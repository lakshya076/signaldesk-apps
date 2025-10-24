import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/advisor_filter_provider.dart';
import 'package:signaldesk_user/widgets/trade_card_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/models/trade_card_model.dart';
import 'package:signaldesk_user/services/api_service.dart';
import 'package:signaldesk_user/view_models/active_trade_card_view_model.dart';
import 'package:signaldesk_user/view_models/closed_trade_card_view_model.dart';
import 'package:signaldesk_user/widgets/active_trade_card.dart';
import 'package:signaldesk_user/widgets/closed_trade_card.dart';

class UserHomeScreen extends StatefulWidget {
  final VoidCallback onViewActive;
  final VoidCallback onViewClosed;

  const UserHomeScreen({
    super.key,
    required this.onViewActive,
    required this.onViewClosed,
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  List<TradeCardModel> _activeTrades = [];
  List<TradeCardModel> _closedTrades = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  Timer? _timer;
  final _apiService = ApiService();
  RealtimeChannel? _tradesChannel;

  Set<String> _currentlySubscribedSymbols = {};

  @override
  void initState() {
    super.initState();
    debugPrint("UserHomeScreen: initState called.");
    _fetchTradeCards();
    Provider.of<AdvisorFilterProvider>(
      context,
      listen: false,
    ).addListener(_fetchTradeCards);
    _initializeRealtimeSubscription();
  }

  void _initializeRealtimeSubscription() {
    try {
      final channelName =
          'trade_cards_home_${DateTime.now().millisecondsSinceEpoch}';
      _tradesChannel = Supabase.instance.client.channel(channelName);
      _tradesChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trade_cards',
            callback: (payload) {
              if (!mounted) return;
              debugPrint(
                "UserHomeScreen: Realtime event received. Type: ${payload.eventType}, Table: ${payload.table}",
              );
              if (!mounted) {
                debugPrint(
                  "UserHomeScreen: Received realtime event but screen is not mounted. Ignoring.",
                );
                return;
              }
              final eventType = payload.eventType;
              final newRecord = payload.newRecord;

              if (eventType == PostgresChangeEvent.insert) {
                debugPrint("UserHomeScreen: Realtime INSERT detected.");
                try {
                  final newTrade = TradeCardModel.fromJson(newRecord);
                  debugPrint(
                    "UserHomeScreen: Inserted Trade - Symbol: ${newTrade.stockSymbol}, Status: ${newTrade.status}",
                  );
                  if (newTrade.status == 'open') {
                    if (!_currentlySubscribedSymbols.contains(
                      newTrade.stockSymbol,
                    )) {
                      debugPrint(
                        "UserHomeScreen: New active symbol found via INSERT: ${newTrade.stockSymbol}. Subscribing...",
                      );
                      _apiService.subscribeToInstrument(newTrade.stockSymbol);
                      _currentlySubscribedSymbols.add(newTrade.stockSymbol);
                    } else {
                      debugPrint(
                        "UserHomeScreen: New active symbol ${newTrade.stockSymbol} already tracked. Skipping subscription.",
                      );
                    }
                  }
                } catch (e) {
                  debugPrint(
                    "UserHomeScreen: Error processing INSERT payload: $e",
                  );
                }
              } else if (eventType == PostgresChangeEvent.update) {
                debugPrint("UserHomeScreen: Realtime UPDATE detected.");
                try {
                  final updatedTrade = TradeCardModel.fromJson(newRecord);
                  debugPrint(
                    "UserHomeScreen: Updated Trade - Symbol: ${updatedTrade.stockSymbol}, Status: ${updatedTrade.status}",
                  );

                  // Check if it BECAME open
                  if (updatedTrade.status == 'open' &&
                      !_currentlySubscribedSymbols.contains(
                        updatedTrade.stockSymbol,
                      )) {
                    debugPrint(
                      "UserHomeScreen: Trade became active via UPDATE: ${updatedTrade.stockSymbol}. Subscribing...",
                    );
                    _apiService.subscribeToInstrument(updatedTrade.stockSymbol);
                    _currentlySubscribedSymbols.add(updatedTrade.stockSymbol);
                  } else if (updatedTrade.status != 'open' &&
                      _currentlySubscribedSymbols.contains(
                        updatedTrade.stockSymbol,
                      )) {
                    debugPrint(
                      "UserHomeScreen: Trade became inactive via UPDATE: ${updatedTrade.stockSymbol}. Consider unsubscribing.",
                    );
                  } else if (updatedTrade.status == 'open') {
                    debugPrint(
                      "UserHomeScreen: Updated active trade ${updatedTrade.stockSymbol} already tracked. Skipping subscription.",
                    );
                  }
                } catch (e) {
                  debugPrint(
                    "UserHomeScreen: Error processing UPDATE payload: $e",
                  );
                }
                debugPrint(
                  "UserHomeScreen: Triggering UI refresh via _fetchTradeCards() after realtime event.",
                );
                _fetchTradeCards();
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    Provider.of<AdvisorFilterProvider>(
      context,
      listen: false,
    ).removeListener(_fetchTradeCards);
    if (_tradesChannel != null) {
      Supabase.instance.client.removeChannel(_tradesChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchTradeCards() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final selectedIds =
          Provider.of<AdvisorFilterProvider>(
            context,
            listen: false,
          ).selectedAdvisorIds;
      List<dynamic> response;
      if (selectedIds.isEmpty) {
        // No filter needed
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .order('created_at', ascending: false);
      } else {
        // Apply multiple OR conditions
        final orConditions = selectedIds
            .map((id) => 'advisor_id.eq.$id')
            .join(',');
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .or(orConditions)
            .order('created_at', ascending: false);
      }
      if (!mounted) return;
      final allCards = response.map((e) => TradeCardModel.fromJson(e)).toList();

      final newSymbolSet =
          allCards
              .where((c) => c.status == 'open')
              .map((c) => c.stockSymbol)
              .toSet();
      debugPrint(
        "UserHomeScreen: Updating tracked symbols. Old: ${_currentlySubscribedSymbols.length}, New: ${newSymbolSet.length}",
      );
      _currentlySubscribedSymbols = newSymbolSet;

      setState(() {
        _activeTrades = allCards.where((c) => c.status == 'open').toList();
        _closedTrades = allCards.where((c) => c.status != 'open').toList();
        _isLoading = false;
      });
      if (_activeTrades.isNotEmpty) {
        _startPriceTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching trades: $e")));
      }
    }
  }

  void _startPriceTimer() {
    _timer?.cancel();
    if (_activeTrades.isNotEmpty && mounted) {
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted && _activeTrades.isNotEmpty) {
          _updateLivePrices();
        } else {
          timer.cancel();
        }
      });
      _updateLivePrices();
    }
  }

  Future<void> _updateLivePrices() async {
    if (_activeTrades.isEmpty || !mounted) return;
    try {
      final symbols =
          _activeTrades.map((card) => card.stockSymbol).toSet().toList();
      if (symbols.isEmpty) return;
      final prices = await _apiService.getLivePrices(symbols);
      if (mounted) setState(() => _livePrices = prices);
    } catch (e) {
      debugPrint("Error fetching live prices for trades: $e");
    }
  }

  Future<void> _refresh() async {
    _timer?.cancel();
    await _fetchTradeCards();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSectionHeader('Active Trades', widget.onViewActive),
                  _buildTradeList(_activeTrades, true),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Closed Trades', widget.onViewClosed),
                  _buildTradeList(_closedTrades, false),
                ],
              ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewMore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextButton(onPressed: onViewMore, child: const Text('View More')),
      ],
    );
  }

  Widget _buildTradeList(List<TradeCardModel> trades, bool isActive) {
    if (trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text('No ${isActive ? 'active' : 'closed'} trades found.'),
        ),
      );
    }
    final displayTrades = trades.take(3).toList();
    return Column(
      children:
          displayTrades.map((trade) {
            if (isActive) {
              final livePrice =
                  _livePrices[trade.stockSymbol] ?? trade.lastPrice;
              final viewModel = ActiveTradeCardViewModel(
                trade: trade,
                currentPrice: livePrice,
              );
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TradeCardHeader(
                      advisorName: viewModel.advisorName,
                      segment: viewModel.tradeSegment,
                      category: viewModel.tradeCategory,
                    ),
                    const SizedBox(height: 4),
                    ActiveTradeCardWidget(trade: viewModel),
                  ],
                ),
              );
            } else {
              final viewModel = ClosedTradeCardViewModel(trade: trade);
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TradeCardHeader(
                      advisorName: viewModel.advisorName,
                      segment: viewModel.tradeSegment,
                      category: viewModel.tradeCategory,
                    ),
                    const SizedBox(height: 4),
                    ClosedTradeCardWidget(trade: viewModel),
                  ],
                ),
              );
            }
          }).toList(),
    );
  }
}
