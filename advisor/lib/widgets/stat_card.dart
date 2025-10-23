import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12.0), // Slightly reduced padding
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: color), // Slightly smaller icon
          const Spacer(), // Use Spacer for flexible layout
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THIS IS THE KEY CHANGE:
              // FittedBox scales the text down to prevent it from overflowing.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                maxLines: 1, // Prevent label from wrapping
                overflow:
                TextOverflow.ellipsis, // Add '...' if label is too long
              ),
            ],
          ),
        ],
      ),
    );
  }
}
