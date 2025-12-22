class Stock {
  final String symbol;
  final String name;
  final double entryPrice;
  final double lastPrice;
  final double? ltp;
  final double? prevCloseRedis;

  Stock({
    required this.symbol,
    required this.name,
    required this.entryPrice,
    required this.lastPrice,
    this.ltp,
    this.prevCloseRedis,
  });

  factory Stock.fromJson(String symbol, Map<String, dynamic> json) {
    return Stock(
      symbol: symbol,
      name: json['name'] ?? '',
      entryPrice: (json['entry_price'] as num?)?.toDouble() ?? 0.0,
      lastPrice: (json['last_price'] as num?)?.toDouble() ?? 0.0,
      ltp: (json['ltp'] as num?)?.toDouble(),
      prevCloseRedis: (json['prev_close'] as num?)?.toDouble(),
    );
  }
}
