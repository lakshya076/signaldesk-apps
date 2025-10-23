import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/view_models/closed_trade_card_view_model.dart';

class ClosedTradesAnalysis extends StatelessWidget {
  final ClosedTradeCardViewModel trade;

  const ClosedTradesAnalysis({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trade Analysis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildReturnCard(context),
            const SizedBox(height: 16),
            _buildDurationCard(context),
            const SizedBox(height: 16),
            _buildDetailsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: theme.colorScheme.primary.withValues(alpha: .1),
          child: Text(
            trade.stockSymbol.substring(0, 1),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                trade.companyName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                softWrap: true,
                overflow: TextOverflow.visible,
                maxLines: null,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Exit Price',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            Text(
              trade.exitPriceFormatted,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReturnCard(BuildContext context) {
    final theme = Theme.of(context);
    final profitColor = theme.colorScheme.secondary;
    final lossColor = theme.colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(
                  context,
                  'Return',
                  trade.gainLossPercent,
                  valueStyle: TextStyle(
                    color: trade.wasProfitable ? profitColor : lossColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildInfoColumn(
                  context,
                  'Risk/Reward Ratio',
                  trade.riskReward,
                  valueStyle: TextStyle(
                    color: profitColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(
                  context,
                  'Entry',
                  trade.entryPriceFormatted,
                  subLabel: 'Timestamp',
                ),
                _buildInfoColumn(
                  context,
                  'Exit',
                  trade.exitPriceFormatted,
                  subLabel: 'Timestamp',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabelValueRow(context, 'Trade Duration', '23 Days'),
                  const SizedBox(height: 12),
                  _buildLabelValueRow(
                    context,
                    'Trade Segment',
                    trade.trade.tradeSegment,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabelValueRow(
                    context,
                    'Trade Direction',
                    trade.trade.tradeDirection,
                  ),
                  const SizedBox(height: 12),
                  _buildLabelValueRow(
                    context,
                    'Trade Category',
                    trade.trade.tradeCategory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final theme = Theme.of(context);
    Color getStatusColor() {
      if (trade.wasProfitable) return theme.colorScheme.secondary;
      if (trade.wasLoss) return theme.colorScheme.error;
      return theme.hintColor;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trade Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildDetailRow(context, 'Entry', '15 Aug 2:03pm'),
            _buildDetailRow(context, 'Exit', '15 Aug 4:03pm'),
            _buildDetailRow(
              context,
              'Status',
              trade.tradeStatus,
              valueColor: getStatusColor(),
            ),
            _buildDetailRow(
              context,
              'Stop Loss',
              '₹${trade.trade.stopLoss.toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              context,
              'Target',
              '₹${trade.trade.target.toStringAsFixed(2)}',
            ),
            _buildDetailRow(context, 'Segment', trade.trade.tradeSegment),
            _buildDetailRow(context, 'Signal Category', 'Trading'),
            _buildDetailRow(
              context,
              'Trade Category',
              trade.trade.tradeCategory,
            ),
            _buildDetailRow(
              context,
              'Trade Direction',
              trade.trade.tradeDirection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
      BuildContext context,
      String label,
      String value, {
        TextStyle? valueStyle,
        String? subLabel,
      }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style:
          valueStyle ??
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (subLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor.withValues(alpha: .8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabelValueRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      BuildContext context,
      String label,
      String value, {
        Color? valueColor,
      }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.hintColor)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
