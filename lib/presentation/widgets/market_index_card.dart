import 'package:flutter/material.dart';

class MarketIndexCard extends StatelessWidget {
  final String name;
  final double value;
  final double change;
  final double percentChange;
  final bool isPositive;

  const MarketIndexCard({
    super.key,
    required this.name,
    required this.value,
    required this.change,
    required this.percentChange,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final changeColor = isPositive
        ? const Color(0xFF4CAF50) // Green
        : const Color(0xFFE53935); // Red

    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Index name
          Text(
            name,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Index value
          Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          // Change info
          Row(
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: changeColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${change.abs().toStringAsFixed(2)} (${percentChange.abs().toStringAsFixed(2)}%)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: changeColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
