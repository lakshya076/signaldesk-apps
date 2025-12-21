import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminStats {
  final UserGrowthStats userGrowth;
  final TradePerformanceStats tradePerformance;
  final PlatformActivityStats platformActivity;

  AdminStats({
    required this.userGrowth,
    required this.tradePerformance,
    required this.platformActivity,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      userGrowth: UserGrowthStats.fromJson(json['user_and_advisor_growth']),
      tradePerformance: TradePerformanceStats.fromJson(
        json['trade_and_performance'],
      ),
      platformActivity: PlatformActivityStats.fromJson(
        json['platform_activity'],
      ),
    );
  }
}

class UserGrowthStats {
  final int totalUsers;
  final int totalAdvisors;
  final int newUsersLast30d;
  final int newAdvisorsLast30d;
  final int totalSubscriptions;
  final List<DailyDataPoint> userRegistrationsLast7d;
  final List<DailyDataPoint> subscriptionActivityLast7d;

  UserGrowthStats({
    required this.totalUsers,
    required this.totalAdvisors,
    required this.newUsersLast30d,
    required this.newAdvisorsLast30d,
    required this.totalSubscriptions,
    required this.userRegistrationsLast7d,
    required this.subscriptionActivityLast7d,
  });

  factory UserGrowthStats.fromJson(Map<String, dynamic> json) {
    return UserGrowthStats(
      totalUsers: json['total_users'] ?? 0,
      totalAdvisors: json['total_advisors'] ?? 0,
      newUsersLast30d: json['new_users_last_30d'] ?? 0,
      newAdvisorsLast30d: json['new_advisors_last_30d'] ?? 0,
      totalSubscriptions: json['total_subscriptions'] ?? 0,
      userRegistrationsLast7d:
          (json['user_registrations_last_7d'] as List? ?? [])
              .map((item) => DailyDataPoint.fromJson(item))
              .toList(),
      subscriptionActivityLast7d:
          (json['subscription_activity_last_7d'] as List? ?? [])
              .map((item) => DailyDataPoint.fromJson(item))
              .toList(),
    );
  }
}

class TradePerformanceStats {
  final int totalTrades;
  final Map<String, int> breakdown;
  final List<TopAdvisor> topPerformingAdvisors;
  final List<TopStock> mostTradedStocks;

  TradePerformanceStats({
    required this.totalTrades,
    required this.breakdown,
    required this.topPerformingAdvisors,
    required this.mostTradedStocks,
  });

  factory TradePerformanceStats.fromJson(Map<String, dynamic> json) {
    return TradePerformanceStats(
      totalTrades: json['total_trades'] ?? 0,
      breakdown: Map<String, int>.from(json['trade_status_breakdown'] ?? {}),
      topPerformingAdvisors:
          (json['top_performing_advisors'] as List? ?? [])
              .map((item) => TopAdvisor.fromJson(item))
              .toList(),
      mostTradedStocks:
          (json['most_traded_stocks'] as List? ?? [])
              .map((item) => TopStock.fromJson(item))
              .toList(),
    );
  }
}

class PlatformActivityStats {
  final List<DailyDataPoint> tradesCreatedLast7d;

  PlatformActivityStats({required this.tradesCreatedLast7d});

  factory PlatformActivityStats.fromJson(Map<String, dynamic> json) {
    return PlatformActivityStats(
      tradesCreatedLast7d:
          (json['trades_created_last_7d'] as List? ?? [])
              .map((item) => DailyDataPoint.fromJson(item))
              .toList(),
    );
  }
}

class DailyDataPoint {
  final DateTime date;
  final int count;

  DailyDataPoint({required this.date, required this.count});

  factory DailyDataPoint.fromJson(Map<String, dynamic> json) {
    return DailyDataPoint(
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      count: json['count'] ?? 0,
    );
  }
}

class TopAdvisor {
  final String name;
  final double hitRate;

  TopAdvisor({required this.name, required this.hitRate});

  factory TopAdvisor.fromJson(Map<String, dynamic> json) {
    String firstName = json['first_name'] ?? '';
    String lastName = json['last_name'] ?? '';
    return TopAdvisor(
      name: '$firstName $lastName'.trim(),
      hitRate: (json['hit_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TopStock {
  final String symbol;
  final int tradeCount;

  TopStock({required this.symbol, required this.tradeCount});

  factory TopStock.fromJson(Map<String, dynamic> json) {
    return TopStock(
      symbol: json['stock_symbol'] ?? 'N/A',
      tradeCount: json['trade_count'] ?? 0,
    );
  }
}

class PendingAdvisor {
  final String id;
  final String name;
  final String email;
  final String licenseType;
  final String registrationNumber;

  PendingAdvisor({
    required this.id,
    required this.name,
    required this.email,
    required this.licenseType,
    required this.registrationNumber,
  });

  factory PendingAdvisor.fromJson(Map<String, dynamic> json) {
    final details = json['advisor_details'] as Map<String, dynamic>?;
    return PendingAdvisor(
      id: json['id'],
      name: '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}'.trim(),
      email: json['email'] ?? 'N/A',
      licenseType: details?['license_type'] ?? 'N/A',
      registrationNumber: details?['registration_number'] ?? 'N/A',
    );
  }
}

class ApiService {
  final String _apiBaseUrl = 'https://e7d6114c6c3d.ngrok-free.app';

  Future<AdminStats> getDashboardStats() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_apiBaseUrl/admin/dashboard-stats'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return AdminStats.fromJson(decoded['data']);
    } else {
      throw Exception('Failed to load stats: ${response.body}');
    }
  }

  Future<List<PendingAdvisor>> getPendingAdvisors() async {
    final session = Supabase.instance.client.auth.currentSession;
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/admin/pending-advisors'),
      headers: {'Authorization': 'Bearer ${session?.accessToken}'},
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body)['data'];
      return data.map((item) => PendingAdvisor.fromJson(item)).toList();
    }
    throw Exception('Failed to load pending advisors');
  }

  Future<void> approveAdvisor(String id) async {
    final session = Supabase.instance.client.auth.currentSession;
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/admin/approve-advisor/$id'),
      headers: {'Authorization': 'Bearer ${session?.accessToken}'},
    );

    if (response.statusCode != 200) {
      throw Exception('Approval failed: ${response.body}');
    }
  }
}

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

class AppThemes {
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    colorScheme: ThemeData.dark().colorScheme.copyWith(
      primary: const Color(0xFF3B82F6),
      secondary: Colors.green.shade400,
      error: Colors.red.shade400,
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
    cardTheme: CardThemeData(
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
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
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
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          title: 'SignalDesk Admin',
          theme: AppThemes.darkTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: currentMode,
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

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
                return const LoginScreen();
              }
              if (profile['role'] == 'admin') {
                return const AdminHomeScreen();
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

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardTab(),
    const AdvisorVerificationTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_reg_outlined),
            activeIcon: Icon(Icons.how_to_reg),
            label: 'Approvals',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({Key? key}) : super(key: key);

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final ApiService _apiService = ApiService();
  AdminStats? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final stats = await _apiService.getDashboardStats();
      setState(() {
        _stats = stats;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
                _stats = null;
              });
              _fetchStats();
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Error: $_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    if (_stats == null) {
      return const Center(child: Text('No data available.'));
    }

    final stats = _stats!;
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionHeader('User & Advisor Growth'),
        _buildUserGrowthGrid(stats.userGrowth),
        const SizedBox(height: 24),
        CustomBarChart(
          title: 'New Users (Last 7 Days)',
          data: stats.userGrowth.userRegistrationsLast7d,
          barColor: Colors.blue.shade300,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Trade & Performance'),
        _buildTradePerformanceGrid(stats.tradePerformance),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                children: [
                  TradeStatusPieChart(
                    breakdown: stats.tradePerformance.breakdown,
                  ),
                  const SizedBox(height: 16),
                  TopListCard(
                    title: 'Top Stocks',
                    items:
                        stats.tradePerformance.mostTradedStocks
                            .map((s) => '${s.symbol}: ${s.tradeCount} trades')
                            .toList(),
                    icon: Icons.show_chart,
                  ),
                ],
              );
            } else {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TradeStatusPieChart(
                      breakdown: stats.tradePerformance.breakdown,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TopListCard(
                      title: 'Top Stocks',
                      items:
                          stats.tradePerformance.mostTradedStocks
                              .map((s) => '${s.symbol}: ${s.tradeCount} trades')
                              .toList(),
                      icon: Icons.show_chart,
                    ),
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),
        TopListCard(
          title: 'Top Advisors (by Hit Rate)',
          items:
              stats.tradePerformance.topPerformingAdvisors
                  .map((a) => '${a.name}: ${a.hitRate.toStringAsFixed(1)}%')
                  .toList(),
          icon: Icons.person_search,
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Platform Activity'),
        CustomBarChart(
          title: 'New Trades (Last 7 Days)',
          data: stats.platformActivity.tradesCreatedLast7d,
          barColor: Colors.teal.shade300,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildUserGrowthGrid(UserGrowthStats userStats) {
    final stats = [
      StatCard(
        title: 'Total Users',
        value: userStats.totalUsers.toString(),
        icon: Icons.people,
      ),
      StatCard(
        title: 'Total Advisors',
        value: userStats.totalAdvisors.toString(),
        icon: Icons.supervised_user_circle,
      ),
      StatCard(
        title: 'Total Subs',
        value: userStats.totalSubscriptions.toString(),
        icon: Icons.subscriptions,
      ),
      StatCard(
        title: 'New Users (30d)',
        value: userStats.newUsersLast30d.toString(),
        icon: Icons.person_add,
      ),
      StatCard(
        title: 'New Advisors (30d)',
        value: userStats.newAdvisorsLast30d.toString(),
        icon: Icons.group_add,
      ),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => stats[index],
    );
  }

  Widget _buildTradePerformanceGrid(TradePerformanceStats tradeStats) {
    final stats = [
      StatCard(
        title: 'Total Trades',
        value: tradeStats.totalTrades.toString(),
        icon: Icons.swap_horiz,
        valueColor: Colors.amber.shade300,
      ),
      StatCard(
        title: 'Open Trades',
        value: tradeStats.breakdown['open']?.toString() ?? '0',
        icon: Icons.hourglass_top,
        valueColor: Colors.blue.shade300,
      ),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: stats.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) => stats[index],
    );
  }
}

class AdvisorVerificationTab extends StatefulWidget {
  const AdvisorVerificationTab({Key? key}) : super(key: key);

  @override
  State<AdvisorVerificationTab> createState() => _AdvisorVerificationTabState();
}

class _AdvisorVerificationTabState extends State<AdvisorVerificationTab> {
  final ApiService _apiService = ApiService();
  List<PendingAdvisor>? _advisors;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdvisors();
  }

  Future<void> _loadAdvisors() async {
    setState(() => _isLoading = true);
    try {
      final list = await _apiService.getPendingAdvisors();
      setState(() {
        _advisors = list;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApproval(String id) async {
    try {
      await _apiService.approveAdvisor(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advisor approved successfully')),
      );
      _loadAdvisors();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approval failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Advisors'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAdvisors),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Error: $_error'));
    }
    if (_advisors == null || _advisors!.isEmpty) {
      return const Center(child: Text('No pending advisors found.'));
    }

    return RefreshIndicator(
      onRefresh: _loadAdvisors,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _advisors!.length,
        itemBuilder: (context, index) {
          final advisor = _advisors![index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                        child: Text(
                          advisor.name.isNotEmpty ? advisor.name[0] : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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
                              advisor.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(advisor.email),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildDetailRow('License Type', advisor.licenseType),
                  _buildDetailRow('Reg Number', advisor.registrationNumber),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                      ),
                      onPressed: () => _handleApproval(advisor.id),
                      child: const Text('Approve Advisor'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 28,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            const Spacer(),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class CustomBarChart extends StatelessWidget {
  final String title;
  final List<DailyDataPoint> data;
  final Color barColor;

  const CustomBarChart({
    Key? key,
    required this.title,
    required this.data,
    required this.barColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue =
        data.isNotEmpty
            ? data.map((d) => d.count).reduce((a, b) => a > b ? a : b)
            : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (maxValue * 1.2).toDouble(),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          rod.toY.round().toString(),
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < data.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('d/M').format(data[index].date),
                                style: TextStyle(
                                  color: theme.hintColor,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups:
                      data
                          .asMap()
                          .map(
                            (index, dataPoint) => MapEntry(
                              index,
                              BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: dataPoint.count.toDouble(),
                                    color: barColor,
                                    width: 16,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .values
                          .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TradeStatusPieChart extends StatelessWidget {
  final Map<String, int> breakdown;

  const TradeStatusPieChart({Key? key, required this.breakdown})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalClosed =
        (breakdown['profit'] ?? 0) +
        (breakdown['loss'] ?? 0) +
        (breakdown['cost'] ?? 0);

    if (totalClosed == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text("Closed Trades", style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              const SizedBox(
                height: 120,
                child: Center(child: Text("No closed trades yet.")),
              ),
            ],
          ),
        ),
      );
    }

    List<PieChartSectionData> sections = [
      PieChartSectionData(
        value: breakdown['profit']?.toDouble() ?? 0,
        title:
            '${((breakdown['profit'] ?? 0) / totalClosed * 100).toStringAsFixed(0)}%',
        color: theme.colorScheme.secondary,
        radius: 50,
        titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      PieChartSectionData(
        value: breakdown['loss']?.toDouble() ?? 0,
        title:
            '${((breakdown['loss'] ?? 0) / totalClosed * 100).toStringAsFixed(0)}%',
        color: theme.colorScheme.error,
        radius: 50,
        titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      PieChartSectionData(
        value: breakdown['cost']?.toDouble() ?? 0,
        title:
            '${((breakdown['cost'] ?? 0) / totalClosed * 100).toStringAsFixed(0)}%',
        color: Colors.amber.shade400,
        radius: 50,
        titleStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text("Closed Trades", style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLegend(context, 'Profit', theme.colorScheme.secondary),
            _buildLegend(context, 'Loss', theme.colorScheme.error),
            _buildLegend(context, 'At Cost', Colors.amber.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, color: color),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

class TopListCard extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;

  const TopListCard({
    Key? key,
    required this.title,
    required this.items,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Text('No data available.')
            else
              ...items.asMap().entries.map((entry) {
                int index = entry.key;
                String itemText = entry.value;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                  title: Text(itemText),
                );
              }),
          ],
        ),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Admin Login',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({Key? key}) : super(key: key);

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
              ),
              const SizedBox(height: 16),
              const Text(
                'You do not have administrative privileges to access this dashboard.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed:
                    () async => await Supabase.instance.client.auth.signOut(),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
