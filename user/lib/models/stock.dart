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
