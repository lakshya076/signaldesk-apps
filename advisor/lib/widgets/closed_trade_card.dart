import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/screens/trades/closed_trades_analysis.dart';
import 'package:signaldesk_advisor/view_models/closed_trade_card_view_model.dart';

class ClosedTradeCardWidget extends StatelessWidget {
  final ClosedTradeCardViewModel trade;

  const ClosedTradeCardWidget({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Logic to determine the outline color based on final status
    final Color outlineColor;
    if (trade.wasProfitable) {
      outlineColor = theme.colorScheme.secondary; // Green
    } else if (trade.wasLoss) {
      outlineColor = theme.colorScheme.error; // Red
    } else {
      outlineColor = theme.colorScheme.tertiary; // Yellow
    }

    final gainLossColor =
        trade.gainLossValue >= 0
            ? theme.colorScheme.secondary
            : theme.colorScheme.error;
    final statusColor = outlineColor;

    return InkWell(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ClosedTradesAnalysis(trade: trade),
            ),
          ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          // UPDATED: Border now uses the dynamic outline color
          border: Border.all(color: outlineColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: .1,
                  ),
                  radius: 24,
                  child: Text(
                    trade.stockSymbol.substring(0, 1),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.stockSymbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        trade.companyName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  trade.tradeStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat(
                  'Gain/Loss',
                  trade.gainLossPercent,
                  gainLossColor,
                  context,
                ),
                _buildStat(
                  'Risk/Reward',
                  trade.riskReward,
                  theme.colorScheme.secondary,
                  context,
                  alignment: CrossAxisAlignment.end,
                ),
              ],
            ),
            Divider(color: theme.dividerColor, height: 32),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLevel('Entry', trade.entryPriceFormatted, context),
                  Container(width: 1, height: 30, color: theme.dividerColor),
                  _buildLevel('Exit', trade.exitPriceFormatted, context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    String label,
    String value,
    Color color,
    BuildContext context, {
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLevel(String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
