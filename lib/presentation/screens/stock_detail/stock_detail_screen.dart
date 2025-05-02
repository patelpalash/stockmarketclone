import 'package:flutter/material.dart';

class StockDetailScreen extends StatelessWidget {
  final String symbol;

  const StockDetailScreen({super.key, required this.symbol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(symbol),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Stock Detail Screen - Coming Soon',
          style: theme.textTheme.titleLarge,
        ),
      ),
    );
  }
}
