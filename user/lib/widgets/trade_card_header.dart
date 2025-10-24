import 'package:flutter/material.dart';

class TradeCardHeader extends StatelessWidget {
  final String advisorName;
  final String segment;
  final String category;

  const TradeCardHeader({
    super.key,
    required this.advisorName,
    required this.segment,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Match the horizontal padding of your trade cards
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline, // Advisor icon
                size: 16,
                color: theme.hintColor,
              ),
              const SizedBox(width: 6),
              Text(
                advisorName,
                style: TextStyle(
                  color: theme.hintColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Tags for Segment and Category
          Row(
            children: [
              _buildTag(context, segment, theme.colorScheme.primary),
              const SizedBox(width: 6),
              _buildTag(context, category, theme.colorScheme.tertiary),
            ],
          ),
        ],
      ),
    );
  }

  // Helper widget to build the small tags
  Widget _buildTag(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: .5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
