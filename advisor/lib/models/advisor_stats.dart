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