import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/market_data_service.dart';
import '../../../domain/entities/stock.dart';
import '../../widgets/real_time_stock_ticker.dart';
import '../../widgets/stock_price_chart.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;

  const StockDetailScreen({super.key, required this.symbol});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  Stock? _stock;
  String _instrumentKey = '';
  bool _isLoading = true;
  String _errorMessage = '';
  String _selectedTimeRange = '1d';

  @override
  void initState() {
    super.initState();
    _fetchStockData();
  }

  Future<void> _fetchStockData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final marketDataService =
          Provider.of<MarketDataService>(context, listen: false);

      // First get the stock details to get data and instrument key
      final stock = await marketDataService.getStockDetails(widget.symbol);

      // For Upstox API, we need to derive the instrument key
      // Using the NSE_EQ|SYMBOL format
      String instrumentKey = '';
      if (widget.symbol == 'RELIANCE') {
        // Use the known instrument key for RELIANCE
        instrumentKey = 'NSE_EQ|INE002A01018';
      } else {
        // Default format using symbol
        instrumentKey = 'NSE_EQ|${widget.symbol}';
      }

      setState(() {
        _stock = stock;
        _instrumentKey = instrumentKey;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch stock data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStockData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchStockData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchStockData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Company name and sector
                      Text(
                        _stock?.companyName ?? widget.symbol,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Real-time price widget
                      if (_instrumentKey.isNotEmpty && _stock != null)
                        RealTimeStockTicker(
                          symbol: widget.symbol,
                          instrumentKey: _instrumentKey,
                          lastPrice: _stock!.lastPrice,
                          showDetailedView: true,
                        ),

                      const SizedBox(height: 24),

                      // Chart time range selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTimeRangeButton('1d'),
                          _buildTimeRangeButton('1w'),
                          _buildTimeRangeButton('1m'),
                          _buildTimeRangeButton('3m'),
                          _buildTimeRangeButton('1y'),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Stock price chart
                      SizedBox(
                        height: 300,
                        child: StockPriceChart(
                          symbol: widget.symbol,
                          range: _selectedTimeRange,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Buy/Sell buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('BUY'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('SELL'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTimeRangeButton(String range) {
    final theme = Theme.of(context);
    final isSelected = _selectedTimeRange == range;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeRange = range;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.dividerColor,
          ),
        ),
        child: Text(
          range,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.textTheme.bodyLarge?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
