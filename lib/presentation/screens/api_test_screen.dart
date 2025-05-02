import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/utils/api_logger.dart';
import '../../data/services/upstox_auth_service.dart';
import '../../data/services/market_data_service.dart';

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _responseText = 'No response yet';
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _isConnected = false;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _apiSecretController = TextEditingController();
  final TextEditingController _redirectUriController = TextEditingController();
  final TextEditingController _authCodeController = TextEditingController();
  String _selectedEndpoint = 'user/profile';

  final UpstoxAuthService _authService = UpstoxAuthService();
  late final MarketDataService _marketDataService;

  final List<String> _endpoints = [
    'user/profile',
    'market-quote/ohlc?instrument_key=NSE_INDEX|Nifty%2050&interval=1d',
    'historical-candle/NSE_EQ|INE002A01018/day?to_date=2024-01-10&from_date=2024-01-01',
    'market-quote/quotes?instrument_key=NSE_EQ|INE002A01018'
  ];

  @override
  void initState() {
    super.initState();
    _marketDataService = MarketDataService(authService: _authService);
    _apiKeyController.text = AppConstants.apiKey;
    _apiSecretController.text = ''; // Will be populated from stored value
    _redirectUriController.text =
        'https://stockmarketcloneapp.web.app/auth'; // Default redirect URI
    _selectedEndpoint = _endpoints.first; // Default to a reliable endpoint

    // Check authentication status
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    await _authService.initialize();
    final authenticated = _authService.isAuthenticated;

    // Also test actual API connectivity
    bool connected = false;
    if (authenticated) {
      connected = await _marketDataService.testApiConnection();
    }

    if (mounted) {
      setState(() {
        _isAuthenticated = authenticated;
        _isConnected = connected;
      });

      if (_isAuthenticated) {
        _appendToResponse('✅ Authentication status: Authenticated');
        if (_isConnected) {
          _appendToResponse('✅ API connection test: PASSED');
        } else {
          _appendToResponse('❌ API connection test: FAILED');
          _appendToResponse(
              '⚠️ You are authenticated but API test failed. Try refreshing your token.');
        }
      } else {
        _appendToResponse('❌ Authentication status: Not authenticated');
        _appendToResponse('⚠️ Please authenticate with Upstox first');
      }
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _redirectUriController.dispose();
    _authCodeController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
      _responseText = 'Starting authentication flow...';
    });

    try {
      final result = await _authService.startAuthFlow(context);

      if (result) {
        // Test API connectivity after authentication
        final apiConnected = await _marketDataService.testApiConnection();

        setState(() {
          _isAuthenticated = true;
          _isConnected = apiConnected;
          _responseText = '✅ Authentication successful!\n\n';

          if (apiConnected) {
            _responseText +=
                '✅ API connection test: PASSED\n\nYou can now test specific endpoints.';
          } else {
            _responseText +=
                '❌ API connection test: FAILED\n\nThere may be issues with the API configuration or endpoint access.';
          }
        });
      } else {
        _appendToResponse('❌ Authentication was not completed');
      }
    } catch (e) {
      _appendToResponse('❌ Error during authentication: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testApi() async {
    setState(() {
      _isLoading = true;
      _responseText = '🔄 Testing API endpoint...\n';
    });

    try {
      // Check authentication first
      if (!_isAuthenticated) {
        _appendToResponse('❌ Not authenticated. Please authenticate first.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get authentication headers
      final headers = await _authService.getAuthHeaders();

      // Construct the URL carefully, handling potential query parameters in the endpoint string
      String path = _selectedEndpoint;
      String baseUrl = AppConstants.upstoxBaseUrl;
      Map<String, String> queryParams = {};

      // Check if the selected endpoint string contains query parameters
      if (_selectedEndpoint.contains('?')) {
        var parts = _selectedEndpoint.split('?');
        path = parts[0];
        queryParams = Uri.splitQueryString(parts[1]);
      }

      // Use Uri.replace to build the final URL
      final uri = Uri.parse(baseUrl).replace(
          path: '/v2/$path',
          queryParameters: queryParams.isEmpty ? null : queryParams);
      final url = uri.toString();

      // Log request details
      _appendToResponse('🔹 Request URL: $url');
      _appendToResponse('🔹 Headers: $headers');

      ApiLogger.logRequest(url, headers);

      final response = await http.get(
        uri,
        headers: headers,
      );

      ApiLogger.logResponse(response.statusCode, response.body, url: url);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _appendToResponse(
            '✅ Response status: ${response.statusCode} (Success)');

        try {
          // Try to parse and pretty-print JSON
          final jsonData = json.decode(response.body);
          final prettyJson =
              const JsonEncoder.withIndent('  ').convert(jsonData);

          // Only show first part of the response if it's very large
          if (prettyJson.length > 2000) {
            _appendToResponse(
                'Response (truncated):\n${prettyJson.substring(0, 2000)}...\n\n(Response truncated due to size)');
          } else {
            _appendToResponse('Response:\n$prettyJson');
          }

          // Check for specific response format issues
          if (jsonData.containsKey('status')) {
            final status = jsonData['status'];
            if (status == 'error') {
              _appendToResponse('⚠️ API returned status: error');
              if (jsonData.containsKey('message')) {
                _appendToResponse('⚠️ Error message: ${jsonData['message']}');
              }
            } else if (status == 'success') {
              _appendToResponse('✅ API returned status: success');
            }
          }
        } catch (e) {
          // If not JSON, just show as text
          _appendToResponse('⚠️ Could not parse response as JSON: $e');

          // Show a limited part of the response if it's large
          final responseText = response.body;
          if (responseText.length > 1000) {
            _appendToResponse(
                'Response (truncated):\n${responseText.substring(0, 1000)}...');
          } else {
            _appendToResponse('Response:\n$responseText');
          }
        }
      } else if (response.statusCode == 401) {
        _appendToResponse(
            '❌ Response status: ${response.statusCode} (Unauthorized)');

        // Try to parse error message if available
        try {
          final errorData = json.decode(response.body);
          _appendToResponse(
              'Error details:\n${const JsonEncoder.withIndent('  ').convert(errorData)}');

          // Handle specific error for invalid auth code
          if (errorData['errors'] != null && errorData['errors'].isNotEmpty) {
            final error = errorData['errors'][0];
            if (error['errorCode'] == 'UDAPI100057') {
              _appendToResponse(
                  '⚠️ ERROR: Authorization code is invalid or expired!');
              _appendToResponse(
                  '⚠️ IMPORTANT: You need a fresh authorization code for each attempt.');
              _appendToResponse(
                  '⚠️ Please get a new code by clicking "Authenticate" button.');
            }
          }
        } catch (e) {
          _appendToResponse('Response body:\n${response.body}');
        }

        // Suggest re-authentication
        _appendToResponse(
            '⚠️ Authentication token may be expired. Try authenticating again.');
      } else {
        _appendToResponse('❌ HTTP error: ${response.statusCode}');
        _appendToResponse('Response body:\n${response.body}');
      }
    } catch (e) {
      _appendToResponse('❌ Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testAllEndpoints() async {
    setState(() {
      _isLoading = true;
      _responseText = '🔄 Testing all endpoints...\n';
    });

    try {
      if (!_isAuthenticated) {
        _appendToResponse('❌ Not authenticated. Please authenticate first.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final headers = await _authService.getAuthHeaders();

      for (final endpointString in _endpoints) {
        _appendToResponse('\n✳️ Testing endpoint: $endpointString');

        String path = endpointString;
        String baseUrl = AppConstants.upstoxBaseUrl;
        Map<String, String> queryParams = {};

        if (endpointString.contains('?')) {
          var parts = endpointString.split('?');
          path = parts[0];
          queryParams = Uri.splitQueryString(parts[1]);
        }

        final uri = Uri.parse(baseUrl).replace(
            path: '/v2/$path',
            queryParameters: queryParams.isEmpty ? null : queryParams);
        final url = uri.toString();

        try {
          ApiLogger.logRequest(url, headers); // Log before request
          final response = await http.get(uri, headers: headers);
          ApiLogger.logResponse(response.statusCode, response.body,
              url: url); // Log after response

          if (response.statusCode >= 200 && response.statusCode < 300) {
            _appendToResponse('✅ Status: ${response.statusCode} (Success)');
          } else {
            _appendToResponse('❌ Status: ${response.statusCode} (Failed)');
            // Optionally log body for failures
            // _appendToResponse('   Body: ${response.body.length > 200 ? response.body.substring(0,200)+"...": response.body}');
          }
        } catch (e) {
          _appendToResponse('❌ Error: $e');
          ApiLogger.logError('Error testing endpoint $url', e);
        }
        await Future.delayed(
            const Duration(milliseconds: 200)); // Delay between tests
      }

      _appendToResponse('\n✅ Endpoint testing complete.');
    } catch (e) {
      _appendToResponse('❌ Error during multi-endpoint test: $e');
      ApiLogger.logError('Error testing all endpoints', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshMarketData() async {
    setState(() {
      _isLoading = true;
      _responseText = '🔄 Fetching market data...\n';
    });

    try {
      if (!_isAuthenticated) {
        _appendToResponse('❌ Not authenticated. Please authenticate first.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Test market indices endpoint
      _appendToResponse('Fetching market indices...');
      try {
        final indices = await _marketDataService.getMarketIndices();
        _appendToResponse(
            '✅ Successfully fetched ${indices.length} market indices');
        for (final index in indices) {
          _appendToResponse(
              '   • ${index.name}: ${index.value} (${index.percentChange.toStringAsFixed(2)}%)');
        }
      } catch (e) {
        _appendToResponse('❌ Error fetching market indices: $e');
      }

      // Test stock data endpoint
      _appendToResponse('\nFetching popular stocks...');
      try {
        final stocks = await _marketDataService
            .getStockData(AppConstants.popularStocks.take(3).toList());
        _appendToResponse('✅ Successfully fetched ${stocks.length} stocks');
        for (final stock in stocks) {
          _appendToResponse(
              '   • ${stock.symbol}: ₹${stock.lastPrice} (${stock.percentChange.toStringAsFixed(2)}%)');
        }
      } catch (e) {
        _appendToResponse('❌ Error fetching stocks: $e');
      }
    } catch (e) {
      _appendToResponse('❌ Error refreshing market data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _appendToResponse(String text) {
    setState(() {
      _responseText += '\n$text';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Connection Test'),
        actions: [
          // Authentication status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: _isAuthenticated
                  ? (_isConnected ? Colors.green : Colors.orange)
                  : Colors.red,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                _isAuthenticated
                    ? (_isConnected ? 'Connected' : 'Auth Only')
                    : 'Not Auth',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top section with status and buttons
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authentication Status: ${_isAuthenticated ? "✅ Authenticated" : "❌ Not Authenticated"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isAuthenticated ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'API Connection: ${_isConnected ? "✅ Connected" : "❌ Not Connected"}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _authenticate,
                            icon: const Icon(Icons.login),
                            label: const Text('Authenticate'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _testAllEndpoints,
                            icon: const Icon(Icons.api),
                            label: const Text('Test All'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _refreshMarketData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Market Data'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Endpoint selection and testing
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Test Specific API Endpoint',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: _selectedEndpoint,
                      decoration: const InputDecoration(
                        labelText: 'Endpoint',
                        border: OutlineInputBorder(),
                      ),
                      items: _endpoints.map((String endpoint) {
                        return DropdownMenuItem<String>(
                          value: endpoint,
                          child: Text(
                            endpoint,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedEndpoint = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _testApi,
                      icon: const Icon(Icons.api),
                      label: const Text('Test Endpoint'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Response display
            Expanded(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding:
                            EdgeInsets.only(left: 8.0, top: 8.0, bottom: 8.0),
                        child: Text(
                          'Response:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: SingleChildScrollView(
                                child: SelectableText(
                                  _responseText,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (_isLoading)
                              const Center(
                                child: CircularProgressIndicator(),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _responseText = 'Response cleared';
                                });
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
