import 'package:flutter_test/flutter_test.dart';
import 'package:signaldesk_user/models/trade_card_model.dart';
import 'package:signaldesk_user/view_models/active_trade_card_view_model.dart';

TradeCardModel trade(String direction, {double entry = 100, double stop = 90, double target = 120}) =>
    TradeCardModel.fromJson({
      'id': 't1', 'stock_symbol': 'HDFCBANK', 'stock_name': 'HDFC Bank', 'status': 'open',
      'trade_direction': direction, 'entry_price': entry, 'stop_loss': stop, 'target': target,
      'last_price': entry, 'created_at': '2025-11-01T09:30:00Z',
    });

void main() {
  test('buy trade: profit when price rises', () {
    final vm = ActiveTradeCardViewModel(trade: trade('Buy'), currentPrice: 110);
    expect(vm.liveReturn, '+10.00%');
    expect(vm.liveStatus, 'In Profit');
    expect(vm.estimatedGain, '+20.00%');
    expect(vm.estimatedRisk, '-10.00%');
    expect(vm.riskReward, '2.00x');
    expect(vm.progress, closeTo(20 / 30, 1e-9));
  });

  test('sell trade: profit when price falls', () {
    final t = trade('Sell', stop: 110, target: 80);
    expect(ActiveTradeCardViewModel(trade: t, currentPrice: 90).liveReturn, '+10.00%');
    expect(ActiveTradeCardViewModel(trade: t, currentPrice: 105).liveStatus, 'In Loss');
    expect(ActiveTradeCardViewModel(trade: t, currentPrice: 90).estimatedGain, '+20.00%');
    expect(ActiveTradeCardViewModel(trade: t, currentPrice: 90).estimatedRisk, '-10.00%');
  });

  test('progress stays within 0..1 past target or stop', () {
    expect(ActiveTradeCardViewModel(trade: trade('Buy'), currentPrice: 200).progress, 1.0);
    expect(ActiveTradeCardViewModel(trade: trade('Buy'), currentPrice: 100.05).liveStatus, 'At Cost');
  });
}
