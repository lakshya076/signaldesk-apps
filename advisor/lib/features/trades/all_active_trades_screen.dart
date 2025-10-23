import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/models/trade_card_model.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/view_models/active_trade_card_view_model.dart';
import 'package:signaldesk_advisor/widgets/active_trade_card.dart';
import 'package:signaldesk_advisor/widgets/filter_chip_row.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllActiveTradesScreen extends StatefulWidget {
  const AllActiveTradesScreen({super.key});

  @override
  State<AllActiveTradesScreen> createState() => _AllActiveTradesScreenState();
}

class _AllActiveTradesScreenState extends State<AllActiveTradesScreen> {
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
    _fetchTradeCards();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final advisorId = Supabase.instance.client.auth.currentUser!.id;
    final channelName =
        'active_trades_${advisorId}_${DateTime.now().millisecondsSinceEpoch}';

    _tradesChannel = Supabase.instance.client.channel(channelName);

    _tradesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'advisor_id',
            value: advisorId,
          ),
          callback: (payload) {
            if (mounted) {
              _fetchTradeCards();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tradesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchTradeCards() async {
    try {
      final advisorId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('trade_cards')
          .select()
          .eq('advisor_id', advisorId)
          .eq('status', 'open')
          .order('created_at', ascending: false);

      final cards =
          (response as List).map((e) => TradeCardModel.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _tradeCards = cards;
          _isLoading = false;
        });

        // NEW: Subscribe to all active trade symbols
        for (var card in cards) {
          _apiService.subscribeToInstrument(card.stockSymbol);
        }

        _filterAndRefresh();
        _startPriceTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching trades: $e")));
        setState(() => _isLoading = false);
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
      final prices = await _apiService.getLivePrices(symbols);
      if (mounted) {
        setState(() {
          _livePrices = prices;
          _filterAndRefresh();
        });
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

  Future<void> _refresh() async {
    _timer?.cancel();
    await _fetchTradeCards();
  }

  // This is the handler function from the previous step (unchanged)
  Future<void> _handleManualClose(
    String tradeId,
    String newStatus,
    double closingPrice,
  ) async {
    try {
      // Show a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await Supabase.instance.client
          .from('trade_cards')
          .update({
            'status': newStatus,
            'closed_at': 'now()',
            'last_price': closingPrice,
          })
          .eq('id', tradeId);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Hide loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade manually closed successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list to remove the closed trade
      _fetchTradeCards();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to close trade: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // ✅ ADDED: The handler function to update SL/TGT in Supabase
  Future<void> _handleModifyTrade(
    String tradeId,
    double newStopLoss,
    double newTarget,
  ) async {
    try {
      // Show a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await Supabase.instance.client
          .from('trade_cards')
          .update({'stop_loss': newStopLoss, 'target': newTarget})
          .eq('id', tradeId);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Hide loading

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade modified successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list to show the new values
      _fetchTradeCards();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to modify trade: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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
          child: RefreshIndicator(
            onRefresh: _refresh,
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredTradeCards.isEmpty
                    ? Center(
                      child: Text(
                        _tradeCards.isEmpty
                            ? 'You have no active trades.'
                            : 'No trades match the filter.',
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _filteredTradeCards.length,
                      itemBuilder: (context, index) {
                        final viewModel = _filteredTradeCards[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          // ✅ UPDATED: Pass both handlers to the widget
                          child: ActiveTradeCardWidget(
                            trade: viewModel,
                            onManualClose: _handleManualClose,
                            onModifyTrade: _handleModifyTrade,
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }
}
