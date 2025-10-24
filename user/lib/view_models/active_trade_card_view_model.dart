import 'package:signaldesk_user/models/trade_card_model.dart';

class ActiveTradeCardViewModel {
  final TradeCardModel trade;
  final double currentPrice;

  ActiveTradeCardViewModel({required this.trade, required this.currentPrice});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

  String get advisorName => trade.advisorName;

  String get tradeCategory => trade.tradeCategory;

  String get tradeSegment => trade.tradeSegment;

  DateTime get createdAt => trade.createdAt;

  String get entryPrice => '₹${trade.entryPrice.toStringAsFixed(2)}';

  String get stopLoss => '₹${trade.stopLoss.toStringAsFixed(2)}';

  String get targetPrice => '₹${trade.target.toStringAsFixed(2)}';

  bool get isSellTrade => trade.tradeDirection.toLowerCase() == 'sell';

  String get currentPriceFormatted => '₹${currentPrice.toStringAsFixed(2)}';

  double get priceChangeValue => currentPrice - trade.lastPrice;

  String get priceChange =>
      '${priceChangeValue >= 0 ? '+' : ''}₹${priceChangeValue.toStringAsFixed(2)} (${(priceChangeValue / trade.lastPrice * 100).toStringAsFixed(2)}%)';

  bool get isProfit {
    if (isSellTrade) {
      // for Sell
      return currentPrice <= trade.entryPrice;
    }
    return currentPrice >= trade.entryPrice;
  }

  double get progress {
    if (trade.status != 'open') return isProfit ? 1.0 : 0.0;

    if (isSellTrade) {
      // For SELL, progress is from StopLoss (high) down to Target (low)
      final range = trade.stopLoss - trade.target;
      if (range <= 0) return 0.5; // Failsafe
      final value = (trade.stopLoss - currentPrice) / range;
      return value.clamp(0.0, 1.0);
    } else {
      // For BUY, progress is from StopLoss (low) up to Target (high)
      final range = trade.target - trade.stopLoss;
      if (range <= 0) return 0.5; // Failsafe
      final value = (currentPrice - trade.stopLoss) / range;
      return value.clamp(0.0, 1.0);
    }
  }

  String get liveStatus {
    if (status != 'open') return status.replaceAll('_', ' ').toUpperCase();
    if (isProfit) return 'In Profit';
    return 'In Loss';
  }

  String get estimatedGain {
    double gain;
    if (isSellTrade) {
      // For SELL, gain is (Entry - Target) / Entry
      gain = ((trade.entryPrice - trade.target) / trade.entryPrice) * 100;
    } else {
      // For BUY, gain is (Target - Entry) / Entry
      gain = ((trade.target - trade.entryPrice) / trade.entryPrice) * 100;
    }
    // Handle potential division by zero if entryPrice is 0
    if (trade.entryPrice == 0) return '0.00%';
    return '${gain.toStringAsFixed(2)}%';
  }

  double get liveReturnValue {
    if (trade.entryPrice == 0) return 0.0; // Avoid division by zero
    if (isSellTrade) {
      // For SELL, return is (Entry - Current) / Entry
      return ((trade.entryPrice - currentPrice) / trade.entryPrice) * 100;
    }
    // For BUY, return is (Current - Entry) / Entry
    return ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100;
  }

  String get liveReturn {
    final gain = liveReturnValue;
    return '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%';
  }

  String get status => trade.status;
}
