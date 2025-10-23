import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:signaldesk_advisor/features/advisor_home_screen.dart';
import 'package:signaldesk_advisor/features/trades/all_active_trades_screen.dart';
import 'package:signaldesk_advisor/features/trades/all_closed_trades_screen.dart';
import 'package:signaldesk_advisor/features/trades/create_trade_card_screen.dart';
import 'package:signaldesk_advisor/features/watchlist/search_screen.dart';
import 'package:signaldesk_advisor/features/watchlist/watchlist_screen.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_advisor/core/theme_provider.dart';

class AdvisorMainScreen extends StatefulWidget {
  const AdvisorMainScreen({super.key});

  @override
  AdvisorMainScreenState createState() => AdvisorMainScreenState();
}

class AdvisorMainScreenState extends State<AdvisorMainScreen> {
  int _selectedIndex = 0;
  Stock? _stockToCreateTrade;

  final ApiService _apiService = ApiService();
  bool _isCheckingMarket = false;

  // Key to access the WatchlistScreen's state and call its refresh method
  final GlobalKey<WatchlistScreenState> _watchlistKey =
      GlobalKey<WatchlistScreenState>();

  void onItemTapped(int index) {
    if (index == 4) {
      // User tapped "Create", run our check
      _navigateToCreateTrade();
    } else {
      // User tapped something else, just change the screen
      setState(() {
        if (index != 4) _stockToCreateTrade = null;
        _selectedIndex = index;
      });
    }
  }

  Future<void> _showMarketClosedDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Market Closed'),
          content: const SingleChildScrollView(
            child: Text('Trade creation is disabled outside of market hours.'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToCreateTrade([Stock? stock]) async {
    if (_isCheckingMarket) return; // Prevent double-taps

    setState(() {
      _isCheckingMarket = true;
    });

    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final isMarketOpen = await _apiService.checkMarketStatus();

    // Hide loading dialog
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    setState(() {
      _isCheckingMarket = false;
    });

    if (!mounted) return;

    if (isMarketOpen) {
      // Market is open, proceed
      setState(() {
        _stockToCreateTrade = stock;
        _selectedIndex = 4;
      });
    } else {
      // Market is closed, show popup
      _showMarketClosedDialog();
    }
  }

  // A method to refresh the watchlist from this parent widget
  void _refreshWatchlist() {
    _watchlistKey.currentState?.fetchWatchlistPublic();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      AdvisorHomeScreen(
        onViewActive: () => onItemTapped(1),
        onViewClosed: () => onItemTapped(2),
      ),
      const AllActiveTradesScreen(),
      const AllClosedTradesScreen(),
      // Assign the GlobalKey to the WatchlistScreen instance
      WatchlistScreen(
        key: _watchlistKey,
        onCreateTrade: (stock) {
          _navigateToCreateTrade(stock);
        },
      ),
      CreateTradeCardScreen(preselectedStock: _stockToCreateTrade),
    ];

    final List<String> titles = [
      'Home',
      'Active Trades',
      'Closed Trades',
      'Watchlist',
      'Create Trade Idea',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () async {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: Center(child: widgetOptions.elementAt(_selectedIndex)),
      floatingActionButton:
          _selectedIndex ==
                  3 // Show only for Watchlist
              ? FloatingActionButton(
                onPressed: () async {
                  final result = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const SearchScreen(),
                  );
                  // If a stock was added (result is true), refresh the list
                  if (result == true) {
                    _refreshWatchlist();
                  }
                },
                // The backgroundColor property has been removed.
                // The button will now use the color from the active theme.
                child: const Icon(Icons.add),
              )
              : null, // Do not show on other screens
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Active',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Closed'),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: 'Watchlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: onItemTapped, // This now points to our updated function
      ),
    );
  }
}
