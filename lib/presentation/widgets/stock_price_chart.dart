import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/services/market_data_service.dart';

class StockPriceChart extends StatefulWidget {
  final String symbol;
  final String range; // e.g., '1d', '1w', '1m', '3m', '1y'
  final String interval;

  const StockPriceChart({
    super.key,
    required this.symbol,
    required this.range,
    this.interval = 'day',
  });

  @override
  State<StockPriceChart> createState() => _StockPriceChartState();
}

class _StockPriceChartState extends State<StockPriceChart> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _chartData;

  @override
  void initState() {
    super.initState();
    _fetchChartData();
  }

  @override
  void didUpdateWidget(StockPriceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.range != widget.range ||
        oldWidget.interval != widget.interval) {
      _fetchChartData();
    }
  }

  Future<void> _fetchChartData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final marketDataService =
          Provider.of<MarketDataService>(context, listen: false);

      // Determine the appropriate interval based on range
      String interval = widget.interval;
      if (widget.range == '1d') {
        interval = 'minute';
      }

      final data = await marketDataService.getHistoricalData(
        widget.symbol,
        interval: interval,
        range: widget.range,
      );

      setState(() {
        _chartData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load chart data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchChartData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chartData == null ||
        (_chartData?['data'] as List<dynamic>?)?.isEmpty == true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              'No chart data available for ${widget.symbol}',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _buildChart(theme);
  }

  Widget _buildChart(ThemeData theme) {
    final List<Map<String, dynamic>> data =
        _chartData!['data'] as List<Map<String, dynamic>>;

    // Find min and max values for y-axis
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final point in data) {
      final double low = point['low'] as double;
      final double high = point['high'] as double;

      if (low < minY) minY = low;
      if (high > maxY) maxY = high;
    }

    // Add some padding to min/max
    final yPadding = (maxY - minY) * 0.1;
    minY -= yPadding;
    maxY += yPadding;

    // Chart line color based on price movement
    final firstPrice = data.first['close'] as double;
    final lastPrice = data.last['close'] as double;
    final lineColor = lastPrice >= firstPrice ? Colors.green : Colors.red;

    // Format for the bottom titles based on range
    String bottomTitleFormat;
    switch (widget.range) {
      case '1d':
        bottomTitleFormat = 'HH:mm';
        break;
      case '1w':
        bottomTitleFormat = 'EEE';
        break;
      case '1m':
        bottomTitleFormat = 'dd MMM';
        break;
      default:
        bottomTitleFormat = 'MM/dd';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            horizontalInterval: (maxY - minY) / 5,
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  // Only show a subset of labels to avoid crowding
                  final skipFactor =
                      data.length > 30 ? 6 : (data.length > 10 ? 3 : 1);
                  if (value.toInt() % skipFactor != 0) {
                    return const SizedBox.shrink();
                  }

                  final index = value.toInt();
                  if (index >= data.length || index < 0) {
                    return const SizedBox.shrink();
                  }

                  String timestamp = data[index]['timestamp'] as String;
                  DateTime dateTime = DateTime.parse(timestamp);

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat(bottomTitleFormat).format(dateTime),
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
                reservedSize: 28,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compact().format(value),
                    style: theme.textTheme.bodySmall,
                  );
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: false,
          ),
          minX: 0,
          maxX: data.length.toDouble() - 1,
          minY: minY,
          maxY: maxY,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < data.length) {
                    final item = data[index];
                    final timestamp = item['timestamp'] as String;
                    final DateTime dateTime = DateTime.parse(timestamp);
                    final price = item['close'] as double;

                    return LineTooltipItem(
                      '${DateFormat('MM/dd HH:mm').format(dateTime)}\n₹${price.toStringAsFixed(2)}',
                      theme.textTheme.bodySmall!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  } else {
                    return null;
                  }
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(data.length, (index) {
                return FlSpot(
                  index.toDouble(),
                  (data[index]['close'] as double),
                );
              }),
              isCurved: true,
              curveSmoothness: 0.2,
              color: lineColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
