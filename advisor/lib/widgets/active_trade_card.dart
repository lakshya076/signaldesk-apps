import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/features/trades/open_trade_analysis.dart';
import 'package:signaldesk_advisor/view_models/active_trade_card_view_model.dart';
import 'live_trade_indicator.dart';

class ActiveTradeCardWidget extends StatelessWidget {
  final ActiveTradeCardViewModel trade;

  // Callback for closing
  final Function(String tradeId, String newStatus, double closingPrice)
  onManualClose;

  // ✅ ADDED: A new callback to notify the parent to update the trade
  final Function(String tradeId, double newStopLoss, double newTarget)
  onModifyTrade;

  const ActiveTradeCardWidget({
    super.key,
    required this.trade,
    required this.onManualClose,
    required this.onModifyTrade, // ✅ ADDED: To the constructor
  });

  // This is the "Manual Close" dialog from the previous step (unchanged)
  Future<void> _showManualCloseDialog(BuildContext context) async {
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      // We pass the root context to close it from another dialog
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Manually Close Trade?'),
          content: Text(
            'How do you want to close this trade for ${trade.stockSymbol}?\n\n'
            'Current Price: ${trade.currentPriceFormatted}',
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.all(16.0),
          actions: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                  ),
                  child: const Text('Close as PROFIT'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close this dialog
                    onManualClose(
                      trade.trade.id,
                      'closed_profit',
                      trade.currentPrice,
                    );
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  child: const Text('Close as LOSS'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close this dialog
                    onManualClose(
                      trade.trade.id,
                      'closed_loss',
                      trade.currentPrice,
                    );
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                  ),
                  child: const Text('Close at COST'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Close this dialog
                    onManualClose(
                      trade.trade.id,
                      'closed_cost',
                      trade.currentPrice,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ✅ ADDED: The new dialog for editing SL/TGT
  Future<void> _showModifyTradeDialog(BuildContext context) async {
    final _formKey = GlobalKey<FormState>();
    final _slController = TextEditingController(
      text: trade.trade.stopLoss.toString(),
    );
    final _tgtController = TextEditingController(
      text: trade.trade.target.toString(),
    );
    final tradeDirection = trade.trade.tradeDirection;
    final entryPrice = trade.trade.entryPrice;

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Use StatefulBuilder to manage the form state within the dialog
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Modify Trade'),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _slController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'New Stop Loss',
                        prefixText: '₹',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final sl = double.tryParse(value);
                        if (sl == null) return 'Invalid number';
                        if (tradeDirection == 'Buy' && sl >= entryPrice) {
                          return 'SL must be below entry';
                        }
                        if (tradeDirection == 'Sell' && sl <= entryPrice) {
                          return 'SL must be above entry';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _tgtController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'New Target',
                        prefixText: '₹',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final tgt = double.tryParse(value);
                        if (tgt == null) return 'Invalid number';
                        if (tradeDirection == 'Buy' && tgt <= entryPrice) {
                          return 'Target must be above entry';
                        }
                        if (tradeDirection == 'Sell' && tgt >= entryPrice) {
                          return 'Target must be below entry';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: const Text('Save Changes'),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final newSl = double.parse(_slController.text);
                      final newTgt = double.parse(_tgtController.text);

                      // Call the callback to update the database
                      onModifyTrade(trade.trade.id, newSl, newTgt);
                      Navigator.of(dialogContext).pop(); // Close this dialog
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ✅ ADDED: The new *main* options menu
  Future<void> _showTradeOptionsDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(trade.stockSymbol),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Modify SL / Target'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close this menu
                  _showModifyTradeDialog(context); // Open modify dialog
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.close_rounded),
                label: const Text('Manually Close Trade'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onErrorContainer,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(); // Close this menu
                  _showManualCloseDialog(context); // Open close dialog
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Logic to determine the outline color based on live performance
    final Color outlineColor;
    if (trade.liveReturnValue.abs() < 0.1) {
      outlineColor = theme.colorScheme.tertiary; // Yellow for At Cost
    } else if (trade.isProfit) {
      outlineColor = theme.colorScheme.secondary; // Green for Profit
    } else {
      outlineColor = theme.colorScheme.error; // Red for Loss
    }

    final currentStatusColor =
        trade.isProfit ? theme.colorScheme.secondary : theme.colorScheme.error;

    return InkWell(
      // ✅ MODIFIED: onLongPress now shows the main options menu
      onLongPress: () {
        _showTradeOptionsDialog(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
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
                    backgroundColor: theme.colorScheme.primary.withValues(alpha: .1),
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
                          color: currentStatusColor,
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
