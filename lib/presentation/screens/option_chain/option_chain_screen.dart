import 'package:flutter/material.dart';

class OptionChainScreen extends StatelessWidget {
  const OptionChainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Options Chain'),
      ),
      body: Center(
        child: Text(
          'Option Chain Screen - Coming Soon',
          style: theme.textTheme.titleLarge,
        ),
      ),
    );
  }
}
