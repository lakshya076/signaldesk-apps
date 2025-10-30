import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/screens/trades/open_trade_analysis.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/view_models/active_trade_card_view_model.dart';
import 'package:signaldesk_advisor/widgets/live_trade_indicator.dart';

class ActiveTradeCardWidget extends StatelessWidget {
  final ActiveTradeCardViewModel trade;

  // Callback for closing
  final Function(String tradeId, String newStatus, double closingPrice)
  onManualClose;

  // Callback to notify the parent to update the trade
  final Function(String tradeId, double newStopLoss, double newTarget)
  onModifyTrade;

  final ApiService apiService;

  const ActiveTradeCardWidget({
    super.key,
    required this.trade,
    required this.onManualClose,
    required this.onModifyTrade,
    required this.apiService,
  });

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

    final priceChangeColor =
        trade.priceChangeValue >= 0
            ? theme.colorScheme.secondary
            : theme.colorScheme.error;

    return InkWell(
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
                tradeDirection: trade.tradeDirection,
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

  // Trade Updation Methods (Manual Close, Updating SL, TGT)

  Future<void> _showManualCloseDialog(BuildContext context) async {
    final theme = Theme.of(context);

    bool isMarketOpen = await apiService.checkMarketStatus();

    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    } else {
      return;
    }

    if (!isMarketOpen) {
      if (context.mounted) {
        _showMarketClosedErrorDialog(context); // Show error and exit
      }
      return;
    }

    // Automatically determine the status based on the (now correct) ViewModel
    final double pnlValue = trade.liveReturnValue;
    final String newStatus;
    final String statusMessage;
    final Color confirmColor;
    final Color confirmTextColor;

    // Using a 0.1% threshold for "at cost"
    if (pnlValue.abs() < 0.1) {
      newStatus = 'closed_cost';
      statusMessage = 'at COST';
      confirmColor = theme.colorScheme.tertiary;
      confirmTextColor = theme.colorScheme.onSurface;
    } else if (pnlValue > 0) {
      newStatus = 'closed_profit';
      statusMessage = 'as PROFIT';
      confirmColor = theme.colorScheme.secondary;
      confirmTextColor = theme.colorScheme.onPrimary;
    } else {
      newStatus = 'closed_loss';
      statusMessage = 'as LOSS';
      confirmColor = theme.colorScheme.error;
      confirmTextColor = theme.colorScheme.onPrimary;
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        // Build a confirmation dialog
        return AlertDialog(
          title: const Text('Confirm Manual Close'),
          content: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text:
                      'Are you sure you want to close this trade for ${trade.stockSymbol}?\n\n'
                      'It will be closed ',
                ),
                TextSpan(
                  text: statusMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text:
                      '.\n\n'
                      'Current Price: ${trade.currentPriceFormatted}\n'
                      'Live Return: ${trade.liveReturn}',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            // "Confirm" button, styled based on the status
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
                foregroundColor: confirmTextColor,
              ),
              child: const Text('Confirm Close'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Call the callback with the auto-determined status
                onManualClose(trade.trade.id, newStatus, trade.currentPrice);
              },
            ),
          ],
        );
      },
    );
  }

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
                        if (tradeDirection == 'Buy') {
                          if (sl >= entryPrice) {
                            return 'SL must be below entry';
                          }
                          if (sl >= trade.currentPrice) {
                            return 'SL must be below current price';
                          }
                        } else {
                          // 'Sell'
                          if (sl <= entryPrice) {
                            return 'SL must be above entry';
                          }
                          if (sl <= trade.currentPrice) {
                            return 'SL must be above current price';
                          }
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
                        if (tradeDirection == 'Buy') {
                          if (tgt <= entryPrice) {
                            return 'Target must be above entry';
                          }
                          if (tgt <= trade.currentPrice) {
                            return 'Target must be above current price';
                          }
                        } else {
                          // 'Sell'
                          if (tgt >= entryPrice) {
                            return 'Target must be below entry';
                          }
                          if (tgt >= trade.currentPrice) {
                            return 'Target must be below current price';
                          }
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

                      onModifyTrade(trade.trade.id, newSl, newTgt);
                      Navigator.of(dialogContext).pop();
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

  Future<void> _showTradeOptionsDialog(BuildContext context) async {
    // Get the theme from the context
    final theme = Theme.of(context);

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
                // This button will use the default theme style
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showModifyTradeDialog(context);
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.close_rounded),
                label: const Text('Manually Close Trade'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _showManualCloseDialog(context);
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

  void _showMarketClosedErrorDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext errorDialogContext) {
        return AlertDialog(
          title: const Text('Market Closed'),
          content: const Text(
            'Trades can only be manually closed when the market is open.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(errorDialogContext).pop(); // Close error dialog
              },
            ),
          ],
        );
      },
    );
  }
}
