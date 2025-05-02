import 'package:flutter/material.dart';
import '../../data/services/market_data_service.dart';
import '../../domain/entities/stock.dart';
import 'package:intl/intl.dart';
import '../widgets/stock_price_chart.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;

  const StockDetailScreen({
    super.key,
    required this.symbol,
  });

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final MarketDataService _marketDataService = MarketDataService();
  late Future<Stock> _stockFuture;
  late Future<Map<String, dynamic>> _historicalDataFuture;
  String _selectedTimeRange = '1m';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _stockFuture = _marketDataService.getStockDetails(widget.symbol);
    _historicalDataFuture = _marketDataService.getHistoricalData(
      widget.symbol,
      interval: 'day',
      range: _selectedTimeRange,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
    );
    final volumeFormat = NumberFormat.compact();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _loadData();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Stock>(
        future: _stockFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Error loading stock data: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadData();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          }

          final stock = snapshot.data!;
          final isPositive = stock.isPositive;
          final changeColor = isPositive ? Colors.green : Colors.red;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock Header
                Text(
                  stock.companyName,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                // Price Information
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(stock.lastPrice),
                      style: theme.textTheme.headlineMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: changeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${isPositive ? '+' : ''}${stock.change.toStringAsFixed(2)} (${stock.percentChange.toStringAsFixed(2)}%)',
                        style: theme.textTheme.bodyMedium!.copyWith(
                          color: changeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                Text(
                  'Last Updated: ${stock.lastUpdateTime}',
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),

                const SizedBox(height: 24),

                // Time Range Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['1d', '1w', '1m', '3m', '6m', '1y']
                        .map((range) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(range),
                                selected: _selectedTimeRange == range,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedTimeRange = range;
                                      _historicalDataFuture =
                                          _marketDataService.getHistoricalData(
                                        widget.symbol,
                                        interval:
                                            range == '1d' ? 'minute' : 'day',
                                        range: range,
                                      );
                                    });
                                  }
                                },
                              ),
                            ))
                        .toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Historical Chart
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _historicalDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Center(
                          child: Text('Chart data not available'),
                        );
                      }

                      // Use our custom chart widget
                      return StockPriceChart(
                        historicalData: snapshot.data!,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Market Statistics
                Text(
                  'Market Statistics',
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildStatRow(
                        'Open',
                        currencyFormat.format(stock.open),
                        'Prev Close',
                        currencyFormat.format(stock.previousClose),
                        theme,
                      ),
                      _buildStatRow(
                        'High',
                        currencyFormat.format(stock.high),
                        'Low',
                        currencyFormat.format(stock.low),
                        theme,
                      ),
                      _buildStatRow(
                        'Volume',
                        volumeFormat.format(stock.volume),
                        '52W High',
                        'N/A', // Not available in current data model
                        theme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(
    String label1,
    String value1,
    String label2,
    String value2,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label1,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value1,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label2,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value2,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _marketDataService.dispose();
    super.dispose();
  }
}
