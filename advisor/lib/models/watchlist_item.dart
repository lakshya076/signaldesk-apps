import 'package:signaldesk_advisor/models/stock.dart';

class WatchlistItem {
  final int id;
  final String stockSymbol;
  Stock? stockData;

  WatchlistItem({required this.id, required this.stockSymbol, this.stockData});
}
