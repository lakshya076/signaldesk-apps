import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/features/watchlist/set_alert_screen.dart';
import 'package:signaldesk_advisor/models/stock.dart';

class WatchlistTile extends StatefulWidget {
  final Stock? stock;
  final double livePrice;
  final double change;
  final double percentChange;
  final Function(Stock) onCreateTrade;

  const WatchlistTile({
    super.key,
    this.stock,
    required this.livePrice,
    required this.change,
    required this.percentChange,
    required this.onCreateTrade,
  });

  @override
  State<WatchlistTile> createState() => WatchlistTileState();
}

class WatchlistTileState extends State<WatchlistTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.stock == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isPositive = widget.change >= 0;
    final color =
    isPositive ? theme.colorScheme.secondary : theme.colorScheme.error;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stock!.symbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.stock!.name,
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${widget.livePrice.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isPositive ? '+' : ''}${widget.change.toStringAsFixed(2)} (${widget.percentChange.toStringAsFixed(2)}%)',
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ],
                ),
              ],
            ),
            if (_isExpanded)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 32),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => SetAlertScreen(
                            isPositive: isPositive,
                            stock: widget.stock!,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      // Adds vertical padding to make tapping easier
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_none,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Set Alert',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => widget.onCreateTrade(widget.stock!),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Create Trade Idea'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
