import 'package:signaldesk_user/core/config.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/screens/user_home_screen.dart';
import 'package:signaldesk_user/screens/trades/user_active_trades_screen.dart';
import 'package:signaldesk_user/screens/trades/user_closed_trades_screen.dart';
import 'package:signaldesk_user/screens/advisors/advisors_screen.dart';
import 'package:signaldesk_user/screens/profile/profile_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _selectedIndex = 0;
  String _userName = 'User';

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _priceStreamController =
      StreamController.broadcast();
  late final Stream<Map<String, dynamic>> _priceStream;
  Timer? _reconnectTimer;
  final Map<String, Map<String, dynamic>> _pendingPrices = {};
  Timer? _flushTimer;
  bool _isWsConnected = false;
  final Set<String> _wsSubscriptions = {};
  final String _wsUrl = wsPricesUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserName();

    _priceStream = _priceStreamController.stream;
    _connectWebSocket();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToActiveTradeInstruments();
    });
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _flushTimer?.cancel();
    _priceStreamController.close();
    super.dispose();
  }

  Future<void> _subscribeToActiveTradeInstruments() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return; // Not logged in

    final userId = user.id;
    final Set<String> symbolsToSubscribe = {};

    try {
      // 1. Get IDs of subscribed advisors
      final subscriptionsResponse = await Supabase.instance.client
          .from('subscriptions')
          .select('advisor_id')
          .eq('user_id', userId);

      if (subscriptionsResponse.isEmpty) {
        debugPrint("User has no subscriptions.");
        return;
      }

      final advisorIds =
          subscriptionsResponse
              .map((sub) => sub['advisor_id'] as String)
              .toList();

      // 2. Get active trade symbols for those advisors
      final activeTradesResponse = await Supabase.instance.client
          .from('trade_cards')
          .select('stock_symbol')
          .inFilter('advisor_id', advisorIds)
          .eq('status', 'open');

      for (var trade in activeTradesResponse) {
        if (trade['stock_symbol'] != null) {
          symbolsToSubscribe.add(trade['stock_symbol']);
        }
      }

      // Bulk subscribe if there are any symbols
      if (symbolsToSubscribe.isNotEmpty) {
        debugPrint(
          'User App: Attempting to bulk subscribe to active trade symbols: ${symbolsToSubscribe.toList()}',
        );
        wsSubscribe(symbolsToSubscribe.toList());
      } else {
        debugPrint(
          "User App: No active trade symbols found for subscribed advisors.",
        );
      }
    } catch (e) {
      debugPrint("User App: Error fetching symbols for bulk subscription: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not set up live data subscriptions: $e"),
          ),
        );
      }
    }
  }

  Future<void> _fetchUserName() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final response =
            await Supabase.instance.client
                .from('profiles')
                .select('first_name')
                .eq('id', user.id)
                .single();
        if (mounted && response['first_name'] != null) {
          setState(() {
            _userName = response['first_name'];
          });
        }
      } catch (e) {
        setState(() {
          _userName = user.userMetadata?['first_name'] ?? 'User';
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Every screen rebuilds per price update, so batch ticks: at most ~4 updates/s per stock
  // however fast the feed is. Without this a busy stock freezes the UI.
  void _flushPrices() {
    _flushTimer = null;
    if (_priceStreamController.isClosed) return;
    _pendingPrices.values.forEach(_priceStreamController.add);
    _pendingPrices.clear();
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
          _reconnectTimer?.cancel();
          _reconnectTimer = null;

          try {
            final data = json.decode(message) as Map<String, dynamic>;
            if (data.containsKey('symbol') && data.containsKey('ltp')) {
              _pendingPrices[data['symbol'] as String] = data; // keep the latest tick per stock
              _flushTimer ??= Timer(const Duration(milliseconds: 250), _flushPrices);
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
            _connectWebSocket, // Attempt to reconnect
          );
        },
        onError: (error) {
          debugPrint("WebSocket: Error: $error");
          if (mounted) setState(() => _isWsConnected = false);
          _reconnectTimer?.cancel();
          _reconnectTimer = Timer(
            const Duration(seconds: 5),
            _connectWebSocket, // Attempt to reconnect
          );
        },
      );

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
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 1), _connectWebSocket);
      }
    } else {
      debugPrint(
        "WebSocket: Not connected. Message will be sent on reconnect.",
      );
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
      _sendWsMessage({
        "action": "subscribe",
        "symbols": _wsSubscriptions.toList(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      UserHomeScreen(
        onViewActive: () => _onItemTapped(1),
        onViewClosed: () => _onItemTapped(2),
        priceStream: _priceStream,
        onSubscribe: wsSubscribe,
      ),
      UserActiveTradesScreen(
        priceStream: _priceStream,
        onSubscribe: wsSubscribe,
      ),
      const UserClosedTradesScreen(),
      const AdvisorsScreen(),
    ];
    const List<String> titles = <String>[
      'Home',
      'Active Trades',
      'Closed Trades',
      'Advisors',
    ];
    final appBarTitle =
        _selectedIndex == 0 ? 'Hi, $_userName' : titles[_selectedIndex];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0.0,
        leading: IconButton(
          icon: const Icon(
            Icons.account_circle_outlined,
            color: Color(0xFFCAC4D0),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
        title: Text(appBarTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () {
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Active',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Closed'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Advisors'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
