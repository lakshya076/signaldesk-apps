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
