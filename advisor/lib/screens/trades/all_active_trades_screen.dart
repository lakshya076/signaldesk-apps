import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/models/trade_card_model.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/view_models/active_trade_card_view_model.dart';
import 'package:signaldesk_advisor/widgets/active_trade_card.dart';
import 'package:signaldesk_advisor/widgets/filter_chip_row.dart';
import 'package:signaldesk_advisor/widgets/trade_card_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AllActiveTradesScreen extends StatefulWidget {
  final Stream<Map<String, dynamic>>? priceStream;
  final Function(List<String> symbols) onSubscribe;

  const AllActiveTradesScreen({
    super.key,
    this.priceStream,
    required this.onSubscribe,
  });

  @override
  State<AllActiveTradesScreen> createState() => _AllActiveTradesScreenState();
}

class _AllActiveTradesScreenState extends State<AllActiveTradesScreen> {
  List<TradeCardModel> _tradeCards = [];
  List<ActiveTradeCardViewModel> _filteredTradeCards = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  StreamSubscription? _priceSubscription;
  Map<String, Stock> _stockDataMap = {};
  final _apiService = ApiService();
  String _selectedFilter = 'All';
  RealtimeChannel? _tradesChannel;

  @override
  void initState() {
    super.initState();
    _fetchTradeCards();
    _setupRealtimeSubscription();
    _listenToPriceStream();
  }

  @override
  void didUpdateWidget(covariant AllActiveTradesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.priceStream != oldWidget.priceStream) {
      _listenToPriceStream();
    }
  }

  void _listenToPriceStream() {
    _priceSubscription?.cancel();
    _priceSubscription = widget.priceStream?.listen((priceData) {
      final symbol = priceData['symbol'] as String?;
      final ltp = (priceData['ltp'] as num?)?.toDouble();

      if (symbol != null && ltp != null && mounted) {
        if (_livePrices[symbol] != ltp) {
          setState(() {
            _livePrices[symbol] = ltp;
            _filterAndRefresh();
          });
        }
      }
    });
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
    _priceSubscription?.cancel();
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

      final Map<String, Stock> fetchedStockData = {};
      final Set<String> symbols = cards.map((c) => c.stockSymbol).toSet();

      final List<Future<void>> stockFutures = [];
      for (var symbol in symbols) {
        stockFutures.add(
          _apiService
              .getStockData(symbol)
              .then((stockJson) {
                if (stockJson != null && mounted) {
                  fetchedStockData[symbol] = Stock.fromJson(symbol, stockJson);
                }
              })
              .catchError((e) {
                debugPrint("Failed to fetch stock data for $symbol: $e");
              }),
        );
      }
      await Future.wait(stockFutures);

      if (mounted) {
        setState(() {
          _tradeCards = cards;
          _stockDataMap = fetchedStockData;
          _isLoading = false;
        });

        for (var card in cards) {
          _apiService.subscribeToInstrument(card.stockSymbol);
        }

        final Set<String> activeSymbols =
            cards.map((c) => c.stockSymbol).toSet();
        if (activeSymbols.isNotEmpty) {
          debugPrint(
            "[AllActive] Requesting WS subscription for ${activeSymbols.length} symbols...",
          );
          widget.onSubscribe(activeSymbols.toList());
        }

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
        _tradeCards.map((trade) {
          final prevClose = trade.lastPrice;
          final stockData = _stockDataMap[trade.stockSymbol];
          final livePrice =
              _livePrices[trade.stockSymbol] ??
              stockData?.ltp ??
              prevClose; // Fallback

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
    await _fetchTradeCards();
  }

  // This is the handler function from the previous step
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
            'manual_exit_price': closingPrice,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TradeCardHeader(
                                direction: viewModel.tradeDirection,
                                segment: viewModel.tradeSegment,
                                category: viewModel.tradeCategory,
                              ),
                              const SizedBox(height: 4),
                              ActiveTradeCardWidget(
                                trade: viewModel,
                                onManualClose: _handleManualClose,
                                onModifyTrade: _handleModifyTrade,
                                apiService: _apiService,
                              ),
                            ],
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
