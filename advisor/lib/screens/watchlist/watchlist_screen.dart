import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/models/watchlist_item.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/widgets/watchlist_tile.dart';

class WatchlistScreen extends StatefulWidget {
  final Function(Stock) onCreateTrade;

  const WatchlistScreen({super.key, required this.onCreateTrade});

  @override
  State<WatchlistScreen> createState() => WatchlistScreenState();
}

class WatchlistScreenState extends State<WatchlistScreen> {
  List<WatchlistItem> _watchlist = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  Timer? _timer;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchWatchlist();
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

      final allStocks = await _apiService.getAllStocks();

      // Subscribe to all watchlist items
      for (var item in watchlistItems) {
        item.stockData = allStocks[item.stockSymbol];
        // Subscribe in background (don't await to avoid blocking UI)
        _apiService.subscribeToInstrument(item.stockSymbol);
      }

      if (mounted) {
        setState(() {
          _watchlist = watchlistItems;
          _isLoading = false;
        });
        _startPriceTimer();
      }
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

  void _startPriceTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 2),
          (timer) => _updateLivePrices(),
    );
    _updateLivePrices();
  }

  Future<void> _updateLivePrices() async {
    if (_watchlist.isEmpty || !mounted) return;
    try {
      final symbols = _watchlist.map((item) => item.stockSymbol).toList();
      final prices = await _apiService.getLivePrices(symbols);
      if (mounted) setState(() => _livePrices = prices);
    } catch (e) {
      debugPrint("Error fetching live prices: $e");
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
    _timer?.cancel();
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
        final livePrice =
            _livePrices[item.stockSymbol] ??
                item.stockData?.lastPrice ??
                0.0;
        final lastPrice = item.stockData?.lastPrice ?? 0.0;
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
