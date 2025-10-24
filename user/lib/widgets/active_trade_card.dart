import 'package:flutter/material.dart';
import 'package:signaldesk_user/screens/trades/open_trade_analysis_screen.dart';
import 'package:signaldesk_user/view_models/active_trade_card_view_model.dart';

import 'live_trade_indicator.dart';

class ActiveTradeCardWidget extends StatelessWidget {
  final ActiveTradeCardViewModel trade;

  const ActiveTradeCardWidget({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color outlineColor;
    if (trade.liveReturnValue.abs() < 0.1) {
      outlineColor = theme.colorScheme.tertiary;
    } else if (trade.isProfit) {
      outlineColor = theme.colorScheme.secondary;
    } else {
      outlineColor = theme.colorScheme.error;
    }
    final currentStatusColor =
        trade.isProfit ? theme.colorScheme.secondary : theme.colorScheme.error;

    final priceChangeColor = trade.priceChangeValue >= 0
        ? theme.colorScheme.secondary
        : theme.colorScheme.error;


    return InkWell(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OpenTradeAnalysis(activeTrade: trade),
            ),
          ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trade.currentPriceFormatted,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      trade.priceChange,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: priceChangeColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LiveTradeIndicator(
              stopLoss: trade.trade.stopLoss,
              target: trade.trade.target,
              entryPrice: trade.trade.entryPrice,
              currentPrice: trade.currentPrice,
              tradeDirection: trade.trade.tradeDirection, // Add this line
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: currentStatusColor.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Live Status: ${trade.liveStatus}',
                  style: TextStyle(
                    color: currentStatusColor,
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
                  'Estimated Gain',
                  trade.estimatedGain,
                  theme.colorScheme.secondary,
                  context,
                ),
                _buildStat(
                  'Live Return',
                  trade.liveReturn,
                  currentStatusColor,
                  context,
                  alignment: CrossAxisAlignment.end,
                ),
              ],
            ),
            Divider(color: theme.dividerColor, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLevel('Entry', trade.entryPrice, context),
                Container(width: 1, height: 30, color: theme.dividerColor),
                _buildLevel('Stop Loss', trade.stopLoss, context),
                Container(width: 1, height: 30, color: theme.dividerColor),
                _buildLevel('Target', trade.targetPrice, context),
              ],
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
