import 'package:signaldesk_user/models/trade_card_model.dart';

class ClosedTradeCardViewModel {
  final TradeCardModel trade;

  ClosedTradeCardViewModel({required this.trade});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

  String get advisorName => trade.advisorName;

  String get tradeCategory => trade.tradeCategory;

  String get tradeSegment => trade.tradeSegment;

  DateTime get createdAt => trade.createdAt;

  DateTime? get closedAt => trade.closedAt;

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
