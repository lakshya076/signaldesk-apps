import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/screens/advisor_main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/services/cache_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
  final _cacheService = CacheService();
  Map<String, Stock> _allStocks = {};
  List<Stock> _searchResults = [];
  final _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllStocks();
    _searchController.addListener(_onSearchChanged);
  }

  /// Loads stocks from cache if available and valid, otherwise fetches from API.
  Future<void> _loadAllStocks() async {
    setState(() => _isLoading = true);

    try {
      // 1. Try loading from cache
      final cachedData = await _cacheService.getInstrumentCache();
      if (cachedData != null) {
        debugPrint("Loading instruments from cache...");
        _processStockData(cachedData);
        return; // Successfully loaded from cache
      }

      // 2. Cache is invalid or missing, fetch from network
      debugPrint("Cache miss or expired. Fetching instruments from API...");
      final Map<String, dynamic> stockDataMap =
          await _apiService.getInstrumentList();

      // 3. Process and save to cache
      _processStockData(stockDataMap);
      await _cacheService.saveInstrumentCache(stockDataMap);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading stocks: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  /// Helper function to parse the JSON map into Stock objects and update state.
  void _processStockData(Map<String, dynamic> stockDataMap) {
    final stocks = stockDataMap.map((symbol, data) {
      return MapEntry(symbol, Stock.fromJson(symbol, data));
    });

    if (mounted) {
      setState(() {
        _allStocks = stocks;
        // Pre-populate search results with all stocks
        _searchResults =
            _searchController.text.isEmpty
                ? _allStocks.values.toList()
                : _filterStocks(_searchController.text);
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchResults = _filterStocks(_searchController.text);
    });
  }

  List<Stock> _filterStocks(String query) {
    if (query.isEmpty) {
      return _allStocks.values.toList();
    }
    final upperQuery = query.toUpperCase();
    return _allStocks.values
        .where(
          (stock) =>
              stock.symbol.toUpperCase().contains(upperQuery) ||
              stock.name.toUpperCase().contains(upperQuery),
        )
        .toList();
  }

  Future<void> _addToWatchlist(String symbol) async {
    try {
      final advisorId = Supabase.instance.client.auth.currentUser!.id;

      // Add to database
      await Supabase.instance.client.from('watchlists').insert({
        'advisor_id': advisorId,
        'stock_symbol': symbol,
      });

      final mainScreenState =
          context.findAncestorStateOfType<AdvisorMainScreenState>();
      final isMarketOpen = await _apiService.checkMarketStatus();

      if (isMarketOpen) {
        await _apiService.subscribeToInstrument(symbol);
      } else {
        await _apiService.backfillSubscribeInstrument(symbol);
      }

      mainScreenState?.wsSubscribe([symbol]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$symbol added to watchlist and subscribed for live data',
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      if (e is PostgrestException && e.code == '23505') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$symbol is already in your watchlist.'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to watchlist: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search for stocks...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _searchResults.isEmpty
                        ? const Center(child: Text("No stocks found"))
                        : ListView.builder(
                          controller: controller,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final stock = _searchResults[index];
                            return ListTile(
                              title: Text(stock.symbol),
                              subtitle: Text(stock.name),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  if (ModalRoute.of(context)?.settings.name ==
                                      'create_trade_search') {
                                    Navigator.pop(context, stock);
                                  } else {
                                    _addToWatchlist(stock.symbol);
                                  }
                                },
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
