import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/advisor_filter_provider.dart';
import 'package:signaldesk_user/models/stock.dart';
import 'package:signaldesk_user/widgets/trade_card_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/models/trade_card_model.dart';
import 'package:signaldesk_user/services/api_service.dart';
import 'package:signaldesk_user/view_models/active_trade_card_view_model.dart';
import 'package:signaldesk_user/widgets/active_trade_card.dart';
import 'package:signaldesk_user/widgets/filter_chip_row.dart';

class UserActiveTradesScreen extends StatefulWidget {
  final Stream<Map<String, dynamic>>? priceStream;
  final Function(List<String> symbols) onSubscribe;

  const UserActiveTradesScreen({
    super.key,
    this.priceStream,
    required this.onSubscribe,
  });

  @override
  State<UserActiveTradesScreen> createState() => _UserActiveTradesScreenState();
}

class _UserActiveTradesScreenState extends State<UserActiveTradesScreen> {
  List<TradeCardModel> _tradeCards = [];
  List<ActiveTradeCardViewModel> _filteredTradeCards = [];
  Map<String, double> _livePrices = {};
  Map<String, Stock> _stockDataMap = {};
  bool _isLoading = true;
  StreamSubscription? _priceSubscription;
  final _apiService = ApiService();
  String _selectedFilter = 'All';
  RealtimeChannel? _tradesChannel;

  Set<String> _currentlySubscribedSymbols = {};

  @override
  void initState() {
    super.initState();
    debugPrint("UserHomeScreen: initState called.");
    _fetchInitialTradeCards();
    Provider.of<AdvisorFilterProvider>(
      context,
      listen: false,
    ).addListener(_fetchInitialTradeCards);
    _setupRealtimeSubscription();
    _listenToPriceStream();
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
          });
        }
      }
    });
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
          callback: (payload) {
            if (!mounted) {
              debugPrint(
                "UserActiveTradesScreen: Received realtime event but screen is not mounted. Ignoring.",
              );
              return;
            }

            debugPrint(
              "UserActiveTradesScreen: Realtime event received. Type: ${payload.eventType}, Table: ${payload.table}",
            );

            _fetchInitialTradeCards();

            final eventType = payload.eventType;
            final newRecord = payload.newRecord;

            if (eventType == PostgresChangeEvent.insert) {
              debugPrint("UserActiveTradesScreen: Realtime INSERT detected.");
              try {
                final newTrade = TradeCardModel.fromJson(newRecord);
                debugPrint(
                  "UserActiveTradesScreen: Inserted Trade - Symbol: ${newTrade.stockSymbol}, Status: ${newTrade.status}",
                );
                if (newTrade.status == 'open') {
                  if (!_currentlySubscribedSymbols.contains(
                    newTrade.stockSymbol,
                  )) {
                    debugPrint(
                      "UserActiveTradesScreen: New active symbol found via INSERT: ${newTrade.stockSymbol}. Subscribing...",
                    );
                    widget.onSubscribe([newTrade.stockSymbol]);
                    _currentlySubscribedSymbols.add(newTrade.stockSymbol);
                  } else {
                    debugPrint(
                      "UserActiveTradesScreen: New active symbol ${newTrade.stockSymbol} already tracked. Skipping subscription.",
                    );
                  }
                }
              } catch (e) {
                debugPrint(
                  "UserActiveTradesScreen: Error processing INSERT payload: $e",
                );
              }
            } else if (eventType == PostgresChangeEvent.update) {
              debugPrint("UserActiveTradesScreen: Realtime UPDATE detected.");
              try {
                final updatedTrade = TradeCardModel.fromJson(newRecord);
                debugPrint(
                  "UserActiveTradesScreen: Updated Trade - Symbol: ${updatedTrade.stockSymbol}, Status: ${updatedTrade.status}",
                );

                // Check if it BECAME open
                if (updatedTrade.status == 'open' &&
                    !_currentlySubscribedSymbols.contains(
                      updatedTrade.stockSymbol,
                    )) {
                  debugPrint(
                    "UserActiveTradesScreen: Trade became active via UPDATE: ${updatedTrade.stockSymbol}. Subscribing...",
                  );

                  widget.onSubscribe([updatedTrade.stockSymbol]);

                  _currentlySubscribedSymbols.add(updatedTrade.stockSymbol);
                } else if (updatedTrade.status != 'open' &&
                    _currentlySubscribedSymbols.contains(
                      updatedTrade.stockSymbol,
                    )) {
                  debugPrint(
                    "UserActiveTradesScreen: Trade became inactive via UPDATE: ${updatedTrade.stockSymbol}. Consider unsubscribing.",
                  );
                } else if (updatedTrade.status == 'open') {
                  debugPrint(
                    "UserActiveTradesScreen: Updated active trade ${updatedTrade.stockSymbol} already tracked. Skipping subscription.",
                  );
                }
              } catch (e) {
                debugPrint(
                  "UserActiveTradesScreen: Error processing UPDATE payload: $e",
                );
              }
              debugPrint(
                "UserActiveTradesScreen: Triggering UI refresh via _fetchInitialTradeCards() after realtime event.",
              );
              _fetchInitialTradeCards();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _priceSubscription?.cancel();
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
        // Get all open trades
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

      final Map<String, Stock> fetchedStockData = {};
      final Set<String> symbols = cards.map((c) => c.stockSymbol).toSet();

      final List<Future<void>> stockFutures = [];
      for (var symbol in symbols) {
        stockFutures.add(
          _apiService
              .getStockData(symbol) // Assumes ApiService has getStockData
              .then((stockJson) {
                if (stockJson != null && mounted) {
                  // Assumes you have a Stock model
                  fetchedStockData[symbol] = Stock.fromJson(symbol, stockJson);
                }
              })
              .catchError((e) {
                debugPrint("Failed to fetch stock data for $symbol: $e");
              }),
        );
      }
      await Future.wait(stockFutures);

      _currentlySubscribedSymbols =
          cards
              .where((c) => c.status == 'open')
              .map((c) => c.stockSymbol)
              .toSet();

      if (mounted) {
        setState(() {
          _tradeCards = cards;
          _stockDataMap = fetchedStockData;
          _isLoading = false;
        });
        _filterAndRefresh();
      }

      if (_currentlySubscribedSymbols.isNotEmpty) {
        widget.onSubscribe(_currentlySubscribedSymbols.toList());
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
        _tradeCards.map((trade) {
          final stockData = _stockDataMap[trade.stockSymbol];
          final livePrice =
              _livePrices[trade.stockSymbol] ??
              stockData?.ltp ??
              trade.lastPrice;

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
                              direction: viewModel.tradeDirection,
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
