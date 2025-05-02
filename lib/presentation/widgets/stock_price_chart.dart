import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StockPriceChart extends StatelessWidget {
  final Map<String, dynamic> historicalData;

  const StockPriceChart({
    super.key,
    required this.historicalData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Map<String, dynamic>> data =
        historicalData['data'] as List<Map<String, dynamic>>;

    if (data.isEmpty) {
      return const Center(child: Text('No chart data available'));
    }

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
                  if (value % 5 != 0) return const SizedBox.shrink();

                  final index = value.toInt();
                  if (index >= data.length || index < 0) {
                    return const SizedBox.shrink();
                  }

                  String timestamp = data[index]['timestamp'] as String;
                  DateTime dateTime = DateTime.parse(timestamp);

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('MM/dd').format(dateTime),
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
