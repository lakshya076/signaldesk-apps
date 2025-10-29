import 'package:signaldesk_user/models/trade_card_model.dart';

class ActiveTradeCardViewModel {
  final TradeCardModel trade;
  final double currentPrice;

  ActiveTradeCardViewModel({required this.trade, required this.currentPrice});

  String get stockSymbol => trade.stockSymbol;

  String get companyName => trade.stockName;

  String get advisorName => trade.advisorName;

  String get tradeDirection => trade.tradeDirection;

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
    if (tradeDirection == 'Buy') {
      return currentPrice >= trade.entryPrice;
    } else {
      return currentPrice <= trade.entryPrice;
    }
  }

  double get progress {
    if (trade.status != 'open') return isProfit ? 1.0 : 0.0;
    final range = (trade.target - trade.stopLoss).abs();
    if (range <= 0) return 0.5; // Failsafe
    final value = (currentPrice - trade.stopLoss).abs() / range;
    return value.clamp(0.0, 1.0);
  }

  String get liveStatus {
    if (status != 'open') return status.replaceAll('_', ' ').toUpperCase();

    final pnl = liveReturnValue;
    if (pnl.abs() < 0.1) return 'At Cost';
    if (pnl > 0) return 'In Profit';
    return 'In Loss';
  }

  String get estimatedGain {
    if (trade.entryPrice == 0) return '0.00%';
    final double gainPercent;
    if (tradeDirection == 'Buy') {
      gainPercent =
          ((trade.target - trade.entryPrice) / trade.entryPrice) * 100;
    } else {
      gainPercent =
          ((trade.entryPrice - trade.target) / trade.entryPrice) * 100;
    }
    return '+${gainPercent.toStringAsFixed(2)}%';
  }

  String get estimatedRisk {
    if (trade.entryPrice == 0) return '0.00%';

    final double riskPercent;
    if (tradeDirection == 'Buy') {
      riskPercent =
          ((trade.entryPrice - trade.stopLoss) / trade.entryPrice) * 100;
    } else {
      riskPercent =
          ((trade.stopLoss - trade.entryPrice) / trade.entryPrice) * 100;
    }
    return '-${riskPercent.toStringAsFixed(2)}%';
  }

  String get riskReward =>
      '${((trade.entryPrice - trade.stopLoss) / (trade.target - trade.entryPrice)).abs().toStringAsFixed(2)}x';

  double get liveReturnValue {
    if (trade.entryPrice == 0) return 0.0;

    if (tradeDirection == 'Buy') {
      return ((currentPrice - trade.entryPrice) / trade.entryPrice) * 100;
    } else {
      // For 'Sell' trades, profit is (entry - current)
      return ((trade.entryPrice - currentPrice) / trade.entryPrice) * 100;
    }
  }

  String get liveReturn {
    final gain = liveReturnValue;
    return '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(2)}%';
  }

  String get status => trade.status;
}
