import 'package:signaldesk_advisor/models/trade_card_model.dart';

class ClosedTradeCardViewModel {
  final TradeCardModel trade;

  ClosedTradeCardViewModel({required this.trade});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

  String get tradeDirection => trade.tradeDirection;

  String get tradeCategory => trade.tradeCategory;

  String get tradeSegment => trade.tradeSegment;

  DateTime get createdAt => trade.createdAt;

  DateTime? get closedAt => trade.closedAt;

  double get exitPriceRaw {
    if (trade.manualExitPrice != null && trade.manualExitPrice! > 0) {
      return trade.manualExitPrice!;
    }

    if (trade.status == 'closed_profit') return trade.target;
    if (trade.status == 'closed_loss') return trade.stopLoss;
    return trade.entryPrice;
  }

  String get entryPrice => '₹${trade.entryPrice.toStringAsFixed(2)}';

  String get exitPrice => '₹${exitPriceRaw.toStringAsFixed(2)}';

  String get stopLoss => '₹${trade.stopLoss.toStringAsFixed(2)}';

  String get targetPrice => '₹${trade.target.toStringAsFixed(2)}';

  bool get wasProfitable => trade.status == 'closed_profit';

  bool get wasLoss => trade.status == 'closed_loss';

  String get tradeStatus {
    if (wasProfitable) return 'Trade Status: Profit';
    if (wasLoss) return 'Trade Status: Loss';
    return 'Trade Status: At Cost';
  }

  double get gainLossValue {
    final gain = exitPriceRaw - trade.entryPrice;
    return trade.tradeDirection == 'Sell' ? -gain : gain;
  }

  String get gainLossPercent {
    if (trade.entryPrice == 0) return '0.00%';
    final percent = (gainLossValue / trade.entryPrice) * 100;
    return '${percent >= 0 ? '+' : ''}${percent.toStringAsFixed(2)}%';
  }

  String get riskReward =>
      '${((trade.entryPrice - trade.stopLoss) / (trade.target - trade.entryPrice)).abs().toStringAsFixed(2)}x';
}
