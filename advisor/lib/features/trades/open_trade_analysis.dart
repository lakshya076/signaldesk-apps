import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signaldesk_advisor/models/trade_card_model.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/view_models/active_trade_card_view_model.dart';
import 'package:signaldesk_advisor/widgets/live_trade_indicator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OpenTradeAnalysis extends StatefulWidget {
  final ActiveTradeCardViewModel activeTrade;

  const OpenTradeAnalysis({super.key, required this.activeTrade});

  @override
  State<OpenTradeAnalysis> createState() => _OpenTradeAnalysisState();
}

class _OpenTradeAnalysisState extends State<OpenTradeAnalysis> {
  late TradeCardModel _tradeData;
  late double _livePrice;

  final _apiService = ApiService();
  Timer? _priceTimer;
  RealtimeChannel? _tradeChannel;

  @override
  void initState() {
    super.initState();
    _tradeData = widget.activeTrade.trade;
    _livePrice = widget.activeTrade.currentPrice;

    _startPriceTimer();
    _setupRealtimeSubscription();
  }

  void _startPriceTimer() {
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateLivePrice(),
    );
  }

  Future<void> _updateLivePrice() async {
    if (!mounted) return;
    try {
      final prices = await _apiService.getLivePrices([_tradeData.stockSymbol]);
      if (mounted && prices.containsKey(_tradeData.stockSymbol)) {
        setState(() {
          _livePrice = prices[_tradeData.stockSymbol]!;
        });
      }
    } catch (e) {
      debugPrint("Failed to update live price on detail screen: $e");
    }
  }

  void _setupRealtimeSubscription() {
    final channelName =
        'trade_${_tradeData.id}_${DateTime.now().millisecondsSinceEpoch}';

    _tradeChannel = Supabase.instance.client.channel(channelName);

    _tradeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _tradeData.id,
          ),
          callback: (payload) {
            if (!mounted) return;

            final eventType = payload.eventType;

            if (eventType == PostgresChangeEvent.update) {
              try {
                final updatedRecord = TradeCardModel.fromJson(
                  payload.newRecord,
                );
                setState(() {
                  _tradeData = updatedRecord;
                });
                if (updatedRecord.status != 'open') {
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) Navigator.of(context).pop();
                  });
                }
              } catch (e) {
                debugPrint('Error parsing updated trade record: $e');
              }
            } else if (eventType == PostgresChangeEvent.delete) {
              // If the trade is deleted, pop the screen
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) Navigator.of(context).pop();
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _tradeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Create the ViewModel inside the build method using the latest state
    final viewModel = ActiveTradeCardViewModel(
      trade: _tradeData,
      currentPrice: _livePrice,
    );

    // If the status is no longer 'open', you might want to show a message
    if (_tradeData.status != 'open') {
      return Scaffold(
        appBar: AppBar(title: const Text('Trade Analysis')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'This trade has been closed.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Status: ${_tradeData.status.replaceAll('_', ' ').toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Trade Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeader(context, viewModel),
          const SizedBox(height: 24),
          _buildLiveIndicator(context, viewModel),
          const SizedBox(height: 24),
          _buildLevels(context, viewModel),
          const SizedBox(height: 16),
          _buildStats(context, viewModel),
          const SizedBox(height: 16),
          _buildDetailsCard(context, viewModel),
        ],
      ),
    );
  }

  // --- Helper methods now take the ViewModel ---

  Widget _buildHeader(BuildContext context, ActiveTradeCardViewModel trade) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
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
        const SizedBox(width: 16),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              trade.currentPriceFormatted,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Last Close: ₹${trade.trade.lastPrice.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveIndicator(
    BuildContext context,
    ActiveTradeCardViewModel trade,
  ) {
    return LiveTradeIndicator(
      stopLoss: trade.trade.stopLoss,
      target: trade.trade.target,
      entryPrice: trade.trade.entryPrice,
      currentPrice: trade.currentPrice,
      tradeDirection: trade.trade.tradeDirection, // Add this line
    );
  }

  Widget _buildLevels(BuildContext context, ActiveTradeCardViewModel trade) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLevelItem(context, 'Entry', trade.entryPrice),
          Container(
            width: 1,
            height: 30,
            color: Theme.of(context).dividerColor,
          ),
          _buildLevelItem(context, 'Stop Loss', trade.stopLoss),
          Container(
            width: 1,
            height: 30,
            color: Theme.of(context).dividerColor,
          ),
          _buildLevelItem(context, 'Target', trade.targetPrice),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, ActiveTradeCardViewModel trade) {
    final theme = Theme.of(context);
    final isProfit = trade.isProfit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatItem(
                  context,
                  'Estimated Gain',
                  trade.estimatedGain,
                  theme.colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                _buildStatItem(
                  context,
                  'Live Return',
                  trade.liveReturn,
                  isProfit
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.error,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatItem(
                  context,
                  'Estimated Risk',
                  '-${((trade.trade.entryPrice - trade.trade.stopLoss) / trade.trade.entryPrice * 100).toStringAsFixed(2)}%',
                  theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                _buildStatItem(
                  context,
                  'Risk/Reward',
                  '${((trade.trade.target - trade.trade.entryPrice) / (trade.trade.entryPrice - trade.trade.stopLoss)).abs().toStringAsFixed(2)}x',
                  theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    ActiveTradeCardViewModel trade,
  ) {
    final theme = Theme.of(context);
    final statusColor =
        trade.isProfit ? theme.colorScheme.secondary : theme.colorScheme.error;

    final DateTime istEntryTime = trade.createdAt.add(
      const Duration(hours: 5, minutes: 30),
    );

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
            _buildDetailRow(
              context,
              'Entry Date & Time',
              DateFormat('d MMM h:mma').format(istEntryTime),
            ),
            _buildDetailRow(
              context,
              'Live Status',
              trade.liveStatus,
              valueColor: statusColor,
            ),
            _buildDetailRow(context, 'Stop Loss', trade.stopLoss),
            _buildDetailRow(context, 'Target', trade.targetPrice),
            _buildDetailRow(context, 'Trade Direction', trade.tradeDirection),
            _buildDetailRow(context, 'Trade Category', trade.tradeCategory),
            _buildDetailRow(context, 'Trade Segment', trade.tradeSegment),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
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
          style: theme.textTheme.bodyLarge?.copyWith(
            color: valueColor,
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
