import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/theme_provider.dart';
import 'package:signaldesk_user/services/api_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/screens/user_home_screen.dart';
import 'package:signaldesk_user/screens/trades/user_active_trades_screen.dart';
import 'package:signaldesk_user/screens/trades/user_closed_trades_screen.dart';
import 'package:signaldesk_user/screens/advisors/advisors_screen.dart';
import 'package:signaldesk_user/screens/profile/profile_screen.dart';

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _selectedIndex = 0;
  String _userName = 'User';
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchUserName();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeToActiveTradeInstruments();
    });
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

      // 3. Bulk subscribe if there are any symbols
      if (symbolsToSubscribe.isNotEmpty) {
        debugPrint(
          'User App: Attempting to bulk subscribe to active trade symbols: ${symbolsToSubscribe.toList()}',
        );
        await _apiService.bulkSubscribeInstruments(symbolsToSubscribe.toList());
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      UserHomeScreen(
        onViewActive: () => _onItemTapped(1),
        onViewClosed: () => _onItemTapped(2),
      ),
      const UserActiveTradesScreen(),
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
