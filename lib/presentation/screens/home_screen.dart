import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../data/services/upstox_auth_service.dart';
import '../../data/services/market_data_service.dart';
import '../../domain/entities/market_index.dart';
import '../../domain/entities/stock.dart';
import '../widgets/market_indices_card.dart';
import '../widgets/stock_list_item.dart';
import '../widgets/auth_button.dart';
import '../screens/api_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final UpstoxAuthService _authService = UpstoxAuthService();
  late final MarketDataService _marketDataService;

  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _apiConnectionSuccessful = false;
  bool _usingMockData = true;
  List<MarketIndex> _marketIndices = [];
  List<Stock> _popularStocks = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _marketDataService = MarketDataService(authService: _authService);
    _checkAuthAndLoadData();
  }

  Future<void> _checkAuthAndLoadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _apiConnectionSuccessful = false;
      _usingMockData = true;
    });

    try {
      final bool isAuth = _authService.isAuthenticated;
      setState(() {
        _isAuthenticated = isAuth;
      });

      if (isAuth) {
        if (kDebugMode) {
          print('User is authenticated, attempting to load real data...');
        }

        await Future.delayed(const Duration(seconds: 1));

        await _loadData();
      } else {
        if (kDebugMode) {
          print('User is not authenticated, loading mock data');
        }
        _loadMockData();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking authentication: $e';
        _usingMockData = true;
      });
      if (kDebugMode) {
        print(_errorMessage);
      }
      _loadMockData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _errorMessage = '';
    });
    try {
      final bool apiConnected = await _marketDataService.testApiConnection();
      setState(() {
        _apiConnectionSuccessful = apiConnected;
      });

      if (!apiConnected) {
        setState(() {
          _errorMessage = 'API connection test failed. Using mock data.';
          _usingMockData = true;
        });
        if (kDebugMode) {
          print(_errorMessage);
        }
        _loadMockData();
        return;
      }

      if (kDebugMode) {
        print('API connection successful. Loading real market data...');
      }

      final indices = await _marketDataService.getMarketIndices();

      final stocks = await _marketDataService
          .getStockData(['RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK']);

      if (indices.isNotEmpty || stocks.isNotEmpty) {
        if (mounted) {
          setState(() {
            _marketIndices = indices;
            _popularStocks = stocks;
            _usingMockData = false;
            _errorMessage = '';
          });
          if (kDebugMode) {
            print('Successfully loaded real market data.');
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Received empty data from API. Using mock data.';
          _usingMockData = true;
        });
        if (kDebugMode) {
          print(_errorMessage);
        }
        _loadMockData();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading market data: $e. Using mock data.';
          _usingMockData = true;
          _apiConnectionSuccessful = false;
        });
      }
      if (kDebugMode) {
        print('Error loading data: $e');
      }
      _loadMockData();
    }
  }

  void _loadMockData() {
    if (_usingMockData && mounted) {
      setState(() {
        _marketIndices = [
          MarketIndex.mock('NIFTY 50'),
          MarketIndex.mock('NIFTY BANK'),
          MarketIndex.mock('NIFTY IT'),
          MarketIndex.mock('NIFTY FIN SERVICE'),
        ];
        _popularStocks = [
          Stock.mock('RELIANCE'),
          Stock.mock('TCS'),
          Stock.mock('HDFCBANK'),
          Stock.mock('INFY'),
          Stock.mock('ICICIBANK'),
        ];
      });
      if (kDebugMode) {
        print("Loaded mock data for display.");
      }
    }
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await _authService.startAuthFlow(context);
      if (result) {
        if (kDebugMode) {
          print('Login successful, checking auth and loading data...');
        }
        await _checkAuthAndLoadData();
      } else {
        if (kDebugMode) {
          print('Login cancelled or failed in auth flow.');
        }
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        print('Login exception: $e');
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _checkAuthAndLoadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Market App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _isLoading ? null : _handleRefresh,
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.science),
              tooltip: 'API Test Screen',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ApiTestScreen()),
                );
              },
            ),
          if (!_isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: AuthButton(
                  onPressed: _isLoading ? () {} : () => _handleLogin()),
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    String statusText;
    MaterialColor statusColor;
    IconData statusIcon;

    if (_isAuthenticated) {
      if (_apiConnectionSuccessful && !_usingMockData) {
        statusText = 'Authenticated - Using real market data';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      } else if (_apiConnectionSuccessful && _usingMockData) {
        statusText = 'Authenticated - API connected but using mock data';
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
      } else {
        statusText = 'Authenticated - API connection failed, using mock data';
        statusColor = Colors.orange;
        statusIcon = Icons.error;
      }
    } else {
      statusText = 'Not authenticated - Using mock data';
      statusColor = Colors.amber;
      statusIcon = Icons.warning;
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage.isNotEmpty &&
                !_errorMessage.contains('API connection test failed'))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.red.shade100,
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_errorMessage.contains('API connection test failed') ||
                        (_isAuthenticated && !_apiConnectionSuccessful))
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ApiTestScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.bug_report, size: 18),
                          label: const Text('Troubleshoot'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: statusColor.shade100,
              child: Row(
                children: [
                  Icon(
                    statusIcon,
                    color: statusColor.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_isAuthenticated && !_apiConnectionSuccessful)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ApiTestScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.bug_report, size: 16),
                        label: const Text('Troubleshoot'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12),
                          backgroundColor: statusColor.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  if (!_isAuthenticated && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: AuthButton(onPressed: () => _handleLogin()),
                    )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Text(
                'Market Indices',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            SizedBox(
              height: 150,
              child: _marketIndices.isEmpty && !_isLoading
                  ? const Center(child: Text('No index data available.'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _marketIndices.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child:
                              MarketIndicesCard(index: _marketIndices[index]),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24.0, 16.0, 8.0),
              child: Text(
                'Popular Stocks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _popularStocks.isEmpty && !_isLoading
                ? const Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Center(child: Text('No stock data available.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _popularStocks.length,
                    itemBuilder: (context, index) {
                      return StockListItem(stock: _popularStocks[index]);
                    },
                  ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
