import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/screens/advisor_main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/models/watchlist_item.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/widgets/watchlist_tile.dart';
import 'package:signaldesk_advisor/services/cache_service.dart';

class WatchlistScreen extends StatefulWidget {
  final Function(Stock) onCreateTrade;
  final Stream<Map<String, dynamic>>? priceStream;

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
  Map<String, double> _prevClosePrices = {};
  bool _isLoading = true;
  final _apiService = ApiService();
  final _cacheService = CacheService();
  StreamSubscription? _priceSubscription;

  @override
  void initState() {
    super.initState();
    _initializeWatchlist();
  }

  /// Loads cached data first, then fetches network data.
  Future<void> _initializeWatchlist() async {
    await _loadAllCaches();
    _fetchWatchlist();
    _listenToPriceStream();
  }

  /// Loads all price caches from the CacheService.
  Future<void> _loadAllCaches() async {
    final priceCache = await _cacheService.getPriceCaches();
    if (mounted) {
      setState(() {
        _livePrices = priceCache.livePrices;
        _prevClosePrices = priceCache.prevClosePrices;
      });
      debugPrint(
        "Watchlist: Loaded ${priceCache.livePrices.length} cached prices.",
      );
      debugPrint(
        "Watchlist: Loaded ${priceCache.prevClosePrices.length} cached 'prev_close' prices.",
      );
    }
  }

  @override
  void didUpdateWidget(covariant WatchlistScreen oldWidget) {
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
          });
          // Save updated prices to cache
          _cacheService.saveLivePrices(_livePrices);
        }
      }
    });
  }

  /// Public method that can be called from the GlobalKey
  Future<void> fetchWatchlistPublic() async {
    await _internalFetchWatchlist();
  }

  Future<void> _fetchWatchlist() async {
    await _internalFetchWatchlist();
  }

  Future<void> _internalFetchWatchlist() async {
    // Only show loading spinner on the very first load
    if (_watchlist.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      // 1. Fetch user's watchlist symbols from Supabase (this is fast)
      final advisorId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('watchlists')
          .select('id, stock_symbol')
          .eq('advisor_id', advisorId);

      final supabaseItems =
          (response as List)
              .map(
                (item) => WatchlistItem(
                  id: item['id'],
                  stockSymbol: item['stock_symbol'],
                ),
              )
              .toList();

      // 2. Try to load static data from the shared instrument cache
      final cachedData = await _cacheService.getInstrumentCache();
      Map<String, dynamic>? allStocksMap;

      if (cachedData != null) {
        allStocksMap = cachedData;
      }

      // 3. (CACHE-FIRST BUILD) Instantly build the UI with cached data
      if (allStocksMap != null) {
        debugPrint("Watchlist: Building UI from cache...");
        final List<WatchlistItem> cachedWatchlist = [];
        for (var item in supabaseItems) {
          final stockDetails = allStocksMap[item.stockSymbol];
          if (stockDetails != null) {
            item.stockData = Stock.fromJson(
              item.stockSymbol,
              stockDetails as Map<String, dynamic>,
            );
            cachedWatchlist.add(item);
          }
        }
        if (mounted) {
          setState(() {
            _watchlist = cachedWatchlist;
            _isLoading = false; // <-- UI appears now
          });
        }
      }

      // 4. (NETWORK FETCH) Check which symbols need fresh data
      final List<Future<Map<String, dynamic>?>> stockDataFutures = [];
      final List<String> symbolsToFetch = [];
      final bool isPrevCloseCacheStale = _cacheService.isPrevCloseCacheStale();

      for (var item in supabaseItems) {
        // Only fetch if cache is stale OR this symbol is missing from the prevClose cache
        if (isPrevCloseCacheStale ||
            !_prevClosePrices.containsKey(item.stockSymbol)) {
          stockDataFutures.add(_apiService.getStockData(item.stockSymbol));
          symbolsToFetch.add(item.stockSymbol);
        }
      }

      debugPrint(
        "Watchlist: Fetching fresh data for ${symbolsToFetch.length} symbols.",
      );

      final List<Map<String, dynamic>?> networkStockData = await Future.wait(
        stockDataFutures,
      );

      // Map results back to symbols
      final Map<String, Map<String, dynamic>> fetchedDataMap = {};
      for (int i = 0; i < symbolsToFetch.length; i++) {
        if (networkStockData[i] != null) {
          fetchedDataMap[symbolsToFetch[i]] = networkStockData[i]!;
        }
      }

      final List<String> symbolsToSubscribe = [];
      final List<WatchlistItem> updatedWatchlist = [];
      bool newPrevCloseData = false;

      // 5. (MERGE DATA) Create the final list
      for (int i = 0; i < supabaseItems.length; i++) {
        final item = supabaseItems[i];
        final stockDataJson =
            fetchedDataMap[item.stockSymbol]; // Data from network (if any)

        if (stockDataJson != null) {
          // We got new data from network
          item.stockData = Stock.fromJson(item.stockSymbol, stockDataJson);

          if (item.stockData?.ltp != null) {
            _livePrices[item.stockSymbol] = item.stockData!.ltp!;
          }
          if (item.stockData?.prevCloseRedis != null) {
            _prevClosePrices[item.stockSymbol] = item.stockData!.prevCloseRedis!;
            newPrevCloseData = true;
          }
          updatedWatchlist.add(item);
        } else {
          // No network data needed or fetch failed. Use the cached version.
          final existingItem = _watchlist.firstWhere(
            (w) => w.stockSymbol == item.stockSymbol,
            orElse: () => item, // Fallback
          );

          // Ensure stockData is at least the cached version
          item.stockData = existingItem.stockData;

          if (item.stockData != null) {
            // We have at least the static data
            updatedWatchlist.add(item);
          }
        }
        symbolsToSubscribe.add(item.stockSymbol); // Subscribe regardless
      }

      // 6. Update UI with fresh prices and save caches
      if (mounted) {
        setState(() {
          _watchlist = updatedWatchlist;
          _isLoading = false; // <-- Hides spinner if cache was missed
        });
        _cacheService.saveLivePrices(_livePrices); // Save latest live prices

        // Only save/update timestamp if we actually got new data or cache was stale
        if (newPrevCloseData ||
            (isPrevCloseCacheStale && symbolsToFetch.isNotEmpty)) {
          _cacheService.savePrevClosePrices(_prevClosePrices);
        }
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

                  // Optimistic UI update: remove from list locally
                  setState(() {
                    _watchlist.removeWhere((w) => w.id == item.id);
                    _livePrices.remove(stockSymbol);
                    _prevClosePrices.remove(stockSymbol);
                  });
                  _cacheService.saveLivePrices(_livePrices);
                  _cacheService.savePrevClosePrices(_prevClosePrices);
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
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _watchlist.isEmpty
        ? const Center(
          child: Text(
            "Your watchlist is empty.\nAdd stocks using the '+' button.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        )
        : ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _watchlist.length,
          itemBuilder: (context, index) {
            final item = _watchlist[index];

            // Use our new map as the primary source for prevClose
            final prevClose = _prevClosePrices[item.stockSymbol] ?? 0.0;

            // Use livePrice if available, otherwise ltp, otherwise fallback to prevClose
            final livePrice =
                _livePrices[item.stockSymbol] ??
                item.stockData?.ltp ??
                prevClose; // Use prevClose as ultimate fallback

            final change = livePrice - prevClose;
            final percentChange =
                prevClose != 0 ? (change / prevClose) * 100 : 0.0;

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
