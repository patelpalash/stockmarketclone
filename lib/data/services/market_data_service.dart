import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../domain/entities/stock.dart';
import '../../domain/entities/market_index.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/api_logger.dart';
import 'upstox_auth_service.dart';

class MarketDataService {
  final String baseUrl;
  final http.Client _httpClient;
  final UpstoxAuthService _authService;
  final bool useMockData;

  MarketDataService({
    http.Client? httpClient,
    UpstoxAuthService? authService,
  })  : baseUrl = AppConstants.upstoxBaseUrl,
        _httpClient = httpClient ?? http.Client(),
        _authService = authService ?? UpstoxAuthService(),
        useMockData = AppConstants.enableMockData {
    if (kDebugMode) {
      print('MarketDataService initialized with baseUrl: $baseUrl');
      print('Mock data enabled: $useMockData');
    }
  }

  // Helper method to create a properly configured HTTP client for each request
  Future<http.Response> _makeGetRequest(
      Uri uri, Map<String, String> headers) async {
    try {
      final request = http.Request('GET', uri);
      request.headers.addAll(headers);

      final streamedResponse = await _httpClient.send(request).timeout(
        Duration(milliseconds: AppConstants.receiveTimeout),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      return await http.Response.fromStream(streamedResponse);
    } on TimeoutException {
      ApiLogger.logError('Request timed out',
          'Timeout after ${AppConstants.receiveTimeout}ms');
      throw Exception('Request timed out');
    } catch (e) {
      ApiLogger.logError('HTTP request failed', e);
      rethrow;
    }
  }

  // Fetch major market indices (Nifty 50, Bank Nifty, etc.)
  Future<List<MarketIndex>> getMarketIndices() async {
    try {
      // If mock data is explicitly enabled, return mock data directly
      if (useMockData) {
        if (kDebugMode) {
          print('Using mock data by configuration setting');
        }
        return _getMockMarketIndices();
      }

      // Try the primary method first (only method now)
      try {
        final indices = await _getMarketIndicesFromPrimaryEndpoint();
        if (indices.isNotEmpty) {
          return indices;
        } else {
          // If primary endpoint returns empty but successful, treat as failure for fallback
          if (kDebugMode) {
            print(
                'Primary endpoint returned success but empty data. Using mock data.');
          }
          return _getMockMarketIndices();
        }
      } catch (e) {
        if (kDebugMode) {
          print('Primary endpoint failed: $e. Using mock data.');
        }
        return _getMockMarketIndices(); // Fallback on error
      }
    } catch (e) {
      // Catch any unexpected errors during the process
      if (kDebugMode) {
        print('Error fetching market indices: $e');
        print('Using mock data instead');
      }
      return _getMockMarketIndices();
    }
  }

  // Primary method using ohlc endpoint
  Future<List<MarketIndex>> _getMarketIndicesFromPrimaryEndpoint() async {
    // Initialize list of market indices to fetch with correct format
    final List<String> indexKeys = [
      'NSE_INDEX|Nifty 50',
      'NSE_INDEX|Nifty Bank',
      'NSE_INDEX|Nifty IT',
      'NSE_INDEX|Nifty Financial Services',
    ];
    final String instrumentKeys = indexKeys.join(',');

    // Get authenticated headers
    final headers = await _authService.getAuthHeaders();

    if (kDebugMode) {
      print('Authentication headers: $headers');
    }

    // Check if we have an access token
    if (!headers.containsKey('Authorization')) {
      if (kDebugMode) {
        print('No authentication token available, using mock data');
      }
      return _getMockMarketIndices();
    }

    // Correct endpoint: market-quote/ohlc with interval parameter
    final String endpoint = '$baseUrl/market-quote/ohlc';
    final Uri uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'instrument_key': instrumentKeys,
        'interval': '1d',
      },
    );

    if (kDebugMode) {
      print('Market indices request URL: $uri');
      print('Market indices instrument keys: $instrumentKeys');
    }

    ApiLogger.logRequest(uri.toString(), headers);

    // Make the API call with timeout handling
    final response = await _makeGetRequest(uri, headers);

    if (kDebugMode) {
      print('Market indices response status: ${response.statusCode}');
    }

    ApiLogger.logResponse(response.statusCode, response.body, url: endpoint);

    // Handle response based on status code
    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      if (responseData['status'] == 'success') {
        final Map<String, dynamic> data = responseData['data'] ?? {};
        if (data.isEmpty) {
          if (kDebugMode) {
            print('API returned empty data, using mock data');
          }
          throw Exception('API returned empty data');
        }

        // Convert the map of index data to a list of MarketIndex objects
        List<MarketIndex> indices = [];
        data.forEach((key, value) {
          try {
            final String name = key.split(':').last;
            indices.add(MarketIndex(
              name: name,
              value: (value['last_price'] as num?)?.toDouble() ?? 0.0,
              change: (value['net_change'] as num?)?.toDouble() ?? 0.0,
              percentChange:
                  value['net_change'] != null && value['ohlc']['close'] != null
                      ? (value['net_change'] / value['ohlc']['close'] * 100)
                      : 0.0,
              lastUpdateTime: value['timestamp'] ?? DateTime.now().toString(),
            ));
          } catch (e) {
            if (kDebugMode) {
              print('Error parsing index data for $key: $e');
            }
          }
        });

        if (indices.isNotEmpty) {
          if (kDebugMode) {
            print('Successfully fetched ${indices.length} market indices');
          }
          return indices;
        } else {
          throw Exception('No valid indices parsed from response');
        }
      } else {
        throw Exception('API returned error: ${responseData['message']}');
      }
    } else {
      throw Exception('Failed to load market indices: ${response.statusCode}');
    }
  }

  // Map Upstox index data to our MarketIndex model
  MarketIndex _mapToMarketIndex(Map<String, dynamic> json) {
    return MarketIndex(
      name: json['name'] ?? '',
      value: (json['last_price'] as num?)?.toDouble() ?? 0.0,
      change: (json['change'] as num?)?.toDouble() ?? 0.0,
      percentChange: (json['change_percentage'] as num?)?.toDouble() ?? 0.0,
      lastUpdateTime: json['timestamp'] ?? DateTime.now().toString(),
    );
  }

  // Helper to find instrument keys for given symbols
  Future<Map<String, String>> _findInstrumentKeys(List<String> symbols) async {
    final Map<String, String> instrumentKeys = {};
    if (symbols.isEmpty) return instrumentKeys;

    final headers = await _authService.getAuthHeaders();
    if (!headers.containsKey('Authorization')) {
      if (kDebugMode)
        print('Cannot find instrument keys without authentication.');
      return instrumentKeys;
    }

    if (kDebugMode)
      print('🔍 Searching for instrument keys for symbols: $symbols');

    // For well-known stocks, we'll use direct mapping since the search API is having issues
    final Map<String, String> knownInstruments = {
      'RELIANCE': 'NSE_EQ|INE002A01018',
      'TCS': 'NSE_EQ|INE467B01029',
      'HDFCBANK': 'NSE_EQ|INE040A01034',
      'INFY': 'NSE_EQ|INE009A01021',
      'ICICIBANK': 'NSE_EQ|INE090A01021',
    };

    // Check if symbols are in our known mapping first
    for (final symbol in symbols) {
      if (knownInstruments.containsKey(symbol)) {
        instrumentKeys[symbol] = knownInstruments[symbol]!;
        if (kDebugMode) {
          print(
              '✅ Found known instrument_key for $symbol: ${knownInstruments[symbol]}');
        }
      }
    }

    // Only try to search for symbols we don't already know
    final unknownSymbols =
        symbols.where((s) => !instrumentKeys.containsKey(s)).toList();
    if (unknownSymbols.isEmpty) {
      return instrumentKeys;
    }

    for (final symbol in unknownSymbols) {
      try {
        // Try to get instruments with a revised URL structure
        final Uri uri = Uri.parse('$baseUrl/market-quote/quotes')
            .replace(queryParameters: {'instrument_key': 'NSE_EQ|$symbol'});

        if (kDebugMode) print('Testing direct instrument access: $uri');

        final response = await _makeGetRequest(uri, headers);

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          if (responseData['status'] == 'success' &&
              responseData['data'] != null &&
              responseData['data'].isNotEmpty) {
            // If we get a success response, this means the instrument key is valid
            instrumentKeys[symbol] = 'NSE_EQ|$symbol';
            if (kDebugMode) {
              print('✅ Confirmed instrument_key for $symbol: NSE_EQ|$symbol');
            }
          } else {
            if (kDebugMode)
              print('⚠️ No data returned for instrument_key: NSE_EQ|$symbol');
          }
        } else {
          if (kDebugMode)
            print(
                '❌ HTTP error ${response.statusCode} testing instrument_key for $symbol');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Exception testing instrument for $symbol: $e');
        }
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (kDebugMode)
      print(
          '🔍 Finished instrument resolution. Found keys for: ${instrumentKeys.keys.toList()}');
    return instrumentKeys;
  }

  // Fetch stock data for a list of symbols
  Future<List<Stock>> getStockData(List<String> symbols) async {
    try {
      if (useMockData) {
        if (kDebugMode) print('Using mock stock data by configuration setting');
        return _getMockStocks(symbols);
      }

      List<Stock> results = [];
      final headers = await _authService.getAuthHeaders();

      if (kDebugMode)
        print('Attempting to fetch stock data for symbols: $symbols');

      if (!headers.containsKey('Authorization')) {
        if (kDebugMode) print('No auth token, using mock stock data');
        return _getMockStocks(symbols);
      }

      // Known instrument keys for popular stocks - based on successful API calls
      final Map<String, String> knownInstrumentKeys = {
        'RELIANCE': 'NSE_EQ|INE002A01018',
        'TCS': 'NSE_EQ|INE467B01029',
        'HDFCBANK': 'NSE_EQ|INE040A01034',
        'INFY': 'NSE_EQ|INE009A01021',
        'ICICIBANK': 'NSE_EQ|INE090A01021',
      };

      // A map of symbol to its instrument key
      final Map<String, String> symbolToKeyMap = {};

      // First, use known keys for popular stocks
      for (final symbol in symbols) {
        if (knownInstrumentKeys.containsKey(symbol)) {
          symbolToKeyMap[symbol] = knownInstrumentKeys[symbol]!;
          if (kDebugMode) {
            print(
                'Using known instrument key for $symbol: ${knownInstrumentKeys[symbol]}');
          }
        }
      }

      // For any unknown symbols, attempt to derive keys
      final unknownSymbols =
          symbols.where((s) => !symbolToKeyMap.containsKey(s)).toList();
      if (unknownSymbols.isNotEmpty) {
        if (kDebugMode)
          print('Finding instrument keys for unknown symbols: $unknownSymbols');

        // Use direct NSE_EQ|SYMBOL format first
        for (final symbol in unknownSymbols) {
          // First try direct NSE_EQ|SYMBOL format
          final directKey = 'NSE_EQ|$symbol';

          // Test if this key works by querying the API
          try {
            final testUri = Uri.parse('$baseUrl/market-quote/quotes')
                .replace(queryParameters: {'instrument_key': directKey});

            final response = await _makeGetRequest(testUri, headers);

            if (response.statusCode == 200) {
              final responseData = json.decode(response.body);
              if (responseData['status'] == 'success' &&
                  responseData['data'] != null &&
                  responseData['data'].isNotEmpty) {
                // Key worked!
                symbolToKeyMap[symbol] = directKey;
                if (kDebugMode) {
                  print('✅ Confirmed instrument_key for $symbol: $directKey');
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error testing direct key for $symbol: $e');
            }
          }
        }
      }

      final List<String> foundInstrumentKeys = symbolToKeyMap.values.toList();

      if (foundInstrumentKeys.isEmpty) {
        if (kDebugMode)
          print('Could not find any valid instrument keys. Using mock data.');
        return _getMockStocks(symbols);
      }

      if (kDebugMode)
        print(
            'Found ${foundInstrumentKeys.length} instrument keys: $foundInstrumentKeys');

      // Process the found instrument keys in batches
      for (int i = 0; i < foundInstrumentKeys.length; i += 5) {
        // Smaller batch size
        int end = (i + 5 < foundInstrumentKeys.length)
            ? i + 5
            : foundInstrumentKeys.length;
        List<String> batchKeys = foundInstrumentKeys.sublist(i, end);
        String instrumentKeysParam = batchKeys.join(',');

        if (kDebugMode)
          print('Fetching batch with instrument_key: $instrumentKeysParam');

        // Use 'market-quote/quotes' with the correct instrument keys
        final String endpoint = '$baseUrl/market-quote/quotes';
        final Uri uri = Uri.parse(endpoint).replace(
          queryParameters: {
            'instrument_key': instrumentKeysParam,
          },
        );

        ApiLogger.logRequest(uri.toString(), headers);
        final response = await _makeGetRequest(uri, headers);
        ApiLogger.logResponse(response.statusCode, response.body,
            url: endpoint);

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          if (responseData['status'] == 'success') {
            final Map<String, dynamic> data = responseData['data'] ?? {};
            if (kDebugMode) print('Got data for ${data.length} stocks');

            if (data.isEmpty) {
              if (kDebugMode) print('Empty stock data received for this batch');
              continue;
            }

            data.forEach((key, value) {
              try {
                // The response key format uses ':' while request uses '|'
                final String requestKey = key.replaceAll(':', '|');

                // Find original symbol from our mapping
                String originalSymbol = 'UNKNOWN';

                // Look up by the request key format
                for (final entry in symbolToKeyMap.entries) {
                  if (entry.value == requestKey) {
                    originalSymbol = entry.key;
                    break;
                  }
                }

                // If not found directly, try to extract from the key
                if (originalSymbol == 'UNKNOWN') {
                  final parts = key.split(':');
                  if (parts.length > 1 && parts[0] == 'NSE_EQ') {
                    // Look for a registered stock symbol that matches
                    for (final sym in symbols) {
                      if (sym == parts[1]) {
                        originalSymbol = sym;
                        break;
                      }
                    }
                  }
                }

                if (originalSymbol != 'UNKNOWN') {
                  results.add(_mapToStockFromQuote(originalSymbol, key, value));
                } else {
                  if (kDebugMode)
                    print(
                        '⚠️ Could not map key $key back to an original symbol');
                }
              } catch (e) {
                if (kDebugMode)
                  print('❌ Error mapping stock data for key $key: $e');
              }
            });
          } else {
            if (kDebugMode)
              print(
                  'API error fetching quotes batch: ${responseData['message']}');
          }
        } else {
          if (kDebugMode)
            print(
                '❌ Failed to load stock data batch: ${response.statusCode}, Body: ${response.body}');
        }
        await Future.delayed(const Duration(milliseconds: 250));
      }

      if (results.isEmpty) {
        if (kDebugMode)
          print('No stock data retrieved from API, using mock data');
        return _getMockStocks(symbols);
      }

      if (kDebugMode)
        print(
            '✅ Successfully fetched data for ${results.length} stocks: ${results.map((s) => s.symbol).toList()}');
      return results;
    } catch (e) {
      if (kDebugMode) print('❌ Error in getStockData: $e');
      return _getMockStocks(symbols);
    }
  }

  // Map Upstox quote data to our Stock model
  Stock _mapToStockFromQuote(
      String symbol, String instrumentKey, Map<String, dynamic> json) {
    try {
      if (kDebugMode) {
        // print('Mapping stock data for symbol: $symbol, key: $instrumentKey, data: $json');
      }

      final Map<String, dynamic> ohlc =
          json['ohlc'] as Map<String, dynamic>? ?? {};

      // Calculate percentChange safely
      double percentChange = 0.0;
      final num? netChange = json['net_change']; // Direct access
      final num? prevClose = ohlc['close']; // Previous day's close from OHLC
      if (netChange != null && prevClose != null && prevClose != 0) {
        percentChange = (netChange / prevClose) * 100;
      }

      final stock = Stock(
        symbol: symbol, // Use the original symbol
        // Use 'name' from quote response if available, else fallback to symbol
        companyName: json['name'] as String? ?? symbol,
        lastPrice: (json['last_price'] as num?)?.toDouble() ?? 0.0,
        change: (netChange as num?)?.toDouble() ?? 0.0,
        percentChange: percentChange,
        open: (ohlc['open'] as num?)?.toDouble() ?? 0.0,
        high: (ohlc['high'] as num?)?.toDouble() ?? 0.0,
        low: (ohlc['low'] as num?)?.toDouble() ?? 0.0,
        previousClose: (prevClose as num?)?.toDouble() ?? 0.0,
        volume: (json['volume'] as num?)?.toInt() ?? 0,
        lastUpdateTime:
            json['timestamp'] as String? ?? DateTime.now().toString(),
      );
      if (kDebugMode) {
        // print('Successfully mapped stock: ${stock.symbol}');
      }
      return stock;
    } catch (e, stacktrace) {
      if (kDebugMode) {
        print('❌ Error mapping quote data for $symbol ($instrumentKey): $e');
        print('Raw JSON for error: $json');
        print('Stacktrace: $stacktrace');
      }
      // Re-throw the error to be caught by the outer loop, preventing addition to results
      rethrow;
    }
  }

  int min(int a, int b) => a < b ? a : b;

  // Fetch detailed data for a specific stock
  Future<Stock> getStockDetails(String symbol) async {
    try {
      // Get authenticated headers
      final headers = await _authService.getAuthHeaders();

      if (kDebugMode) {
        print('Fetching stock details for: $symbol');
        print('Authentication headers: $headers');
      }

      // Determine instrument key - first check known keys
      String? instrumentKey;

      // Known keys for major stocks
      final Map<String, String> knownKeys = {
        'RELIANCE': 'NSE_EQ|INE002A01018',
        'TCS': 'NSE_EQ|INE467B01029',
        'HDFCBANK': 'NSE_EQ|INE040A01034',
        'INFY': 'NSE_EQ|INE009A01021',
        'ICICIBANK': 'NSE_EQ|INE090A01021',
      };

      if (knownKeys.containsKey(symbol)) {
        instrumentKey = knownKeys[symbol];
        if (kDebugMode) {
          print('Using known instrument key for $symbol: $instrumentKey');
        }
      } else {
        // Try direct format
        instrumentKey = 'NSE_EQ|$symbol';

        // Test if this key works
        try {
          final testUri = Uri.parse('$baseUrl/market-quote/quotes')
              .replace(queryParameters: {'instrument_key': instrumentKey});

          final testResponse = await _makeGetRequest(testUri, headers);

          if (testResponse.statusCode != 200 ||
              json.decode(testResponse.body)['data'] == null ||
              json.decode(testResponse.body)['data'].isEmpty) {
            // Direct key didn't work, try searching
            if (kDebugMode) {
              print('Direct key not working, trying to search for $symbol');
            }
            instrumentKey = null;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error testing direct key: $e');
          }
          instrumentKey = null;
        }
      }

      // If still no key, fallback to mock
      if (instrumentKey == null) {
        if (kDebugMode) {
          print('Could not find instrument key for $symbol, using mock data');
        }
        return Stock.mock(symbol);
      }

      // Use the proper endpoint with instrument_key parameter
      final String endpoint = '$baseUrl/market-quote/quotes';
      final Uri uri = Uri.parse(endpoint).replace(
        queryParameters: {
          'instrument_key': instrumentKey,
        },
      );

      if (kDebugMode) {
        print('Stock details request URL: $uri');
      }

      final response = await _makeGetRequest(uri, headers);

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final Map<String, dynamic> data = responseData['data'] ?? {};
          // The key in the data map will be the instrument key with : instead of |
          final String dataKey = instrumentKey.replaceAll('|', ':');
          if (data.containsKey(dataKey)) {
            return _mapToStockFromQuote(symbol, instrumentKey, data[dataKey]);
          }
        }
        if (kDebugMode) {
          print('Stock details not available from API, using mock data');
        }
        return Stock.mock(symbol);
      } else {
        if (kDebugMode) {
          print('Failed API request, using mock data for $symbol');
        }
        return Stock.mock(symbol);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching stock details: $e');
      }
      return Stock.mock(symbol);
    }
  }

  // Get historical data for a stock (for charts)
  Future<Map<String, dynamic>> getHistoricalData(
    String symbol, {
    String interval = 'day', // Corresponds to Upstox interval like '1day'
    String range = '1m', // Used to calculate from/to dates
  }) async {
    try {
      final headers = await _authService.getAuthHeaders();
      if (!headers.containsKey('Authorization')) {
        throw Exception('Authentication required for historical data');
      }

      // --- Find the correct instrument key ---
      if (kDebugMode)
        print('Finding instrument key for historical data: $symbol');

      // For RELIANCE, we've seen success with a specific instrument key
      String? instrumentKey;
      if (symbol == 'RELIANCE') {
        instrumentKey = 'NSE_EQ|INE002A01018';
        if (kDebugMode)
          print('Using known instrument key for RELIANCE: $instrumentKey');
      } else {
        final keyMap = await _findInstrumentKeys([symbol]);
        instrumentKey = keyMap[symbol];
      }

      if (instrumentKey == null) {
        throw Exception('Could not find instrument key for symbol: $symbol');
      }
      if (kDebugMode)
        print('Using instrument key for historical data: $instrumentKey');
      // --- End Find Key ---

      // Convert interval to Upstox API interval string
      // Supported intervals: 1minute, 30minute, day, week, month
      String upstoxInterval;
      switch (interval.toLowerCase()) {
        case '1minute':
        case 'minute':
          upstoxInterval = '1minute';
          break;
        case '30minute':
          upstoxInterval = '30minute';
          break;
        case 'day':
          upstoxInterval = 'day'; // Corrected to 'day' as per docs
          break;
        case 'week':
          upstoxInterval = 'week'; // Corrected to 'week'
          break;
        case 'month':
          upstoxInterval = 'month'; // Corrected to 'month'
          break;
        default:
          if (kDebugMode)
            print('Unsupported interval $interval, defaulting to day');
          upstoxInterval = 'day';
      }

      // Calculate from and to dates based on range
      DateTime to = DateTime.now();
      DateTime from;
      // Ensure 'to' date is not in the future (API might reject it)
      // Use end of yesterday for daily/weekly/monthly to ensure data is available
      if (upstoxInterval == 'day' ||
          upstoxInterval == 'week' ||
          upstoxInterval == 'month') {
        to = DateTime(to.year, to.month, to.day)
            .subtract(const Duration(microseconds: 1));
      }

      switch (range) {
        case '1d':
          from = DateTime(to.year, to.month, to.day); // Start of day
          if (interval == 'day') upstoxInterval = '1minute';
          break;
        case '1w':
          from = to.subtract(const Duration(days: 7));
          break;
        case '1m':
          from = to.subtract(const Duration(days: 30));
          break;
        case '3m':
          from = to.subtract(const Duration(days: 90));
          break;
        case '6m':
          from = to.subtract(const Duration(days: 180));
          break;
        case '1y':
          from = to.subtract(const Duration(days: 365));
          break;
        case '5y':
          from = to.subtract(const Duration(days: 1825));
          break;
        default:
          from = to.subtract(const Duration(days: 30)); // Default to 1 month
      }

      // Format dates correctly
      String formattedFrom =
          "${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}";
      String formattedTo =
          "${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}";

      if (kDebugMode) {
        print('Fetching historical data for: $instrumentKey');
        print(
            'Interval: $upstoxInterval, From: $formattedFrom, To: $formattedTo');
      }

      // Based on logs, this format seems to work: /historical-candle/{instrument_key}/{interval}?from_date=X&to_date=Y
      final Uri uri = Uri.parse(
          '$baseUrl/historical-candle/$instrumentKey/$upstoxInterval');
      final queryParams = {'from_date': formattedFrom, 'to_date': formattedTo};
      final completeUri = uri.replace(queryParameters: queryParams);

      if (kDebugMode) print('Historical data URL: $completeUri');

      ApiLogger.logRequest(completeUri.toString(), headers);
      final response = await _makeGetRequest(completeUri, headers);
      ApiLogger.logResponse(response.statusCode, response.body,
          url: completeUri.toString()); // Log full URI

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData['status'] == 'success') {
          final List<dynamic> candles = responseData['data']?['candles'] ?? [];

          List<Map<String, dynamic>> formattedData = candles
              .map((candle) {
                // Expected format: [Timestamp, Open, High, Low, Close, Volume, OI]
                if (candle is List && candle.length >= 6) {
                  return {
                    'timestamp':
                        candle[0], // Assuming Timestamp is String or Number
                    'open': (candle[1] as num?)?.toDouble(),
                    'high': (candle[2] as num?)?.toDouble(),
                    'low': (candle[3] as num?)?.toDouble(),
                    'close': (candle[4] as num?)?.toDouble(),
                    'volume': (candle[5] as num?)?.toInt(),
                  };
                } else {
                  if (kDebugMode) print('Unexpected candle format: $candle');
                  return <String,
                      dynamic>{}; // Return empty map for invalid format
                }
              })
              .where((map) => map.isNotEmpty)
              .toList(); // Filter out empty maps

          return {
            'symbol': symbol,
            'interval': interval,
            'range': range,
            'data': formattedData,
          };
        } else {
          if (kDebugMode) print('API error: ${responseData['message']}');
          return _getMockHistoricalData(symbol, interval, range);
        }
      } else {
        if (kDebugMode)
          print('Using mock data due to API error: ${response.statusCode}');
        return _getMockHistoricalData(symbol, interval, range);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in getHistoricalData for $symbol: $e');
      }
      return _getMockHistoricalData(
          symbol, interval, range); // Fallback to mock
    }
  }

  // Mock data generators (kept for fallback)
  List<MarketIndex> _getMockMarketIndices() {
    return [
      MarketIndex.mock(AppConstants.nifty50),
      MarketIndex.mock(AppConstants.bankNifty),
      MarketIndex.mock(AppConstants.niftyIT),
      MarketIndex.mock(AppConstants.niftyFinService),
    ];
  }

  List<Stock> _getMockStocks(List<String> symbols) {
    return symbols.map((symbol) => Stock.mock(symbol)).toList();
  }

  Map<String, dynamic> _getMockHistoricalData(
      String symbol, String interval, String range) {
    // Generate random data points for the chart
    final int dataPoints = range == '1d'
        ? 24
        : range == '1w'
            ? 7
            : range == '1m'
                ? 30
                : 90;
    final List<Map<String, dynamic>> data = [];

    final DateTime now = DateTime.now();
    double basePrice = 1000 + (symbol.hashCode % 2000);

    for (int i = 0; i < dataPoints; i++) {
      final DateTime timestamp = now.subtract(Duration(
        days: interval == 'day' ? i : 0,
        hours: interval == 'hour' ? i : 0,
        minutes: interval == 'minute' ? i : 0,
      ));

      // Add some random price movement
      final double change = (0.5 - (i % dataPoints) / dataPoints) * 20;
      basePrice += change;

      data.add({
        'timestamp': timestamp.toIso8601String(),
        'open': basePrice - 5,
        'high': basePrice + 10,
        'low': basePrice - 10,
        'close': basePrice,
        'volume': 100000 + (1000 * i),
      });
    }

    return {
      'symbol': symbol,
      'interval': interval,
      'range': range,
      'data': data.reversed.toList(), // Most recent first
    };
  }

  // Test API connectivity - use this for debugging
  Future<bool> testApiConnection() async {
    try {
      // Get authenticated headers
      final headers = await _authService.getAuthHeaders();

      if (kDebugMode) {
        print('Testing API connectivity');
        print('Authentication headers: $headers');
      }

      // Try a different API call that's more likely to succeed - User Profile
      // This endpoint is more reliable than market-status
      final String endpoint = '$baseUrl/user/profile';
      final Uri uri = Uri.parse(endpoint);

      ApiLogger.logRequest(uri.toString(), headers);

      // Make the API call
      final response = await _makeGetRequest(uri, headers);

      ApiLogger.logResponse(response.statusCode, response.body, url: endpoint);

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('API connection successful!');
        }
        return true;
      } else if (response.statusCode == 401) {
        // Authentication issue
        if (kDebugMode) {
          print('Authentication failed: Token may be expired or invalid');
          print('Response: ${response.body}');
        }

        // Try to clear authentication and prompt for re-auth
        await _authService.logout();

        return false;
      } else {
        if (kDebugMode) {
          print('API connection failed with status: ${response.statusCode}');
          print('Response: ${response.body}');

          // Try to parse error message if available
          try {
            final errorData = json.decode(response.body);
            final errorMsg =
                errorData['message'] ?? errorData['error'] ?? 'Unknown error';
            print('Error message: $errorMsg');
          } catch (e) {
            // Unable to parse error
            print('Unable to parse error response');
          }
        }
        return false;
      }
    } catch (e) {
      ApiLogger.logError('Error testing API connection', e);
      if (kDebugMode) {
        print('Exception during API test: $e');
      }
      return false;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
