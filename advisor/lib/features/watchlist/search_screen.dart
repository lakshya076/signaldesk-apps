import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();
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

  Future<void> _loadAllStocks() async {
    try {
      final stocks = await _apiService.getAllStocks();
      if (mounted) {
        setState(() {
          _allStocks = stocks;
          _searchResults = stocks.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading stocks: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toUpperCase();
    setState(() {
      _searchResults =
      query.isEmpty
          ? _allStocks.values.toList()
          : _allStocks.values
          .where(
            (stock) =>
        stock.symbol.toUpperCase().contains(query) ||
            stock.name.toUpperCase().contains(query),
      )
          .toList();
    });
  }

  Future<void> _addToWatchlist(String symbol) async {
    try {
      final advisorId = Supabase.instance.client.auth.currentUser!.id;

      // Add to database
      await Supabase.instance.client.from('watchlists').insert({
        'advisor_id': advisorId,
        'stock_symbol': symbol,
      });

      // NEW: Subscribe to live data for this stock
      await _apiService.subscribeToInstrument(symbol);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$symbol added to watchlist and subscribed for live data',
            ),
            backgroundColor: Colors.green,
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
            backgroundColor: Colors.amber.shade800,
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
