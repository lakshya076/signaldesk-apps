import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slide_to_act/slide_to_act.dart';

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

class WatchlistItem {
  final int id;
  final String stockSymbol;
  Stock? stockData;

  WatchlistItem({required this.id, required this.stockSymbol, this.stockData});
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
  });

  factory TradeCardModel.fromJson(Map<String, dynamic> json) {
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
    );
  }
}

// ViewModel to handle calculated properties for the Active Trade UI
class ActiveTradeCardViewModel {
  final TradeCardModel trade;
  final double currentPrice;

  ActiveTradeCardViewModel({required this.trade, required this.currentPrice});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

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

// ViewModel for the Closed Trade UI
class ClosedTradeCardViewModel {
  final TradeCardModel trade;

  ClosedTradeCardViewModel({required this.trade});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

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

  // REMOVED: The statusColor getter is gone. The widget will handle this now.

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

class AdvisorStats {
  final int followerCount;
  final int totalClosedTrades;
  final int profitableTrades;
  final double hitRate;

  AdvisorStats({
    required this.followerCount,
    required this.totalClosedTrades,
    required this.profitableTrades,
    required this.hitRate,
  });

  // A factory to create an instance from Supabase JSON
  factory AdvisorStats.fromJson(Map<String, dynamic> json) {
    return AdvisorStats(
      followerCount: json['follower_count'] ?? 0,
      totalClosedTrades: json['total_closed_trades'] ?? 0,
      profitableTrades: json['profitable_trades'] ?? 0,
      hitRate: (json['hit_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // A factory for when no data is found, preventing null errors
  factory AdvisorStats.empty() {
    return AdvisorStats(
      followerCount: 0,
      totalClosedTrades: 0,
      profitableTrades: 0,
      hitRate: 0.0,
    );
  }
}

// --- API Service ---
class ApiService {
  final String _apiBaseUrl = 'https://cb09ae5c854a.ngrok-free.app';

  Future<Map<String, Stock>> getAllStocks() async {
    final response = await http.get(Uri.parse('$_apiBaseUrl/get-all-stocks'));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final stockData = decoded['data'] as Map<String, dynamic>;
      return stockData.map(
        (key, value) => MapEntry(key, Stock.fromJson(key, value)),
      );
    } else {
      throw Exception('Failed to load stocks');
    }
  }

  Future<Map<String, double>> getLivePrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/get-live-prices'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'symbols': symbols}),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final prices = (decoded['data'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
      return prices;
    } else {
      throw Exception('Failed to load live prices');
    }
  }

  Future<void> createTrade(Map<String, dynamic> tradeData) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception("User is not authenticated");
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/create-trade'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(tradeData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create trade: ${response.body}');
    }
  }
}

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: "https://wvnfmsgnqydelrrpwfic.supabase.co",
    anonKey: "sb_publishable_v2xTPguM2YQqSMOI1QHA3Q_MlQdj7Zu",
  );

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? true;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'Trade Advisor',
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

// In main.dart, replace the existing AuthGate widget

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Map<String, dynamic>?> _getProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    // CHANGED: Use .maybeSingle() to safely handle cases where the profile doesn't exist.
    // This returns null instead of throwing an error if no row is found.
    final response =
        await Supabase.instance.client
            .from('profiles')
            .select('role, is_verified')
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

              // NEW: Added explicit error handling for unexpected issues
              if (profileSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Text(
                      'Error loading profile: ${profileSnapshot.error}',
                    ),
                  ),
                );
              }

              final profile = profileSnapshot.data;
              // If the profile is null, the user is in an invalid state.
              // The safest action is to send them back to the login screen.
              if (profile == null) {
                return const LoginScreen();
              }

              if (profile['role'] == 'advisor') {
                if (!profile['is_verified']) {
                  return const PendingApprovalScreen();
                }
                return const AdvisorMainScreen();
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

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approval')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_top_outlined, size: 60),
              const SizedBox(height: 24),
              const Text(
                'Account Under Review',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Thank you for registering. Your profile is currently being reviewed by our team. You will be notified by email once it is approved.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ADVISOR UI SCREENS ---
// --- ADVISOR UI SCREENS ---
class AdvisorMainScreen extends StatefulWidget {
  const AdvisorMainScreen({super.key});

  @override
  _AdvisorMainScreenState createState() => _AdvisorMainScreenState();
}

class _AdvisorMainScreenState extends State<AdvisorMainScreen> {
  int _selectedIndex = 0;
  Stock? _stockToCreateTrade;

  // Key to access the WatchlistScreen's state and call its refresh method
  final GlobalKey<_WatchlistScreenState> _watchlistKey =
      GlobalKey<_WatchlistScreenState>();

  void _onItemTapped(int index) {
    setState(() {
      if (index != 4) _stockToCreateTrade = null;
      _selectedIndex = index;
    });
  }

  // A method to refresh the watchlist from this parent widget
  void _refreshWatchlist() {
    _watchlistKey.currentState?.fetchWatchlistPublic();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      AdvisorHomeScreen(
        onViewActive: () => _onItemTapped(1),
        onViewClosed: () => _onItemTapped(2),
      ),
      const AllActiveTradesScreen(),
      const AllClosedTradesScreen(),
      // Assign the GlobalKey to the WatchlistScreen instance
      WatchlistScreen(
        key: _watchlistKey,
        onCreateTrade: (stock) {
          setState(() {
            _stockToCreateTrade = stock;
            _selectedIndex = 4;
          });
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
        onTap: _onItemTapped,
      ),
    );
  }
}

class AdvisorHomeScreen extends StatefulWidget {
  final VoidCallback onViewActive;
  final VoidCallback onViewClosed;

  const AdvisorHomeScreen({
    super.key,
    required this.onViewActive,
    required this.onViewClosed,
  });

  @override
  State<AdvisorHomeScreen> createState() => _AdvisorHomeScreenState();
}

class _AdvisorHomeScreenState extends State<AdvisorHomeScreen> {
  // NEW: State variable for advisor statistics
  AdvisorStats? _advisorStats;
  List<TradeCardModel> _activeTrades = [];
  List<TradeCardModel> _closedTrades = [];
  Map<String, double> _livePrices = {};
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _priceTimer;
  final _apiService = ApiService();
  RealtimeChannel? _tradesChannel;
  String? _advisorId;

  @override
  void initState() {
    super.initState();
    _initializeAdvisorData();
  }

  Future<void> _initializeAdvisorData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _handleError('User not authenticated');
      return;
    }

    _advisorId = currentUser.id;
    // UPDATED: Fetch all data in parallel for faster loading
    await _fetchAdvisorData();
    _setupRealtimeSubscription();
  }

  // NEW: Function to fetch both stats and trades
  Future<void> _fetchAdvisorData() async {
    if (_advisorId == null) return;

    try {
      setState(() {
        _errorMessage = null;
        if (_advisorStats == null) {
          _isLoading = true;
        }
      });

      // Fetch stats and trades concurrently
      final responses = await Future.wait([
        Supabase.instance.client
            .from('advisor_statistics')
            .select()
            .eq('advisor_id', _advisorId!)
            .maybeSingle(), // Use maybeSingle to safely handle no-stats case
        Supabase.instance.client
            .from('trade_cards')
            .select()
            .eq('advisor_id', _advisorId!)
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;

      // Process statistics response
      final statsResponse = responses[0] as Map<String, dynamic>?;
      final fetchedStats =
          statsResponse != null
              ? AdvisorStats.fromJson(statsResponse)
              : AdvisorStats.empty();

      // Process trades response
      final tradesResponse = responses[1] as List<dynamic>;
      final allCards =
          tradesResponse
              .map((e) => TradeCardModel.fromJson(e as Map<String, dynamic>))
              .toList();

      setState(() {
        _advisorStats = fetchedStats;
        _activeTrades = allCards.where((c) => c.status == 'open').toList();
        _closedTrades = allCards.where((c) => c.status != 'open').toList();
        _isLoading = false;
        _errorMessage = null;
      });

      _startPriceTimer();
    } catch (e) {
      _handleError('Error fetching advisor data: $e');
    }
  }

  void _setupRealtimeSubscription() {
    if (_advisorId == null) return;

    try {
      _tradesChannel =
          Supabase.instance.client
              .channel('public:trade_cards:advisor=$_advisorId:home')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'trade_cards',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'advisor_id',
                  value: _advisorId,
                ),
                callback: (payload) {
                  debugPrint('Realtime change received: ${payload.toString()}');
                  if (mounted) {
                    // Just refetch everything to keep it simple and consistent
                    _fetchAdvisorData();
                  }
                },
              )
              .subscribe();
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _cleanupRealtimeSubscription();
    super.dispose();
  }

  void _cleanupRealtimeSubscription() {
    if (_tradesChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_tradesChannel!);
      } catch (e) {
        debugPrint('Error removing realtime channel: $e');
      }
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _startPriceTimer() {
    _priceTimer?.cancel();

    if (_activeTrades.isNotEmpty) {
      _priceTimer = Timer.periodic(
        const Duration(seconds: 5),
        (timer) => _updateLivePrices(),
      );
      _updateLivePrices();
    }
  }

  Future<void> _updateLivePrices() async {
    if (_activeTrades.isEmpty || !mounted) return;

    try {
      final symbols =
          _activeTrades
              .map((card) => card.stockSymbol)
              .where((symbol) => symbol.isNotEmpty)
              .toSet()
              .toList();

      if (symbols.isEmpty) return;

      final prices = await _apiService.getLivePrices(symbols);
      if (mounted) {
        setState(() => _livePrices = prices);
      }
    } catch (e) {
      debugPrint("Error fetching live prices: $e");
    }
  }

  Future<void> _refresh() async {
    _priceTimer?.cancel();
    await _fetchAdvisorData();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _refresh, child: _buildContent());
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _advisorStats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAdvisorData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Main layout with stats grid and trade lists
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // NEW: Stats Grid Section
        _buildStatsGrid(),
        const SizedBox(height: 24),
        _buildSectionHeader('Active Trades', widget.onViewActive),
        _buildTradeList(_activeTrades, true),
        const SizedBox(height: 24),
        _buildSectionHeader('Closed Trades', widget.onViewClosed),
        _buildTradeList(_closedTrades, false),
      ],
    );
  }

  // NEW: Widget to build the 2x2 statistics grid
  Widget _buildStatsGrid() {
    final stats = _advisorStats!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      // Adjust this ratio for card shape
      children: [
        _StatCard(
          icon: Icons.people_outline,
          label: 'Followers',
          value: stats.followerCount.toString(),
          color: Colors.blue.shade400,
        ),
        _StatCard(
          icon: Icons.check_circle_outline,
          label: 'Hit Rate',
          value: '${stats.hitRate.toStringAsFixed(1)}%',
          color: Colors.green.shade400,
        ),
        _StatCard(
          icon: Icons.bar_chart,
          label: 'Profitable Trades',
          value: stats.profitableTrades.toString(),
          color: Colors.amber.shade400,
        ),
        _StatCard(
          icon: Icons.history,
          label: 'Total Closed',
          value: stats.totalClosedTrades.toString(),
          color: Colors.purple.shade400,
        ),
      ],
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
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
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
          child: Column(
            children: [
              Icon(
                isActive ? Icons.trending_up : Icons.history,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'No ${isActive ? 'active' : 'closed'} trades found.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayTrades = trades.take(3).toList();
    return Column(
      children:
          displayTrades.asMap().entries.map((entry) {
            final index = entry.key;
            final trade = entry.value;

            Widget tradeCard;
            if (isActive) {
              final livePrice =
                  _livePrices[trade.stockSymbol] ?? trade.lastPrice;
              final viewModel = ActiveTradeCardViewModel(
                trade: trade,
                currentPrice: livePrice,
              );
              tradeCard = ActiveTradeCardWidget(trade: viewModel);
            } else {
              final viewModel = ClosedTradeCardViewModel(trade: trade);
              tradeCard = ClosedTradeCardWidget(trade: viewModel);
            }

            return Padding(
              padding: EdgeInsets.only(top: index == 0 ? 8.0 : 16.0),
              child: tradeCard,
            );
          }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12.0), // Slightly reduced padding
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: color), // Slightly smaller icon
          const Spacer(), // Use Spacer for flexible layout
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // THIS IS THE KEY CHANGE:
              // FittedBox scales the text down to prevent it from overflowing.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
                maxLines: 1, // Prevent label from wrapping
                overflow:
                    TextOverflow.ellipsis, // Add '...' if label is too long
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AllActiveTradesScreen extends StatefulWidget {
  const AllActiveTradesScreen({super.key});

  @override
  State<AllActiveTradesScreen> createState() => _AllActiveTradesScreenState();
}

class _AllActiveTradesScreenState extends State<AllActiveTradesScreen> {
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
    _fetchTradeCards();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final advisorId = Supabase.instance.client.auth.currentUser!.id;
    final channelName =
        'active_trades_${advisorId}_${DateTime.now().millisecondsSinceEpoch}';

    _tradesChannel = Supabase.instance.client.channel(channelName);

    _tradesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'advisor_id',
            value: advisorId,
          ),
          callback: (payload) {
            if (mounted) {
              _fetchTradeCards();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tradesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchTradeCards() async {
    try {
      final advisorId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('trade_cards')
          .select()
          .eq('advisor_id', advisorId)
          .eq('status', 'open')
          .order('created_at', ascending: false);

      final cards =
          (response as List).map((e) => TradeCardModel.fromJson(e)).toList();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching trades: $e")));
        setState(() => _isLoading = false);
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
      final prices = await _apiService.getLivePrices(symbols);
      if (mounted) {
        setState(() {
          _livePrices = prices;
          _filterAndRefresh();
        });
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
            if (_selectedFilter == 'At Cost') {
              return vm.liveReturnValue.abs() < 0.1;
            }
            return false;
          }).toList();
    }
    setState(() {});
  }

  Future<void> _refresh() async {
    _timer?.cancel();
    await _fetchTradeCards();
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
          child: RefreshIndicator(
            onRefresh: _refresh,
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredTradeCards.isEmpty
                    ? Center(
                      child: Text(
                        _tradeCards.isEmpty
                            ? 'You have no active trades.'
                            : 'No trades match the filter.',
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
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
        ),
      ],
    );
  }
}

class AllClosedTradesScreen extends StatefulWidget {
  const AllClosedTradesScreen({super.key});

  @override
  State<AllClosedTradesScreen> createState() => _AllClosedTradesScreenState();
}

class _AllClosedTradesScreenState extends State<AllClosedTradesScreen> {
  List<TradeCardModel> _tradeCards = [];
  List<ClosedTradeCardViewModel> _filteredTradeCards = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  RealtimeChannel? _tradesChannel;

  @override
  void initState() {
    super.initState();
    _fetchTradeCards();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final advisorId = Supabase.instance.client.auth.currentUser!.id;
    final channelName =
        'closed_trades_${advisorId}_${DateTime.now().millisecondsSinceEpoch}';

    _tradesChannel = Supabase.instance.client.channel(channelName);

    _tradesChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trade_cards',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'advisor_id',
            value: advisorId,
          ),
          callback: (payload) {
            if (mounted) {
              _fetchTradeCards();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _tradesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchTradeCards() async {
    try {
      final advisorId = Supabase.instance.client.auth.currentUser!.id;
      final response = await Supabase.instance.client
          .from('trade_cards')
          .select()
          .eq('advisor_id', advisorId)
          .neq('status', 'open')
          .order('created_at', ascending: false);

      final cards =
          (response as List).map((e) => TradeCardModel.fromJson(e)).toList();
      if (mounted) {
        setState(() {
          _tradeCards = cards;
          _isLoading = false;
        });
        _filterAndRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching trades: $e")));
        setState(() => _isLoading = false);
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
                          ? 'You have no closed trades.'
                          : 'No trades match the filter.',
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
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

// --- WATCHLIST & SEARCH ---
class WatchlistScreen extends StatefulWidget {
  final Function(Stock) onCreateTrade;

  const WatchlistScreen({super.key, required this.onCreateTrade});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
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
    // Set loading state only if the list is currently empty
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
      for (var item in watchlistItems) {
        item.stockData = allStocks[item.stockSymbol];
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
      const Duration(seconds: 5),
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
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close the dialog
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Remove'),
              onPressed: () async {
                try {
                  // Delete the item from the database using its unique ID
                  await Supabase.instance.client
                      .from('watchlists')
                      .delete()
                      .match({'id': item.id});

                  if (!mounted) return;

                  Navigator.of(dialogContext).pop(); // Close the dialog

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$stockSymbol removed from watchlist'),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );

                  // Refresh the watchlist UI
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
              child: _WatchlistTile(
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

class _WatchlistTile extends StatefulWidget {
  final Stock? stock;
  final double livePrice;
  final double change;
  final double percentChange;
  final Function(Stock) onCreateTrade;

  const _WatchlistTile({
    super.key,
    this.stock,
    required this.livePrice,
    required this.change,
    required this.percentChange,
    required this.onCreateTrade,
  });

  @override
  State<_WatchlistTile> createState() => _WatchlistTileState();
}

class _WatchlistTileState extends State<_WatchlistTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.stock == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isPositive = widget.change >= 0;
    final color =
        isPositive ? theme.colorScheme.secondary : theme.colorScheme.error;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stock!.symbol,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.stock!.name,
                        style: TextStyle(color: theme.hintColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${widget.livePrice.toStringAsFixed(2)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${isPositive ? '+' : ''}${widget.change.toStringAsFixed(2)} (${widget.percentChange.toStringAsFixed(2)}%)',
                      style: theme.textTheme.bodyMedium?.copyWith(color: color),
                    ),
                  ],
                ),
              ],
            ),
            if (_isExpanded)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 32),

                  // START OF CHANGES

                  // The old TextButton.icon is replaced with a full-width InkWell
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) => SetAlertScreen(
                                isPositive: isPositive,
                                stock: widget.stock!,
                              ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      // Adds vertical padding to make tapping easier
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_none,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Set Alert',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => widget.onCreateTrade(widget.stock!),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Create Trade Idea'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

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
      await Supabase.instance.client.from('watchlists').insert({
        'advisor_id': advisorId,
        'stock_symbol': symbol,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$symbol added to watchlist'),
            backgroundColor: Colors.green, // Use a success color
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return; // Guard against async errors after dispose

      // Check if the error is from Supabase and is a unique constraint violation
      if (e is PostgrestException && e.code == '23505') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$symbol is already in your watchlist.'),
            // Use a neutral or warning color, not a hard error color
            backgroundColor: Colors.amber.shade800,
          ),
        );
      } else {
        // For all other unexpected errors
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

class SetAlertScreen extends StatefulWidget {
  final Stock stock;
  final bool isPositive;

  const SetAlertScreen({
    super.key,
    required this.isPositive,
    required this.stock,
  });

  @override
  State<SetAlertScreen> createState() => _SetAlertScreenState();
}

class _SetAlertScreenState extends State<SetAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetPriceController = TextEditingController();
  String _notifyMeOption = 'Every time';
  bool _isSaving = false;

  Future<void> _setAlert() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final advisorId = Supabase.instance.client.auth.currentUser!.id;
      final targetPrice = double.parse(_targetPriceController.text);

      final alertData = {
        'advisor_id': advisorId,
        'stock_symbol': widget.stock.symbol,
        'target_price': targetPrice,
        'notify_frequency': _notifyMeOption,
      };

      await Supabase.instance.client.from('alerts').insert(alertData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert has been created successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set alert: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _targetPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        widget.isPositive
            ? theme.colorScheme.secondary
            : theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Set Alert')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stock.symbol,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.stock.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '₹${widget.stock.lastPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildRow(
                'Target Price',
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    controller: _targetPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.end,
                    // Align text to the right for prices
                    decoration: const InputDecoration(hintText: 'Enter price'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildRow(
                'Notify Me',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(child: _buildNotifyButton('Every time')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildNotifyButton('Once')),
                  ],
                ),
              ),
              const Spacer(),
              // Spacer works fine here because the parent Column fills the Scaffold body
              ElevatedButton(
                onPressed: _setAlert,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text('Set Alert'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // THIS IS THE CORRECTED METHOD
  Widget _buildRow(String label, Widget control) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 16),
        // This Expanded widget solves the layout error
        Expanded(child: control),
      ],
    );
  }

  Widget _buildNotifyButton(String option) {
    final theme = Theme.of(context);
    final isSelected = _notifyMeOption == option;
    return ElevatedButton(
      onPressed: () => setState(() => _notifyMeOption = option),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected
                ? theme.colorScheme.primary
                : theme.inputDecorationTheme.fillColor,
        foregroundColor:
            isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(option),
    );
  }
}

class CreateTradeCardScreen extends StatefulWidget {
  final Stock? preselectedStock;

  const CreateTradeCardScreen({super.key, this.preselectedStock});

  @override
  _CreateTradeCardScreenState createState() => _CreateTradeCardScreenState();
}

class _CreateTradeCardScreenState extends State<CreateTradeCardScreen> {
  final _slideActionKey = GlobalKey<SlideActionState>();
  final _formKey = GlobalKey<FormState>();
  final _stockSymbolController = TextEditingController();
  final _livePriceController = TextEditingController();
  final _lastPriceController = TextEditingController();
  final _stopLossController = TextEditingController();
  final _targetController = TextEditingController();
  final _entryZoneController = TextEditingController();
  final _exitZoneController = TextEditingController();

  String _tradeDirection = 'Buy';
  Stock? _selectedStock;
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedStock != null) {
      _setSelectedStock(widget.preselectedStock!);
    }
    _targetController.addListener(_updateExitZone);
  }

  void _setSelectedStock(Stock stock) {
    setState(() {
      _selectedStock = stock;
      _stockSymbolController.text = stock.symbol;
      final livePrice = stock.entryPrice;
      _livePriceController.text = livePrice.toStringAsFixed(2);
      _lastPriceController.text = stock.lastPrice.toStringAsFixed(2);

      final entryZoneStart = (livePrice * 0.99).toStringAsFixed(2);
      final entryZoneEnd = (livePrice * 1.01).toStringAsFixed(2);
      _entryZoneController.text = '$entryZoneStart - $entryZoneEnd';

      _targetController.clear();
      _exitZoneController.clear();
    });
  }

  void _updateExitZone() {
    final targetPrice = double.tryParse(_targetController.text);
    if (targetPrice != null) {
      final exitZoneStart = (targetPrice * 0.99).toStringAsFixed(2);
      final exitZoneEnd = (targetPrice * 1.01).toStringAsFixed(2);
      _exitZoneController.text = '$exitZoneStart - $exitZoneEnd';
    }
  }

  Future<void> _searchAndSelectStock() async {
    final selectedStock = await showModalBottomSheet<Stock>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      routeSettings: const RouteSettings(name: 'create_trade_search'),
      builder: (context) => const SearchScreen(),
    );
    if (selectedStock != null) _setSelectedStock(selectedStock);
  }

  Future<void> _createTrade() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final tradeData = {
        "stock_symbol": _selectedStock!.symbol,
        "stop_loss": double.parse(_stopLossController.text),
        "target": double.parse(_targetController.text),
        "trade_direction": _tradeDirection,
        "trade_category": "Swing", // Placeholder
        "trade_segment": "Equity", // Placeholder
        "entry_zone": _entryZoneController.text,
        "exit_zone": _exitZoneController.text,
      };

      await _apiService.createTrade(tradeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trade card created successfully!')),
        );
        context
            .findAncestorStateOfType<_AdvisorMainScreenState>()
            ?._onItemTapped(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _targetController.removeListener(_updateExitZone);
    _stockSymbolController.dispose();
    _livePriceController.dispose();
    _lastPriceController.dispose();
    _stopLossController.dispose();
    _targetController.dispose();
    _entryZoneController.dispose();
    _exitZoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildLabel('Stock Name'),
            InkWell(
              onTap: _searchAndSelectStock,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _stockSymbolController,
                  decoration: const InputDecoration(
                    hintText: 'Search Stock',
                    suffixIcon: Icon(Icons.search),
                  ),
                  validator:
                      (value) =>
                          (value == null || value.isEmpty)
                              ? 'Please select a stock'
                              : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _livePriceController,
                    decoration: const InputDecoration(labelText: 'Live Price'),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lastPriceController,
                    decoration: const InputDecoration(labelText: 'Last Price'),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Trade Direction'),
            Row(
              children: [
                Expanded(child: _buildDirectionButton('Buy')),
                Expanded(child: _buildDirectionButton('Sell')),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildLabel(
                    'Stop Loss (${_tradeDirection == 'Buy' ? 'Sell' : 'Buy'})',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLabel(
                    'Target (${_tradeDirection == 'Buy' ? 'Sell' : 'Buy'})',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stopLossController,
                    decoration: const InputDecoration(
                      hintText: 'Enter Stop Loss',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final sl = double.tryParse(value);
                      final livePrice = double.tryParse(
                        _livePriceController.text,
                      );
                      if (sl == null || livePrice == null) {
                        return 'Invalid number';
                      }
                      if (_tradeDirection == 'Buy' && sl >= livePrice) {
                        return 'SL must be below price';
                      }
                      if (_tradeDirection == 'Sell' && sl <= livePrice) {
                        return 'SL must be above price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _targetController,
                    decoration: const InputDecoration(hintText: 'Enter Target'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final target = double.tryParse(value);
                      final livePrice = double.tryParse(
                        _livePriceController.text,
                      );
                      if (target == null || livePrice == null) {
                        return 'Invalid number';
                      }
                      if (_tradeDirection == 'Buy' && target <= livePrice) {
                        return 'Target must be above price';
                      }
                      if (_tradeDirection == 'Sell' && target >= livePrice) {
                        return 'Target must be below price';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildLabel('Trade Category')),
                const SizedBox(width: 16),
                Expanded(child: _buildLabel('Trade Segment')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildDropdownPlaceholder('Swing')),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdownPlaceholder('Equity')),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Zones (Optional)'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _entryZoneController,
                    decoration: const InputDecoration(labelText: 'Entry Zone'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _exitZoneController,
                    decoration: const InputDecoration(labelText: 'Exit Zone'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SlideAction(
                  key: _slideActionKey,
                  text: 'Swipe to Create Trade Idea',
                  textStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16,
                  ),
                  outerColor: Theme.of(context).colorScheme.primary,
                  innerColor: Colors.white,
                  sliderButtonIcon: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.blue,
                  ),
                  onSubmit: () {
                    if (_formKey.currentState!.validate()) {
                      _createTrade();
                    } else {
                      _slideActionKey.currentState?.reset();
                    }
                    return null;
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
      ),
    );
  }

  Widget _buildDirectionButton(String direction) {
    final theme = Theme.of(context);
    final isSelected = _tradeDirection == direction;
    return ElevatedButton(
      onPressed: () => setState(() => _tradeDirection = direction),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected
                ? theme.colorScheme.primary
                : theme.inputDecorationTheme.fillColor,
        foregroundColor:
            isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(direction),
    );
  }

  Widget _buildDropdownPlaceholder(String hint) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            hint,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          Icon(Icons.arrow_drop_down, color: theme.hintColor),
        ],
      ),
    );
  }
}

class ActiveTradeCardWidget extends StatelessWidget {
  final ActiveTradeCardViewModel trade;

  const ActiveTradeCardWidget({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Logic to determine the outline color based on live performance
    final Color outlineColor;
    if (trade.liveReturnValue.abs() < 0.1) {
      outlineColor = theme.colorScheme.tertiary; // Yellow for At Cost
    } else if (trade.isProfit) {
      outlineColor = theme.colorScheme.secondary; // Green for Profit
    } else {
      outlineColor = theme.colorScheme.error; // Red for Loss
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
          // UPDATED: Border now uses the dynamic outline color
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

    // Logic to determine the outline color based on final status
    final Color outlineColor;
    if (trade.wasProfitable) {
      outlineColor = theme.colorScheme.secondary; // Green
    } else if (trade.wasLoss) {
      outlineColor = theme.colorScheme.error; // Red
    } else {
      outlineColor = theme.colorScheme.tertiary; // Yellow
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
          // UPDATED: Border now uses the dynamic outline color
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
              // If the trade is deleted, pop the screen
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
    _tradeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Create the ViewModel inside the build method using the latest state
    final viewModel = ActiveTradeCardViewModel(
      trade: _tradeData,
      currentPrice: _livePrice,
    );

    // If the status is no longer 'open', you might want to show a message
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

  // --- Helper methods now take the ViewModel ---

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
            // Placeholder
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
                overflow: TextOverflow.visible,
                maxLines: null,
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
            _buildDetailRow(context, 'Entry', '15 Aug 2:03pm'),
            _buildDetailRow(context, 'Exit', '15 Aug 4:03pm'),
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
  final _regNumController = TextEditingController();
  String? _selectedLicense;
  bool _isLoading = false;

  final List<String> _licenseTypes = [
    'SEBI Research Analyst',
    'SEBI Investment Advisor',
    'Registered Portfolio Manager',
  ];

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Step 1: Create the auth user. The database trigger will create the base profile rows.
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {'role': 'advisor'},
      );

      if (response.user != null && mounted) {
        // Step 2: Immediately update the new profile and details tables with all the form data.
        await Supabase.instance.client
            .from('profiles')
            .update({
              'first_name': _firstNameController.text.trim(),
              'last_name': _lastNameController.text.trim(),
              'mobile_number': _mobileController.text.trim(),
            })
            .eq('id', response.user!.id);

        await Supabase.instance.client
            .from('advisor_details')
            .update({
              'license_type': _selectedLicense!,
              'registration_number': _regNumController.text.trim(),
            })
            .eq('profile_id', response.user!.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Success! Please check your email for verification.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
    _regNumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up as Advisor')),
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
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLicense,
              decoration: const InputDecoration(labelText: 'License Type'),
              items:
                  _licenseTypes
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _selectedLicense = value),
              validator:
                  (value) =>
                      value == null ? 'Please select a license type' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _regNumController,
              decoration: const InputDecoration(
                labelText: 'Registration Number',
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
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
                'This application is for advisors only. Please use the user application to log in with a user account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: const Text('Logout'),
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ],
          ),
        ),
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
