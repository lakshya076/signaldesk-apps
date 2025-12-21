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
      name: '${json['first_name']} ${json['last_name']}',
      email: json['email'],
      licenseType: details?['license_type'] ?? 'N/A',
      registrationNumber: details?['registration_number'] ?? 'N/A',
    );
  }
}
