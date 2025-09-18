import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- USER APP FRAMEWORK ---
// This file contains the complete, separate codebase for the user-facing application.

// --- Data Models ---
class Stock {
  final String symbol;
  final String name;
  final double entryPrice;
  final double lastPrice;

  Stock({
    required this.symbol,
    required this.name,
    required this.entryPrice,
    required this.lastPrice,
  });

  factory Stock.fromJson(String symbol, Map<String, dynamic> json) {
    return Stock(
      symbol: symbol,
      name: json['name'] ?? '',
      entryPrice: (json['entry_price'] as num?)?.toDouble() ?? 0.0,
      lastPrice: (json['last_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TradeCardModel {
  final String id;
  final String stockSymbol;
  final String stockName;
  final double entryPrice;
  final double stopLoss;
  final double target;
  final String status;
  final String tradeDirection;
  final double lastPrice;
  final String tradeCategory;
  final String tradeSegment;
  final String advisorName;

  TradeCardModel({
    required this.id,
    required this.stockSymbol,
    required this.stockName,
    required this.entryPrice,
    required this.stopLoss,
    required this.target,
    required this.status,
    required this.tradeDirection,
    required this.lastPrice,
    required this.tradeCategory,
    required this.tradeSegment,
    required this.advisorName,
  });

  factory TradeCardModel.fromJson(Map<String, dynamic> json) {
    String name = 'Unknown Advisor';
    if (json['profiles'] != null) {
      final firstName = json['profiles']['first_name'] ?? '';
      final lastName = json['profiles']['last_name'] ?? '';
      name = '$firstName $lastName'.trim();
    }

    return TradeCardModel(
      id: json['id'] ?? '',
      stockSymbol: json['stock_symbol'] ?? '',
      stockName: json['stock_name'] ?? '',
      entryPrice: (json['entry_price'] as num?)?.toDouble() ?? 0.0,
      stopLoss: (json['stop_loss'] as num?)?.toDouble() ?? 0.0,
      target: (json['target'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'unknown',
      tradeDirection: json['trade_direction'] ?? '',
      lastPrice: (json['last_price'] as num?)?.toDouble() ?? 0.0,
      tradeCategory: json['trade_category'] ?? 'N/A',
      tradeSegment: json['trade_segment'] ?? 'N/A',
      advisorName: name,
    );
  }
}

// --- ViewModels ---
class ActiveTradeCardViewModel {
  final TradeCardModel trade;
  final double currentPrice;

  ActiveTradeCardViewModel({required this.trade, required this.currentPrice});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

  String get advisorName => trade.advisorName;

  String get entryPrice => '₹${trade.entryPrice.toStringAsFixed(2)}';

  String get stopLoss => '₹${trade.stopLoss.toStringAsFixed(2)}';

  String get targetPrice => '₹${trade.target.toStringAsFixed(2)}';

  String get currentPriceFormatted => '₹${currentPrice.toStringAsFixed(2)}';

  double get priceChangeValue => currentPrice - trade.lastPrice;

  String get priceChange =>
      '${priceChangeValue >= 0 ? '+' : ''}₹${priceChangeValue.toStringAsFixed(2)} (${(priceChangeValue / trade.lastPrice * 100).toStringAsFixed(2)}%)';

  bool get isProfit => currentPrice >= trade.entryPrice;

  double get progress {
    if (trade.status != 'open') return isProfit ? 1.0 : 0.0;
    final range = trade.target - trade.stopLoss;
    if (range <= 0) return 0.5;
    final value = (currentPrice - trade.stopLoss) / range;
    return value.clamp(0.0, 1.0);
  }

  String get liveStatus {
    if (status != 'open') return status.replaceAll('_', ' ').toUpperCase();
    if (isProfit) return 'In Profit';
    return 'In Loss';
  }

  String get estimatedGain {
    final gain = ((trade.target - trade.entryPrice) / trade.entryPrice) * 100;
    return '${gain.toStringAsFixed(2)}%';
  }

  double get liveReturnValue =>
      ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100;

  String get liveReturn {
    final gain = liveReturnValue;
    return '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%';
  }

  String get status => trade.status;
}

class ClosedTradeCardViewModel {
  final TradeCardModel trade;

  ClosedTradeCardViewModel({required this.trade});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

  String get advisorName => trade.advisorName;

  double get exitPrice {
    if (trade.status == 'closed_profit') return trade.target;
    if (trade.status == 'closed_loss') return trade.stopLoss;
    return trade.entryPrice;
  }

  String get entryPriceFormatted => '₹${trade.entryPrice.toStringAsFixed(2)}';

  String get exitPriceFormatted => '₹${exitPrice.toStringAsFixed(2)}';

  bool get wasProfitable => trade.status == 'closed_profit';

  bool get wasLoss => trade.status == 'closed_loss';

  String get tradeStatus {
    if (wasProfitable) return 'Trade Status: Profit';
    if (wasLoss) return 'Trade Status: Loss';
    return 'Trade Status: At Cost';
  }

  double get gainLossValue {
    final gain = exitPrice - trade.entryPrice;
    return trade.tradeDirection == 'Sell' ? -gain : gain;
  }

  String get gainLossPercent {
    if (trade.entryPrice == 0) return '0.00%';
    final percent = (gainLossValue / trade.entryPrice) * 100;
    return '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%';
  }

  String get riskReward {
    final potentialGain = (trade.target - trade.entryPrice).abs();
    final potentialLoss = (trade.entryPrice - trade.stopLoss).abs();
    if (potentialLoss == 0) return 'N/A';
    final rr = potentialGain / potentialLoss;
    return '${rr.toStringAsFixed(2)}x';
  }
}

// --- API Service ---
class ApiService {
  final String _apiBaseUrl = 'https://8daec68513f2.ngrok-free.app';

  Future<Map<String, double>> getLivePrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/get-live-prices'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'symbols': symbols}),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return (decoded['data'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
    } else {
      throw Exception('Failed to load live prices');
    }
  }
}

// --- Global State Notifiers ---
final selectedAdvisorsNotifier = ValueNotifier<Set<String>>({});
final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

class AppThemes {
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    colorScheme: ThemeData.dark().colorScheme.copyWith(
      primary: const Color(0xFF3B82F6),
      secondary: Colors.green.shade400,
      // Profit
      error: Colors.red.shade400,
      // Loss
      tertiary: Colors.amber.shade400,
      // NEW: At Cost color
      surface: const Color(0xFF2B3544),
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF1F2937),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F2937),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF3B82F6),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardTheme(
      elevation: 1,
      color: const Color(0xFF2B3544),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2B3544),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Color(0xFF6B7280)),
      labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF60A5FA)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF111827),
      selectedItemColor: Color(0xFF3B82F6),
      unselectedItemColor: Color(0xFF6B7280),
    ),
    dividerColor: Colors.grey.withOpacity(0.2),
  );

  static final ThemeData lightTheme = ThemeData.light().copyWith(
    colorScheme: ThemeData.light().colorScheme.copyWith(
      primary: const Color(0xFF3B82F6),
      secondary: Colors.green.shade700,
      // Profit
      error: Colors.red.shade700,
      // Loss
      tertiary: Colors.amber.shade700,
      // NEW: At Cost color
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    scaffoldBackgroundColor: const Color(0xFFF9FAFB),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Color(0xFF3B82F6),
      foregroundColor: Colors.white,
    ),
    cardTheme: CardTheme(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: Color(0xFF6B7280)),
      labelStyle: const TextStyle(color: Color(0xFF4B5563)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF3B82F6)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF3B82F6),
      unselectedItemColor: Color(0xFF6B7280),
    ),
    dividerColor: Colors.grey.withOpacity(0.2),
  );
}

// --- App Initialization ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: "https://wvnfmsgnqydelrrpwfic.supabase.co",
    anonKey: "sb_publishable_v2xTPguM2YQqSMOI1QHA3Q_MlQdj7Zu",
  );
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? true;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  runApp(const UserApp());
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'SignalDesk User',
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: currentMode,
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// --- Authentication Flow ---
class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Map<String, dynamic>?> _getProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final response =
        await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.session != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getProfileData(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final profile = profileSnapshot.data;
              if (profile == null) {
                return const LoginScreen(); // Fallback to login if profile doesn't exist
              }

              if (profile['role'] == 'user') {
                return const UserMainScreen();
              } else {
                return const AccessDeniedScreen();
              }
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

// --- Main User Screen ---
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
            onPressed: () async {
              final newMode =
                  themeNotifier.value == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light;
              themeNotifier.value = newMode;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isDarkMode', newMode == ThemeMode.dark);
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

// --- All User Screens ---

class UserHomeScreen extends StatefulWidget {
  final VoidCallback onViewActive;
  final VoidCallback onViewClosed;

  const UserHomeScreen({
    super.key,
    required this.onViewActive,
    required this.onViewClosed,
  });

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  List<TradeCardModel> _activeTrades = [];
  List<TradeCardModel> _closedTrades = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  Timer? _timer;
  final _apiService = ApiService();
  RealtimeChannel? _tradesChannel;

  @override
  void initState() {
    super.initState();
    _fetchTradeCards();
    selectedAdvisorsNotifier.addListener(_fetchTradeCards);
    _initializeRealtimeSubscription();
  }

  void _initializeRealtimeSubscription() {
    try {
      final channelName =
          'trade_cards_home_${DateTime.now().millisecondsSinceEpoch}';
      _tradesChannel = Supabase.instance.client.channel(channelName);
      _tradesChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trade_cards',
            callback: (payload) {
              if (mounted) _fetchTradeCards();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    selectedAdvisorsNotifier.removeListener(_fetchTradeCards);
    if (_tradesChannel != null) {
      Supabase.instance.client.removeChannel(_tradesChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchTradeCards() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final selectedIds = selectedAdvisorsNotifier.value;
      List<dynamic> response;
      if (selectedIds.isEmpty) {
        // No filter needed
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .order('created_at', ascending: false);
      } else {
        // Apply multiple OR conditions
        final orConditions = selectedIds
            .map((id) => 'advisor_id.eq.$id')
            .join(',');
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .or(orConditions)
            .order('created_at', ascending: false);
      }
      if (!mounted) return;
      final allCards = response.map((e) => TradeCardModel.fromJson(e)).toList();
      setState(() {
        _activeTrades = allCards.where((c) => c.status == 'open').toList();
        _closedTrades = allCards.where((c) => c.status != 'open').toList();
        _isLoading = false;
      });
      if (_activeTrades.isNotEmpty) {
        _startPriceTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching trades: $e")));
      }
    }
  }

  void _startPriceTimer() {
    _timer?.cancel();
    if (_activeTrades.isNotEmpty && mounted) {
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted && _activeTrades.isNotEmpty) {
          _updateLivePrices();
        } else {
          timer.cancel();
        }
      });
      _updateLivePrices();
    }
  }

  Future<void> _updateLivePrices() async {
    if (_activeTrades.isEmpty || !mounted) return;
    try {
      final symbols =
          _activeTrades.map((card) => card.stockSymbol).toSet().toList();
      if (symbols.isEmpty) return;
      final prices = await _apiService.getLivePrices(symbols);
      if (mounted) setState(() => _livePrices = prices);
    } catch (e) {
      debugPrint("Error fetching live prices for trades: $e");
    }
  }

  Future<void> _refresh() async {
    _timer?.cancel();
    await _fetchTradeCards();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildSectionHeader('Active Trades', widget.onViewActive),
                  _buildTradeList(_activeTrades, true),
                  const SizedBox(height: 24),
                  _buildSectionHeader('Closed Trades', widget.onViewClosed),
                  _buildTradeList(_closedTrades, false),
                ],
              ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewMore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        TextButton(onPressed: onViewMore, child: const Text('View More')),
      ],
    );
  }

  Widget _buildTradeList(List<TradeCardModel> trades, bool isActive) {
    if (trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Text('No ${isActive ? 'active' : 'closed'} trades found.'),
        ),
      );
    }
    final displayTrades = trades.take(3).toList();
    return Column(
      children:
          displayTrades.map((trade) {
            if (isActive) {
              final livePrice =
                  _livePrices[trade.stockSymbol] ?? trade.lastPrice;
              final viewModel = ActiveTradeCardViewModel(
                trade: trade,
                currentPrice: livePrice,
              );
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ActiveTradeCardWidget(trade: viewModel),
              );
            } else {
              final viewModel = ClosedTradeCardViewModel(trade: trade);
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: ClosedTradeCardWidget(trade: viewModel),
              );
            }
          }).toList(),
    );
  }
}

class UserActiveTradesScreen extends StatefulWidget {
  const UserActiveTradesScreen({super.key});

  @override
  State<UserActiveTradesScreen> createState() => _UserActiveTradesScreenState();
}

class _UserActiveTradesScreenState extends State<UserActiveTradesScreen> {
  List<TradeCardModel> _tradeCards = [];
  List<ActiveTradeCardViewModel> _filteredTradeCards = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  Timer? _timer;
  final _apiService = ApiService();
  String _selectedFilter = 'All';
  RealtimeChannel? _tradesChannel;

  @override
  void initState() {
    super.initState();
    _fetchInitialTradeCards();
    selectedAdvisorsNotifier.addListener(_fetchInitialTradeCards);
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _tradesChannel = Supabase.instance.client.channel(
      'active_trades_${DateTime.now().millisecondsSinceEpoch}',
    );
    _tradesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'status',
            value: 'open',
          ),
          callback: (payload) {
            if (mounted) _fetchInitialTradeCards();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    selectedAdvisorsNotifier.removeListener(_fetchInitialTradeCards);
    if (_tradesChannel != null) {
      Supabase.instance.client.removeChannel(_tradesChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchInitialTradeCards() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final selectedIds = selectedAdvisorsNotifier.value;
      List<dynamic> response;

      if (selectedIds.isEmpty) {
        // No filter needed - get all open trades
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .eq('status', 'open')
            .order('created_at', ascending: false);
      } else {
        // Apply multiple OR conditions for advisor filtering
        final orConditions = selectedIds
            .map((id) => 'advisor_id.eq.$id')
            .join(',');
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .eq('status', 'open')
            .or(orConditions)
            .order('created_at', ascending: false);
      }

      if (!mounted) return;
      final cards = response.map((e) => TradeCardModel.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _tradeCards = cards;
          _isLoading = false;
        });
        _filterAndRefresh();
        _startPriceTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching trades: $e")));
      }
    }
  }

  void _startPriceTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _updateLivePrices(),
    );
    _updateLivePrices();
  }

  Future<void> _updateLivePrices() async {
    if (_tradeCards.isEmpty || !mounted) return;
    try {
      final symbols =
          _tradeCards.map((card) => card.stockSymbol).toSet().toList();
      if (symbols.isEmpty) return;
      final prices = await _apiService.getLivePrices(symbols);
      if (mounted) {
        setState(() {
          _livePrices = prices;
        });
        _filterAndRefresh();
      }
    } catch (e) {
      debugPrint("Error fetching live prices for trades: $e");
    }
  }

  void _onFilterChanged(String newFilter) {
    setState(() {
      _selectedFilter = newFilter;
      _filterAndRefresh();
    });
  }

  void _filterAndRefresh() {
    final allViewModels =
        _tradeCards.map((trade) {
          final livePrice = _livePrices[trade.stockSymbol] ?? trade.lastPrice;
          return ActiveTradeCardViewModel(
            trade: trade,
            currentPrice: livePrice,
          );
        }).toList();
    if (_selectedFilter == 'All') {
      _filteredTradeCards = allViewModels;
    } else {
      _filteredTradeCards =
          allViewModels.where((vm) {
            if (_selectedFilter == 'In Profit') return vm.liveReturnValue > 0;
            if (_selectedFilter == 'In Loss') return vm.liveReturnValue < 0;
            if (_selectedFilter == 'At Cost')
              return vm.liveReturnValue.abs() < 0.1;
            return false;
          }).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: FilterChipRowWidget(
            selectedFilter: _selectedFilter,
            onFilterChanged: _onFilterChanged,
          ),
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTradeCards.isEmpty
                  ? Center(
                    child: Text(
                      _tradeCards.isEmpty
                          ? 'No active trades from your advisors.'
                          : 'No trades match the filter.',
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _filteredTradeCards.length,
                    itemBuilder: (context, index) {
                      final viewModel = _filteredTradeCards[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ActiveTradeCardWidget(trade: viewModel),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class UserClosedTradesScreen extends StatefulWidget {
  const UserClosedTradesScreen({super.key});

  @override
  State<UserClosedTradesScreen> createState() => _UserClosedTradesScreenState();
}

class _UserClosedTradesScreenState extends State<UserClosedTradesScreen> {
  List<TradeCardModel> _tradeCards = [];
  List<ClosedTradeCardViewModel> _filteredTradeCards = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  RealtimeChannel? _tradesChannel;

  @override
  void initState() {
    super.initState();
    _fetchInitialClosedTrades();
    selectedAdvisorsNotifier.addListener(_fetchInitialClosedTrades);
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _tradesChannel = Supabase.instance.client.channel(
      'closed_trades_${DateTime.now().millisecondsSinceEpoch}',
    );
    _tradesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          callback: (payload) {
            final newData = payload.newRecord;
            final oldData = payload.oldRecord;
            bool shouldRefresh = false;
            if (payload.eventType == PostgresChangeEvent.insert ||
                payload.eventType == PostgresChangeEvent.update) {
              if (newData['status'] != 'open') {
                shouldRefresh = true;
              }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              if (oldData['status'] != 'open') {
                shouldRefresh = true;
              }
            }
            if (shouldRefresh && mounted) {
              _fetchInitialClosedTrades();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    selectedAdvisorsNotifier.removeListener(_fetchInitialClosedTrades);
    if (_tradesChannel != null) {
      Supabase.instance.client.removeChannel(_tradesChannel!);
    }
    super.dispose();
  }

  Future<void> _fetchInitialClosedTrades() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final selectedIds = selectedAdvisorsNotifier.value;
      List<dynamic> response;

      if (selectedIds.isEmpty) {
        // No filter needed - get all closed trades
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .neq('status', 'open')
            .order('created_at', ascending: false);
      } else {
        // Apply multiple OR conditions for advisor filtering
        final orConditions = selectedIds
            .map((id) => 'advisor_id.eq.$id')
            .join(',');
        response = await Supabase.instance.client
            .from('trade_cards')
            .select('*, profiles(first_name, last_name)')
            .neq('status', 'open')
            .or(orConditions)
            .order('created_at', ascending: false);
      }

      if (!mounted) return;
      final cards = response.map((e) => TradeCardModel.fromJson(e)).toList();

      if (mounted) {
        setState(() {
          _tradeCards = cards;
          _isLoading = false;
        });
        _filterAndRefresh();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching trades: $e")));
      }
    }
  }

  void _onFilterChanged(String newFilter) {
    setState(() {
      _selectedFilter = newFilter;
      _filterAndRefresh();
    });
  }

  void _filterAndRefresh() {
    final allViewModels =
        _tradeCards
            .map((trade) => ClosedTradeCardViewModel(trade: trade))
            .toList();
    if (_selectedFilter == 'All') {
      _filteredTradeCards = allViewModels;
    } else {
      _filteredTradeCards =
          allViewModels.where((vm) {
            if (_selectedFilter == 'In Profit') {
              return vm.trade.status == 'closed_profit';
            }
            if (_selectedFilter == 'In Loss') {
              return vm.trade.status == 'closed_loss';
            }
            if (_selectedFilter == 'At Cost') {
              return vm.trade.status == 'closed_cost';
            }
            return false;
          }).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: FilterChipRowWidget(
            selectedFilter: _selectedFilter,
            onFilterChanged: _onFilterChanged,
          ),
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTradeCards.isEmpty
                  ? Center(
                    child: Text(
                      _tradeCards.isEmpty
                          ? 'No closed trades from your advisors.'
                          : 'No trades match the filter.',
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _filteredTradeCards.length,
                    itemBuilder: (context, index) {
                      final viewModel = _filteredTradeCards[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: ClosedTradeCardWidget(trade: viewModel),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class AdvisorsScreen extends StatefulWidget {
  const AdvisorsScreen({super.key});

  @override
  State<AdvisorsScreen> createState() => _AdvisorsScreenState();
}

class _AdvisorsScreenState extends State<AdvisorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _showFab = false;
  List<dynamic> _subscribedAdvisors = [];
  List<dynamic> _discoverAdvisors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _showFab = _tabController.index == 1);
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final responses = await Future.wait([
        Supabase.instance.client
            .from('profiles')
            .select('id, first_name, last_name')
            .eq('role', 'advisor'),
        Supabase.instance.client
            .from('subscriptions')
            .select('advisor_id')
            .eq('user_id', userId),
      ]);
      final allAdvisors = responses[0] as List;
      final subscriptions = responses[1] as List;
      final subscribedIds =
          subscriptions.map((sub) => sub['advisor_id'] as String).toSet();
      if (mounted) {
        setState(() {
          _subscribedAdvisors =
              allAdvisors
                  .where((advisor) => subscribedIds.contains(advisor['id']))
                  .toList();
          _discoverAdvisors =
              allAdvisors
                  .where((advisor) => !subscribedIds.contains(advisor['id']))
                  .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching advisors: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSubscriptionChange(
    String advisorId,
    bool isSubscribing,
  ) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      if (isSubscribing) {
        await Supabase.instance.client.from('subscriptions').insert({
          'user_id': userId,
          'advisor_id': advisorId,
        });
      } else {
        await Supabase.instance.client.from('subscriptions').delete().match({
          'user_id': userId,
          'advisor_id': advisorId,
        });
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating subscription: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Subscribed'), Tab(text: 'Discover')],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  _AdvisorList(
                    advisors: _subscribedAdvisors,
                    isSubscribedList: true,
                    onSubscriptionChange:
                        (advisorId) =>
                            _handleSubscriptionChange(advisorId, false),
                  ),
                  _AdvisorList(
                    advisors: _discoverAdvisors,
                    isSubscribedList: false,
                    onSubscriptionChange:
                        (advisorId) =>
                            _handleSubscriptionChange(advisorId, true),
                  ),
                ],
              ),
      floatingActionButton:
          _showFab
              ? FloatingActionButton(
                onPressed: () async {
                  await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder:
                        (context) => SearchAdvisorsScreen(
                          discoverAdvisors: _discoverAdvisors,
                          onSubscribe:
                              (advisorId) =>
                                  _handleSubscriptionChange(advisorId, true),
                        ),
                  );
                },
                child: const Icon(Icons.search),
              )
              : null,
    );
  }
}

class _AdvisorList extends StatelessWidget {
  final List<dynamic> advisors;
  final bool isSubscribedList;
  final Function(String) onSubscriptionChange;

  const _AdvisorList({
    required this.advisors,
    required this.isSubscribedList,
    required this.onSubscriptionChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (advisors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isSubscribedList
                ? 'You are not subscribed to any advisors yet.\nGo to the Discover tab to find new advisors.'
                : 'No new advisors to discover.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: advisors.length,
      itemBuilder: (context, index) {
        final advisor = advisors[index];
        final advisorId = advisor['id'] as String;
        final fullName =
            '${advisor['first_name'] ?? ''} ${advisor['last_name'] ?? ''}'
                .trim();
        final initial =
            (advisor['first_name'] ?? '?').isNotEmpty
                ? advisor['first_name'][0].toUpperCase()
                : '?';

        return SizedBox(
          height: 72.0,
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    foregroundColor: theme.colorScheme.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      fullName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => onSubscriptionChange(advisorId),
                    style:
                        isSubscribedList
                            ? ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                              foregroundColor: Colors.white,
                            )
                            : null,
                    child: Text(isSubscribedList ? 'Unsubscribe' : 'Subscribe'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SearchAdvisorsScreen extends StatefulWidget {
  final List<dynamic> discoverAdvisors;
  final Function(String) onSubscribe;

  const SearchAdvisorsScreen({
    super.key,
    required this.discoverAdvisors,
    required this.onSubscribe,
  });

  @override
  State<SearchAdvisorsScreen> createState() => _SearchAdvisorsScreenState();
}

class _SearchAdvisorsScreenState extends State<SearchAdvisorsScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchResults = widget.discoverAdvisors;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toUpperCase();
    setState(() {
      _searchResults =
          query.isEmpty
              ? widget.discoverAdvisors
              : widget.discoverAdvisors.where((advisor) {
                final fullName =
                    '${advisor['first_name'] ?? ''} ${advisor['last_name'] ?? ''}'
                        .toUpperCase();
                return fullName.contains(query);
              }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    hintText: 'Search for advisors...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child:
                    _searchResults.isEmpty
                        ? const Center(child: Text("No advisors found"))
                        : ListView.builder(
                          controller: controller,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final advisor = _searchResults[index];
                            final fullName =
                                '${advisor['first_name'] ?? ''} ${advisor['last_name'] ?? ''}'
                                    .trim();
                            final initial =
                                (advisor['first_name'] ?? '?').isNotEmpty
                                    ? advisor['first_name'][0].toUpperCase()
                                    : '?';

                            return SizedBox(
                              height: 72.0,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: theme.colorScheme.primary
                                          .withOpacity(0.1),
                                      foregroundColor:
                                          theme.colorScheme.primary,
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        widget.onSubscribe(advisor['id']);
                                        Navigator.pop(context, true);
                                      },
                                      child: const Text('Subscribe'),
                                    ),
                                  ],
                                ),
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _fullName = 'User';
  String _email = '';
  String _initial = '?';
  List<dynamic> _subscribedAdvisors = [];

  @override
  void initState() {
    super.initState();
    // Fetch both profile data and subscribed advisors at the same time
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Fetch profile data (name, email)
      final profileResponse =
          await Supabase.instance.client
              .from('profiles')
              .select('first_name, last_name, email')
              .eq('id', user.id)
              .single();

      final firstName = profileResponse['first_name'] ?? '';
      final lastName = profileResponse['last_name'] ?? '';

      // Fetch subscribed advisor IDs
      final subscriptionsResponse = await Supabase.instance.client
          .from('subscriptions')
          .select('advisor_id')
          .eq('user_id', user.id);

      final advisorIds =
          (subscriptionsResponse as List)
              .map((sub) => sub['advisor_id'] as String)
              .toList();

      List<dynamic> advisors = [];
      if (advisorIds.isNotEmpty) {
        // Fetch full profiles for the subscribed advisors using OR conditions
        final orConditions = advisorIds.map((id) => 'id.eq.$id').join(',');
        final advisorsResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, first_name, last_name')
            .or(orConditions);
        advisors = advisorsResponse as List;
      }

      if (mounted) {
        setState(() {
          _fullName = '$firstName $lastName'.trim();
          _email = profileResponse['email'] ?? user.email ?? '';
          _initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
          _subscribedAdvisors = advisors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Filters'),
        actions: [
          // Clear filter button appears when a filter is active
          ValueListenableBuilder<Set<String>>(
            valueListenable: selectedAdvisorsNotifier,
            builder: (context, selectedIds, child) {
              if (selectedIds.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.filter_alt_off_outlined),
                onPressed: () => selectedAdvisorsNotifier.value = {},
                tooltip: 'Clear Filters',
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetchData,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // User Info Section
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: theme.colorScheme.primary
                              .withOpacity(0.1),
                          foregroundColor: theme.colorScheme.primary,
                          child: Text(
                            _initial,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _fullName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // NEW: Filter by Advisor section is now directly on this screen
                    _buildAdvisorFilterSection(context),

                    const SizedBox(height: 24),

                    // Settings Card
                    Card(
                      child: Column(
                        children: [
                          ValueListenableBuilder<ThemeMode>(
                            valueListenable: themeNotifier,
                            builder: (context, currentMode, child) {
                              return SwitchListTile(
                                title: const Text('Dark Mode'),
                                value: currentMode == ThemeMode.dark,
                                onChanged: (isDark) async {
                                  final newMode =
                                      isDark ? ThemeMode.dark : ThemeMode.light;
                                  themeNotifier.value = newMode;
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setBool('isDarkMode', isDark);
                                },
                                secondary: const Icon(
                                  Icons.brightness_6_outlined,
                                ),
                              );
                            },
                          ),
                          // ... (Other settings can go here)
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Logout Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error.withOpacity(
                          0.1,
                        ),
                        foregroundColor: theme.colorScheme.error,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  // Helper widget to build the filter section UI
  Widget _buildAdvisorFilterSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter Trades by Advisor',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap one or more advisors to see only their trades.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 16),
        _subscribedAdvisors.isEmpty
            ? Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'You are not subscribed to any advisors. Go to the Advisors tab to subscribe.',
                      ),
                    ),
                  ],
                ),
              ),
            )
            : ValueListenableBuilder<Set<String>>(
              valueListenable: selectedAdvisorsNotifier,
              builder: (context, selectedIds, child) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 3 / 2.5,
                  ),
                  itemCount: _subscribedAdvisors.length,
                  itemBuilder: (context, index) {
                    final advisor = _subscribedAdvisors[index];
                    final advisorId = advisor['id'] as String;
                    final fullName =
                        '${advisor['first_name'] ?? ''} ${advisor['last_name'] ?? ''}'
                            .trim();
                    final initial =
                        (advisor['first_name'] ?? '?').isNotEmpty
                            ? advisor['first_name'][0].toUpperCase()
                            : '?';
                    final isSelected = selectedIds.contains(advisorId);

                    return GestureDetector(
                      onTap: () {
                        final newSet = Set<String>.from(selectedIds);
                        if (isSelected) {
                          newSet.remove(advisorId);
                        } else {
                          newSet.add(advisorId);
                        }
                        selectedAdvisorsNotifier.value = newSet;
                      },
                      child: Card(
                        elevation: isSelected ? 4 : 1,
                        color:
                            isSelected
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.3)
                                : Theme.of(context).cardTheme.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(radius: 24, child: Text(initial)),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Text(
                                fullName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      ],
    );
  }
}

class ActiveTradeCardWidget extends StatelessWidget {
  final ActiveTradeCardViewModel trade;

  const ActiveTradeCardWidget({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color outlineColor;
    if (trade.liveReturnValue.abs() < 0.1) {
      outlineColor = theme.colorScheme.tertiary;
    } else if (trade.isProfit) {
      outlineColor = theme.colorScheme.secondary;
    } else {
      outlineColor = theme.colorScheme.error;
    }
    final currentStatusColor =
        trade.isProfit ? theme.colorScheme.secondary : theme.colorScheme.error;
    return InkWell(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => OpenTradeAnalysis(activeTrade: trade),
            ),
          ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outlineColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  radius: 24,
                  child: Text(
                    trade.stockSymbol.substring(0, 1),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.stockSymbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        trade.companyName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      trade.currentPriceFormatted,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      trade.priceChange,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: currentStatusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            LiveTradeIndicator(
              stopLoss: trade.trade.stopLoss,
              target: trade.trade.target,
              entryPrice: trade.trade.entryPrice,
              currentPrice: trade.currentPrice,
              tradeDirection: trade.trade.tradeDirection, // Add this line
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: currentStatusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Live Status: ${trade.liveStatus}',
                  style: TextStyle(
                    color: currentStatusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat(
                  'Estimated Gain',
                  trade.estimatedGain,
                  theme.colorScheme.secondary,
                  context,
                ),
                _buildStat(
                  'Live Return',
                  trade.liveReturn,
                  currentStatusColor,
                  context,
                  alignment: CrossAxisAlignment.end,
                ),
              ],
            ),
            Divider(color: theme.dividerColor, height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLevel('Entry', trade.entryPrice, context),
                Container(width: 1, height: 30, color: theme.dividerColor),
                _buildLevel('Stop Loss', trade.stopLoss, context),
                Container(width: 1, height: 30, color: theme.dividerColor),
                _buildLevel('Target', trade.targetPrice, context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
    String label,
    String value,
    Color color,
    BuildContext context, {
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLevel(String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class ClosedTradeCardWidget extends StatelessWidget {
  final ClosedTradeCardViewModel trade;

  const ClosedTradeCardWidget({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color outlineColor;
    if (trade.wasProfitable) {
      outlineColor = theme.colorScheme.secondary;
    } else if (trade.wasLoss) {
      outlineColor = theme.colorScheme.error;
    } else {
      outlineColor = theme.colorScheme.tertiary;
    }
    final gainLossColor =
        trade.gainLossValue >= 0
            ? theme.colorScheme.secondary
            : theme.colorScheme.error;
    final statusColor = outlineColor;

    return InkWell(
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ClosedTradesAnalysis(trade: trade),
            ),
          ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outlineColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  radius: 24,
                  child: Text(
                    trade.stockSymbol.substring(0, 1),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trade.stockSymbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        trade.companyName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Analyst Signal",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildTag("Swing", theme.colorScheme.primary, context),
                        const SizedBox(width: 4),
                        _buildTag("Equity", Colors.amber.shade700, context),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  trade.tradeStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat(
                  'Gain/Loss',
                  trade.gainLossPercent,
                  gainLossColor,
                  context,
                ),
                _buildStat(
                  'Risk/Reward',
                  trade.riskReward,
                  theme.colorScheme.secondary,
                  context,
                  alignment: CrossAxisAlignment.end,
                ),
              ],
            ),
            Divider(color: theme.dividerColor, height: 32),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLevel('Entry', trade.entryPriceFormatted, context),
                  Container(width: 1, height: 30, color: theme.dividerColor),
                  _buildLevel('Exit', trade.exitPriceFormatted, context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStat(
    String label,
    String value,
    Color color,
    BuildContext context, {
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLevel(String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class OpenTradeAnalysis extends StatefulWidget {
  final ActiveTradeCardViewModel activeTrade;

  const OpenTradeAnalysis({super.key, required this.activeTrade});

  @override
  State<OpenTradeAnalysis> createState() => _OpenTradeAnalysisState();
}

class _OpenTradeAnalysisState extends State<OpenTradeAnalysis> {
  late TradeCardModel _tradeData;
  late double _livePrice;
  final _apiService = ApiService();
  Timer? _priceTimer;
  RealtimeChannel? _tradeChannel;

  @override
  void initState() {
    super.initState();
    _tradeData = widget.activeTrade.trade;
    _livePrice = widget.activeTrade.currentPrice;
    _startPriceTimer();
    _setupRealtimeSubscription();
  }

  void _startPriceTimer() {
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _updateLivePrice(),
    );
  }

  Future<void> _updateLivePrice() async {
    if (!mounted) return;
    try {
      final prices = await _apiService.getLivePrices([_tradeData.stockSymbol]);
      if (mounted && prices.containsKey(_tradeData.stockSymbol)) {
        setState(() {
          _livePrice = prices[_tradeData.stockSymbol]!;
        });
      }
    } catch (e) {
      debugPrint("Failed to update live price on detail screen: $e");
    }
  }

  void _setupRealtimeSubscription() {
    final channelName =
        'trade_${_tradeData.id}_${DateTime.now().millisecondsSinceEpoch}';
    _tradeChannel = Supabase.instance.client.channel(channelName);
    _tradeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _tradeData.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            final eventType = payload.eventType;
            if (eventType == PostgresChangeEvent.update) {
              try {
                final updatedRecord = TradeCardModel.fromJson(
                  payload.newRecord,
                );
                setState(() {
                  _tradeData = updatedRecord;
                });
                if (updatedRecord.status != 'open') {
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) Navigator.of(context).pop();
                  });
                }
              } catch (e) {
                debugPrint('Error parsing updated trade record: $e');
              }
            } else if (eventType == PostgresChangeEvent.delete) {
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) Navigator.of(context).pop();
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    if (_tradeChannel != null) {
      _tradeChannel!.unsubscribe();
      Supabase.instance.client.removeChannel(_tradeChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ActiveTradeCardViewModel(
      trade: _tradeData,
      currentPrice: _livePrice,
    );
    if (_tradeData.status != 'open') {
      return Scaffold(
        appBar: AppBar(title: const Text('Trade Analysis')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'This trade has been closed.',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Status: ${_tradeData.status.replaceAll('_', ' ').toUpperCase()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Trade Analysis')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHeader(context, viewModel),
          const SizedBox(height: 24),
          _buildLiveIndicator(context, viewModel),
          const SizedBox(height: 24),
          _buildLevels(context, viewModel),
          const SizedBox(height: 16),
          _buildStats(context, viewModel),
          const SizedBox(height: 16),
          _buildDetailsCard(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ActiveTradeCardViewModel trade) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            trade.stockSymbol.substring(0, 1),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trade.stockSymbol,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                trade.companyName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              trade.currentPriceFormatted,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Last Close: ₹${trade.trade.lastPrice.toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveIndicator(
    BuildContext context,
    ActiveTradeCardViewModel trade,
  ) {
    return LiveTradeIndicator(
      stopLoss: trade.trade.stopLoss,
      target: trade.trade.target,
      entryPrice: trade.trade.entryPrice,
      currentPrice: trade.currentPrice,
      tradeDirection: trade.trade.tradeDirection, // Add this line
    );
  }

  Widget _buildLevels(BuildContext context, ActiveTradeCardViewModel trade) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLevelItem(context, 'Entry', trade.entryPrice),
          Container(
            width: 1,
            height: 30,
            color: Theme.of(context).dividerColor,
          ),
          _buildLevelItem(context, 'Stop Loss', trade.stopLoss),
          Container(
            width: 1,
            height: 30,
            color: Theme.of(context).dividerColor,
          ),
          _buildLevelItem(context, 'Target', trade.targetPrice),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context, ActiveTradeCardViewModel trade) {
    final theme = Theme.of(context);
    final isProfit = trade.isProfit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatItem(
                  context,
                  'Estimated Gain',
                  trade.estimatedGain,
                  theme.colorScheme.secondary,
                ),
                const SizedBox(height: 16),
                _buildStatItem(
                  context,
                  'Live Return',
                  trade.liveReturn,
                  isProfit
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.error,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatItem(
                  context,
                  'Estimated Risk',
                  '-${((trade.trade.entryPrice - trade.trade.stopLoss) / trade.trade.entryPrice * 100).toStringAsFixed(2)}%',
                  theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                _buildStatItem(
                  context,
                  'Risk/Reward',
                  '${((trade.trade.target - trade.trade.entryPrice) / (trade.trade.entryPrice - trade.trade.stopLoss)).abs().toStringAsFixed(2)}x',
                  theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
    BuildContext context,
    ActiveTradeCardViewModel trade,
  ) {
    final theme = Theme.of(context);
    final statusColor =
        trade.isProfit ? theme.colorScheme.secondary : theme.colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trade Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildDetailRow(context, 'Entry Date', '15 Aug 2:03pm'),
            _buildDetailRow(
              context,
              'Live Status',
              trade.liveStatus,
              valueColor: statusColor,
            ),
            _buildDetailRow(context, 'Stop Loss', trade.stopLoss),
            _buildDetailRow(context, 'Target', trade.targetPrice),
            _buildDetailRow(
              context,
              'Trade Direction',
              trade.trade.tradeDirection,
            ),
            _buildDetailRow(
              context,
              'Trade Category',
              trade.trade.tradeCategory,
            ),
            _buildDetailRow(context, 'Trade Segment', trade.trade.tradeSegment),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.hintColor)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ClosedTradesAnalysis extends StatelessWidget {
  final ClosedTradeCardViewModel trade;

  const ClosedTradesAnalysis({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trade Analysis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            _buildReturnCard(context),
            const SizedBox(height: 16),
            _buildDurationCard(context),
            const SizedBox(height: 16),
            _buildDetailsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Text(
            trade.stockSymbol.substring(0, 1),
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trade.stockSymbol,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                trade.companyName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                softWrap: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Exit Price',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            Text(
              trade.exitPriceFormatted,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReturnCard(BuildContext context) {
    final theme = Theme.of(context);
    final profitColor = theme.colorScheme.secondary;
    final lossColor = theme.colorScheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(
                  context,
                  'Return',
                  trade.gainLossPercent,
                  valueStyle: TextStyle(
                    color: trade.wasProfitable ? profitColor : lossColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildInfoColumn(
                  context,
                  'Risk/Reward Ratio',
                  trade.riskReward,
                  valueStyle: TextStyle(
                    color: profitColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: theme.dividerColor),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(
                  context,
                  'Entry',
                  trade.entryPriceFormatted,
                  subLabel: 'Timestamp',
                ),
                _buildInfoColumn(
                  context,
                  'Exit',
                  trade.exitPriceFormatted,
                  subLabel: 'Timestamp',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabelValueRow(context, 'Trade Duration', '23 Days'),
                  const SizedBox(height: 12),
                  _buildLabelValueRow(
                    context,
                    'Trade Segment',
                    trade.trade.tradeSegment,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabelValueRow(
                    context,
                    'Trade Direction',
                    trade.trade.tradeDirection,
                  ),
                  const SizedBox(height: 12),
                  _buildLabelValueRow(
                    context,
                    'Trade Category',
                    trade.trade.tradeCategory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    final theme = Theme.of(context);
    Color getStatusColor() {
      if (trade.wasProfitable) return theme.colorScheme.secondary;
      if (trade.wasLoss) return theme.colorScheme.error;
      return theme.hintColor;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trade Details',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildDetailRow(context, 'Entry Date & Time', '15 Aug 2:03pm'),
            _buildDetailRow(context, 'Exit Date & Time', '15 Aug 4:03pm'),
            _buildDetailRow(
              context,
              'Status',
              trade.tradeStatus,
              valueColor: getStatusColor(),
            ),
            _buildDetailRow(
              context,
              'Stop Loss',
              '₹${trade.trade.stopLoss.toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              context,
              'Target',
              '₹${trade.trade.target.toStringAsFixed(2)}',
            ),
            _buildDetailRow(context, 'Segment', trade.trade.tradeSegment),
            _buildDetailRow(context, 'Signal Category', 'Trading'),
            _buildDetailRow(
              context,
              'Trade Category',
              trade.trade.tradeCategory,
            ),
            _buildDetailRow(
              context,
              'Trade Direction',
              trade.trade.tradeDirection,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(
    BuildContext context,
    String label,
    String value, {
    TextStyle? valueStyle,
    String? subLabel,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style:
              valueStyle ??
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (subLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            subLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor.withOpacity(0.8),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLabelValueRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: theme.hintColor)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// --- AUTHENTICATION SCREENS ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(labelText: 'Password'),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                onPressed: _signIn,
                child: const Text('Sign In'),
              ),
          const SizedBox(height: 16),
          TextButton(
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SignUpScreen()),
                ),
            child: const Text('Don\'t have an account? Sign Up'),
          ),
        ],
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'role': 'user'},
      );

      if (response.user != null && mounted) {
        await Supabase.instance.client
            .from('profiles')
            .update({
              'first_name': _firstNameController.text.trim(),
              'last_name': _lastNameController.text.trim(),
              'mobile_number': _mobileController.text.trim(),
            })
            .eq('id', response.user!.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Success! Please check your email for verification.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $error')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mobileController,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 6)
                  return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _passwordController.text)
                  return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                  onPressed: _signUp,
                  child: const Text('Sign Up'),
                ),
          ],
        ),
      ),
    );
  }
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.gpp_bad_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              const Text(
                'Access Denied',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This application is for users only. Please use the advisor application to log in with an advisor account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdditionalDetailsScreen extends StatefulWidget {
  final VoidCallback onProfileSaved;

  const AdditionalDetailsScreen({super.key, required this.onProfileSaved});

  @override
  State<AdditionalDetailsScreen> createState() =>
      _AdditionalDetailsScreenState();
}

class _AdditionalDetailsScreenState extends State<AdditionalDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _mobileController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] ?? '';
    if (fullName.isNotEmpty) {
      final names = fullName.split(' ');
      _firstNameController.text = names.first;
      if (names.length > 1) {
        _lastNameController.text = names.sublist(1).join(' ');
      }
    }
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'mobile_number': _mobileController.text.trim(),
          })
          .eq('id', user.id);

      if (mounted) {
        widget.onProfileSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'Please provide a few more details to continue.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mobileController,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                  onPressed: _completeProfile,
                  child: const Text('Save and Continue'),
                ),
          ],
        ),
      ),
    );
  }
}

class FilterChipRowWidget extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const FilterChipRowWidget({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filters = ['All', 'In Profit', 'In Loss', 'At Cost'];
    final isLightTheme = theme.brightness == Brightness.light;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;
          return ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            onSelected: (selected) => {if (selected) onFilterChanged(filter)},
            backgroundColor: theme.inputDecorationTheme.fillColor,
            selectedColor: theme.colorScheme.primary,
            labelStyle: TextStyle(
              color:
                  isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.transparent : theme.dividerColor,
              ),
            ),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class LiveTradeIndicator extends StatelessWidget {
  final double stopLoss;
  final double target;
  final double entryPrice;
  final double currentPrice;
  final String tradeDirection; // NEW: Added trade direction

  const LiveTradeIndicator({
    Key? key,
    required this.stopLoss,
    required this.target,
    required this.entryPrice,
    required this.currentPrice,
    required this.tradeDirection, // NEW
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 50),
      painter: _TradeIndicatorPainter(
        stopLoss: stopLoss,
        target: target,
        entryPrice: entryPrice,
        currentPrice: currentPrice,
        tradeDirection: tradeDirection,
        // NEW
        profitColor: Theme.of(context).colorScheme.secondary,
        lossColor: Theme.of(context).colorScheme.error,
        textColor: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
      ),
    );
  }
}

class _TradeIndicatorPainter extends CustomPainter {
  final double stopLoss;
  final double target;
  final double entryPrice;
  final double currentPrice;
  final String tradeDirection; // NEW
  final Color profitColor;
  final Color lossColor;
  final Color textColor;

  _TradeIndicatorPainter({
    required this.stopLoss,
    required this.target,
    required this.entryPrice,
    required this.currentPrice,
    required this.tradeDirection, // NEW
    required this.profitColor,
    required this.lossColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // UPDATED: Robustly calculate the range and min/max values
    final minVal = math.min(stopLoss, target);
    final maxVal = math.max(stopLoss, target);
    final totalRange = maxVal - minVal;
    if (totalRange <= 0) return;

    // UPDATED: This function now works regardless of trade direction
    double getX(double price) {
      final clampedPrice = price.clamp(minVal, maxVal);
      return ((clampedPrice - minVal) / totalRange) * size.width;
    }

    final paint = Paint()..strokeCap = StrokeCap.round;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final lineY = size.height / 2;

    final currentX = getX(currentPrice);

    // UPDATED: Profit/loss logic now depends on tradeDirection
    bool isProfit;
    if (tradeDirection == 'Buy') {
      isProfit = currentPrice >= entryPrice;
    } else {
      // 'Sell'
      isProfit = currentPrice <= entryPrice;
    }
    final progressColor = isProfit ? profitColor : lossColor;

    // Draw the colored part of the line
    paint.color = progressColor;
    paint.strokeWidth = 4;
    canvas.drawLine(Offset(0, lineY), Offset(currentX, lineY), paint);

    // Draw the remaining gray part of the line
    paint.color = Colors.grey.shade600;
    paint.strokeWidth = 2;
    canvas.drawLine(Offset(currentX, lineY), Offset(size.width, lineY), paint);

    // Draw a distinct point for the current live price
    paint.color = progressColor;
    canvas.drawCircle(Offset(currentX, lineY), 6, paint);
    paint.color = Colors.white;
    canvas.drawCircle(Offset(currentX, lineY), 3, paint);

    // Helper function to draw markers and labels
    void drawMarker(double price, String label, {bool isAbove = false}) {
      final x = getX(price);
      paint.color = Colors.grey.shade400;
      paint.strokeWidth = 1.5;
      canvas.drawLine(Offset(x, lineY - 8), Offset(x, lineY + 8), paint);

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();
      final yPos = isAbove ? lineY - textPainter.height - 12 : lineY + 12;
      textPainter.paint(canvas, Offset(x - (textPainter.width / 2), yPos));
    }

    drawMarker(stopLoss, 'SL');
    drawMarker(entryPrice, 'Entry', isAbove: true);
    drawMarker(target, 'Target');
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
