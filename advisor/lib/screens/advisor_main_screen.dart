import 'package:signaldesk_advisor/core/config.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:signaldesk_advisor/screens/advisor_home_screen.dart';
import 'package:signaldesk_advisor/screens/trades/all_active_trades_screen.dart';
import 'package:signaldesk_advisor/screens/trades/all_closed_trades_screen.dart';
import 'package:signaldesk_advisor/screens/trades/create_trade_card_screen.dart';
import 'package:signaldesk_advisor/screens/watchlist/search_screen.dart';
import 'package:signaldesk_advisor/screens/watchlist/watchlist_screen.dart';
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

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _priceStreamController =
      StreamController.broadcast();
  late final Stream<Map<String, dynamic>> _priceStream;
  Timer? _reconnectTimer;
  bool _isWsConnected = false;
  final Set<String> _wsSubscriptions = {};
  final String _wsUrl = wsPricesUrl;

  @override
  void initState() {
    super.initState();
    _priceStream = _priceStreamController.stream;
    _connectWebSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToAllInstruments();
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _priceStreamController.close();
    super.dispose();
  }

  void _connectWebSocket() {
    if (_isWsConnected || _reconnectTimer != null) {
      return; // Already connected or trying
    }
    debugPrint("WebSocket: Connecting to $_wsUrl...");

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      setState(() => _isWsConnected = true); // Assume connected for now

      _channel!.stream.listen(
        (message) {
          if (!_isWsConnected) setState(() => _isWsConnected = true);
          _reconnectTimer?.cancel(); // Successful message, cancel retry timer
          _reconnectTimer = null;

          try {
            final data = json.decode(message) as Map<String, dynamic>;
            if (data.containsKey('symbol') && data.containsKey('ltp')) {
              _priceStreamController.add(data);
            } else if (data.containsKey('status')) {
              debugPrint("WebSocket status: ${data['message']}");
            }
          } catch (e) {
            debugPrint("WebSocket: Error parsing message: $e");
          }
        },
        onDone: () {
          debugPrint("WebSocket: Disconnected.");
          if (mounted) setState(() => _isWsConnected = false);
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(
            const Duration(seconds: 5),
            _connectWebSocket,
          );
        },
        onError: (error) {
          debugPrint("WebSocket: Error: $error");
          if (mounted) setState(() => _isWsConnected = false);
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(
            const Duration(seconds: 5),
            _connectWebSocket,
          );
        },
      );

      // After connecting, re-subscribe to all our known symbols
      _resubscribeWebSocketSymbols();
    } catch (e) {
      debugPrint("WebSocket: Connection failed: $e");
      if (mounted) setState(() => _isWsConnected = false);
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 5), _connectWebSocket);
    }
  }

  void _sendWsMessage(Map<String, dynamic> message) {
    if (_isWsConnected && _channel != null) {
      try {
        _channel!.sink.add(json.encode(message));
      } catch (e) {
        debugPrint("WebSocket: Error sending message: $e");
        // Trigger reconnect
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 1), _connectWebSocket);
      }
    } else {
      debugPrint(
        "WebSocket: Not connected. Message will be sent on reconnect.",
      );
      // Ensure we try to reconnect
      if (_reconnectTimer == null && !_isWsConnected) {
        _reconnectTimer = Timer(const Duration(seconds: 1), _connectWebSocket);
      }
    }
  }

  void wsSubscribe(List<String> symbols) {
    _wsSubscriptions.addAll(symbols);
    _sendWsMessage({"action": "subscribe", "symbols": symbols});
  }

  void wsUnsubscribe(List<String> symbols) {
    for (var symbol in symbols) {
      _wsSubscriptions.remove(symbol);
    }
    _sendWsMessage({"action": "unsubscribe", "symbols": symbols});
  }

  void _resubscribeWebSocketSymbols() {
    if (_wsSubscriptions.isNotEmpty) {
      debugPrint(
        "WebSocket: Resubscribing to ${_wsSubscriptions.length} symbols...",
      );
      wsSubscribe(List.from(_wsSubscriptions));
    }
  }

  Future<void> _subscribeToAllInstruments() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final advisorId = user.id;
    final Set<String> symbolsToSubscribe = {};

    try {
      // Fetch active trade symbols
      final activeTradesResponse = await Supabase.instance.client
          .from('trade_cards')
          .select('stock_symbol')
          .eq('advisor_id', advisorId)
          .eq('status', 'open');

      for (var trade in activeTradesResponse) {
        if (trade['stock_symbol'] != null) {
          symbolsToSubscribe.add(trade['stock_symbol']);
        }
      }

      // Fetch watchlist symbols
      final watchlistResponse = await Supabase.instance.client
          .from('watchlists')
          .select('stock_symbol')
          .eq('advisor_id', advisorId);

      for (var item in watchlistResponse) {
        if (item['stock_symbol'] != null) {
          symbolsToSubscribe.add(item['stock_symbol']);
        }
      }

      if (symbolsToSubscribe.isNotEmpty) {
        debugPrint(
          'Attempting to bulk subscribe to: ${symbolsToSubscribe.toList()}',
        );
        await _apiService.bulkSubscribeInstruments(symbolsToSubscribe.toList());
        wsSubscribe(symbolsToSubscribe.toList());
      }
    } catch (e) {
      debugPrint("Error fetching symbols for bulk subscription: $e");
      // Optionally show a snackbar error
    }
  }

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
        priceStream: _priceStream,
        onSubscribe: wsSubscribe,
      ),
      AllActiveTradesScreen(
        priceStream: _priceStream,
        onSubscribe: wsSubscribe,
      ),
      const AllClosedTradesScreen(),
      // Assign the GlobalKey to the WatchlistScreen instance
      WatchlistScreen(
        key: _watchlistKey,
        onCreateTrade: (stock) {
          _navigateToCreateTrade(stock);
        },
        priceStream: _priceStream,
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
        title: Row(
          children: [
            Text(titles[_selectedIndex]),
            const SizedBox(width: 8),
            Icon(
              _isWsConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isWsConnected ? Colors.green : Colors.red,
              size: 20,
            ),
          ],
        ),
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
          _selectedIndex == 3
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
                child: const Icon(Icons.add),
              )
              : null,
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
