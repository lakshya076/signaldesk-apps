import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/advisor_filter_provider.dart';
import 'package:signaldesk_user/widgets/trade_card_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/models/trade_card_model.dart';
import 'package:signaldesk_user/services/api_service.dart';
import 'package:signaldesk_user/view_models/active_trade_card_view_model.dart';
import 'package:signaldesk_user/widgets/active_trade_card.dart';
import 'package:signaldesk_user/widgets/filter_chip_row.dart';

class UserActiveTradesScreen extends StatefulWidget {
  const UserActiveTradesScreen({super.key});

  @override
  State<UserActiveTradesScreen> createState() => _UserActiveTradesScreenState();
}

class _UserActiveTradesScreenState extends State<UserActiveTradesScreen> {
  List<TradeCardModel> _tradeCards = [];
  List<ActiveTradeCardViewModel> _filteredTradeCards = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  Timer? _timer;
  final _apiService = ApiService();
  String _selectedFilter = 'All';
  RealtimeChannel? _tradesChannel;

  @override
  void initState() {
    super.initState();
    _fetchInitialTradeCards();
    Provider.of<AdvisorFilterProvider>(
      context,
      listen: false,
    ).addListener(_fetchInitialTradeCards);
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _tradesChannel = Supabase.instance.client.channel(
      'active_trades_${DateTime.now().millisecondsSinceEpoch}',
    );
    _tradesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'open',
          ),
          callback: (payload) {
            if (mounted) _fetchInitialTradeCards();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    Provider.of<AdvisorFilterProvider>(
      context,
      listen: false,
    ).removeListener(_fetchInitialTradeCards);
    if (_tradesChannel != null) {
      Supabase.instance.client.removeChannel(_tradesChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchInitialTradeCards() async {
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
        // No filter needed - get all open trades
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .eq('status', 'open')
            .order('created_at', ascending: false);
      } else {
        // Apply multiple OR conditions for advisor filtering
        final orConditions = selectedIds
            .map((id) => 'advisor_id.eq.$id')
            .join(',');
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .eq('status', 'open')
            .or(orConditions)
            .order('created_at', ascending: false);
      }

      if (!mounted) return;
      final cards = response.map((e) => TradeCardModel.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _tradeCards = cards;
          _isLoading = false;
        });
        _filterAndRefresh();
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
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _updateLivePrices(),
    );
    _updateLivePrices();
  }

  Future<void> _updateLivePrices() async {
    if (_tradeCards.isEmpty || !mounted) return;
    try {
      final symbols =
          _tradeCards.map((card) => card.stockSymbol).toSet().toList();
      if (symbols.isEmpty) return;
      final prices = await _apiService.getLivePrices(symbols);
      if (mounted) {
        setState(() {
          _livePrices = prices;
        });
        _filterAndRefresh();
      }
    } catch (e) {
      debugPrint("Error fetching live prices for trades: $e");
    }
  }

  void _onFilterChanged(String newFilter) {
    setState(() {
      _selectedFilter = newFilter;
      _filterAndRefresh();
    });
  }

  void _filterAndRefresh() {
    final allViewModels =
        _tradeCards.map((trade) {
          final livePrice = _livePrices[trade.stockSymbol] ?? trade.lastPrice;
          return ActiveTradeCardViewModel(
            trade: trade,
            currentPrice: livePrice,
          );
        }).toList();
    if (_selectedFilter == 'All') {
      _filteredTradeCards = allViewModels;
    } else {
      _filteredTradeCards =
          allViewModels.where((vm) {
            if (_selectedFilter == 'In Profit') return vm.liveReturnValue > 0;
            if (_selectedFilter == 'In Loss') return vm.liveReturnValue < 0;
            if (_selectedFilter == 'At Cost') {
              return vm.liveReturnValue.abs() < 0.1;
            }
            return false;
          }).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: FilterChipRowWidget(
            selectedFilter: _selectedFilter,
            onFilterChanged: _onFilterChanged,
          ),
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTradeCards.isEmpty
                  ? Center(
                    child: Text(
                      _tradeCards.isEmpty
                          ? 'No active trades from your advisors.'
                          : 'No trades match the filter.',
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _filteredTradeCards.length,
                    itemBuilder: (context, index) {
                      final viewModel = _filteredTradeCards[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
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
                    },
                  ),
        ),
      ],
    );
  }
}
