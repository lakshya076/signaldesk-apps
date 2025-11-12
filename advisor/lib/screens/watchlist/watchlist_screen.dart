import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/screens/advisor_main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/models/watchlist_item.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/widgets/watchlist_tile.dart';

class WatchlistScreen extends StatefulWidget {
  final Function(Stock) onCreateTrade;

  final Stream<Map<String, dynamic>>? priceStream; // Updated type

  const WatchlistScreen({
    super.key,
    required this.onCreateTrade,
    this.priceStream,
  });

  @override
  State<WatchlistScreen> createState() => WatchlistScreenState();
}

class WatchlistScreenState extends State<WatchlistScreen> {
  List<WatchlistItem> _watchlist = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  final _apiService = ApiService();
  StreamSubscription? _priceSubscription;

  @override
  void initState() {
    super.initState();
    _fetchWatchlist();
    _listenToPriceStream();
  }

  @override
  void didUpdateWidget(covariant WatchlistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the stream instance changes, re-subscribe
    if (widget.priceStream != oldWidget.priceStream) {
      _listenToPriceStream();
    }
  }

  void _listenToPriceStream() {
    _priceSubscription?.cancel(); // Cancel old one if exists
    _priceSubscription = widget.priceStream?.listen((priceData) {
      final symbol = priceData['symbol'] as String?;
      final ltp = (priceData['ltp'] as num?)?.toDouble();

      if (symbol != null && ltp != null) {
        if (mounted) {
          // Only update if the price is different
          if (_livePrices[symbol] != ltp) {
            setState(() {
              _livePrices[symbol] = ltp;
            });
          }
        }
      }
    });
  }

  // Renamed to be more descriptive and avoid conflict
  Future<void> _internalFetchWatchlist() async {
    if (_watchlist.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final advisorId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('watchlists')
          .select('id, stock_symbol')
          .eq('advisor_id', advisorId);

      final watchlistItems =
          (response as List)
              .map(
                (item) => WatchlistItem(
                  id: item['id'],
                  stockSymbol: item['stock_symbol'],
                ),
              )
              .toList();

      //final allStocks = await _apiService.getAllStocks();
      final List<Future<Map<String, dynamic>?>> stockDataFutures = [];
      for (var item in watchlistItems) {
        stockDataFutures.add(_apiService.getStockData(item.stockSymbol));
      }

      final List<Map<String, dynamic>?> allStockData = await Future.wait(
        stockDataFutures,
      );

      final List<String> symbolsToSubscribe = [];
      final List<WatchlistItem> updatedWatchlist = [];

      for (int i = 0; i < watchlistItems.length; i++) {
        final item = watchlistItems[i];
        final stockDataJson = allStockData[i];

        if (stockDataJson != null) {
          // Create the Stock object from the JSON
          item.stockData = Stock.fromJson(item.stockSymbol, stockDataJson);
          updatedWatchlist.add(item); // Add to the new list
          symbolsToSubscribe.add(item.stockSymbol);
        } else {
          debugPrint("Could not find data for ${item.stockSymbol}");
        }
      }

      if (mounted) {
        setState(() {
          _watchlist = updatedWatchlist; // Use the new list
          _isLoading = false;
        });
      }
      final mainScreenState =
          context.findAncestorStateOfType<AdvisorMainScreenState>();
      mainScreenState?.wsSubscribe(symbolsToSubscribe);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching watchlist: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  // Public method that can be called from the GlobalKey
  Future<void> fetchWatchlistPublic() async {
    await _internalFetchWatchlist();
  }

  // This is the original method name, now it calls the new internal one
  Future<void> _fetchWatchlist() async {
    await _internalFetchWatchlist();
  }

  Future<void> _showDeleteConfirmationDialog(WatchlistItem item) async {
    if (item.stockData == null) return;

    final stockSymbol = item.stockData!.symbol;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Remove from Watchlist?'),
          content: Text(
            'Are you sure you want to remove $stockSymbol from your watchlist?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Remove'),
              onPressed: () async {
                try {
                  // Delete from database
                  await Supabase.instance.client
                      .from('watchlists')
                      .delete()
                      .match({'id': item.id});

                  await _apiService.unsubscribeFromInstrument(stockSymbol);

                  final mainScreenState =
                      context.findAncestorStateOfType<AdvisorMainScreenState>();
                  mainScreenState?.wsUnsubscribe([stockSymbol]);

                  if (!mounted) return;

                  Navigator.of(dialogContext).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$stockSymbol removed from watchlist'),
                      backgroundColor: theme.colorScheme.error,
                    ),
                  );

                  _fetchWatchlist();
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to remove stock: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _priceSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The Scaffold has been completely removed from this widget.
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _watchlist.length,
          itemBuilder: (context, index) {
            final item = _watchlist[index];

            final lastPrice = item.stockData?.lastPrice ?? 0.0;

            final livePrice =
                _livePrices[item.stockSymbol] ??
                item.stockData?.ltp ??
                lastPrice;

            final change = livePrice - lastPrice;
            final percentChange =
                lastPrice != 0 ? (change / lastPrice) * 100 : 0.0;

            return InkWell(
              onLongPress: () {
                _showDeleteConfirmationDialog(item);
              },
              child: WatchlistTile(
                stock: item.stockData,
                livePrice: livePrice,
                change: change,
                percentChange: percentChange,
                onCreateTrade: widget.onCreateTrade,
              ),
            );
          },
        );
  }
}
