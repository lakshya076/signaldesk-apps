import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/features/user_home_screen.dart';
import 'package:signaldesk_user/features/trades/user_active_trades_screen.dart';
import 'package:signaldesk_user/features/trades/user_closed_trades_screen.dart';
import 'package:signaldesk_user/features/advisors/advisors_screen.dart';
import 'package:signaldesk_user/features/profile/profile_screen.dart';

class UserMainScreen extends StatefulWidget {
  const UserMainScreen({super.key});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  int _selectedIndex = 0;
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _fetchUserName();
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
