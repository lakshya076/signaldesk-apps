import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/models/trade_card_model.dart';
import 'package:signaldesk_advisor/view_models/closed_trade_card_view_model.dart';
import 'package:signaldesk_advisor/widgets/closed_trade_card.dart';
import 'package:signaldesk_advisor/widgets/filter_chip_row.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllClosedTradesScreen extends StatefulWidget {
  const AllClosedTradesScreen({super.key});

  @override
  State<AllClosedTradesScreen> createState() => _AllClosedTradesScreenState();
}

class _AllClosedTradesScreenState extends State<AllClosedTradesScreen> {
  List<TradeCardModel> _tradeCards = [];
  List<ClosedTradeCardViewModel> _filteredTradeCards = [];
  bool _isLoading = true;
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
        'closed_trades_${advisorId}_${DateTime.now().millisecondsSinceEpoch}';

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
          .neq('status', 'open')
          .order('created_at', ascending: false);

      final cards =
      (response as List).map((e) => TradeCardModel.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _tradeCards = cards;
          _isLoading = false;
        });
        _filterAndRefresh();
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

  void _onFilterChanged(String newFilter) {
    setState(() {
      _selectedFilter = newFilter;
      _filterAndRefresh();
    });
  }

  void _filterAndRefresh() {
    final allViewModels =
    _tradeCards
        .map((trade) => ClosedTradeCardViewModel(trade: trade))
        .toList();

    if (_selectedFilter == 'All') {
      _filteredTradeCards = allViewModels;
    } else {
      _filteredTradeCards =
          allViewModels.where((vm) {
            if (_selectedFilter == 'In Profit') {
              return vm.trade.status == 'closed_profit';
            }
            if (_selectedFilter == 'In Loss') {
              return vm.trade.status == 'closed_loss';
            }
            if (_selectedFilter == 'At Cost') {
              return vm.trade.status == 'closed_cost';
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
                  ? 'You have no closed trades.'
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
                child: ClosedTradeCardWidget(trade: viewModel),
              );
            },
          ),
        ),
      ],
    );
  }
}
