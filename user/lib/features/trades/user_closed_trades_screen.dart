import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/advisor_filter_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/models/trade_card_model.dart';
import 'package:signaldesk_user/view_models/closed_trade_card_view_model.dart';
import 'package:signaldesk_user/widgets/closed_trade_card.dart';
import 'package:signaldesk_user/widgets/filter_chip_row.dart';

class UserClosedTradesScreen extends StatefulWidget {
  const UserClosedTradesScreen({super.key});

  @override
  State<UserClosedTradesScreen> createState() => _UserClosedTradesScreenState();
}

class _UserClosedTradesScreenState extends State<UserClosedTradesScreen> {
  List<TradeCardModel> _tradeCards = [];
  List<ClosedTradeCardViewModel> _filteredTradeCards = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  RealtimeChannel? _tradesChannel;

  @override
  void initState() {
    super.initState();
    _fetchInitialClosedTrades();
    Provider.of<AdvisorFilterProvider>(
      context,
      listen: false,
    ).addListener(_fetchInitialClosedTrades);
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _tradesChannel = Supabase.instance.client.channel(
      'closed_trades_${DateTime.now().millisecondsSinceEpoch}',
    );
    _tradesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          callback: (payload) {
            final newData = payload.newRecord;
            final oldData = payload.oldRecord;
            bool shouldRefresh = false;
            if (payload.eventType == PostgresChangeEvent.insert ||
                payload.eventType == PostgresChangeEvent.update) {
              if (newData['status'] != 'open') {
                shouldRefresh = true;
              }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              if (oldData['status'] != 'open') {
                shouldRefresh = true;
              }
            }
            if (shouldRefresh && mounted) {
              _fetchInitialClosedTrades();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    Provider.of<AdvisorFilterProvider>(
      context,
      listen: false,
    ).removeListener(_fetchInitialClosedTrades);
    if (_tradesChannel != null) {
      Supabase.instance.client.removeChannel(_tradesChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchInitialClosedTrades() async {
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
        // No filter needed - get all closed trades
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .neq('status', 'open')
            .order('created_at', ascending: false);
      } else {
        // Apply multiple OR conditions for advisor filtering
        final orConditions = selectedIds
            .map((id) => 'advisor_id.eq.$id')
            .join(',');
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .neq('status', 'open')
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
                          ? 'No closed trades from your advisors.'
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
                        child: ClosedTradeCardWidget(trade: viewModel),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
