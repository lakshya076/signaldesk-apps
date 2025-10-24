import 'package:signaldesk_advisor/models/trade_card_model.dart';

class ActiveTradeCardViewModel {
  final TradeCardModel trade;
  final double currentPrice;

  ActiveTradeCardViewModel({required this.trade, required this.currentPrice});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

  String get tradeDirection => trade.tradeDirection;

  String get tradeCategory => trade.tradeCategory;

  String get tradeSegment => trade.tradeSegment;

  DateTime get createdAt => trade.createdAt;

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
