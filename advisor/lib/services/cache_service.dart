import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signaldesk_advisor/models/advisor_stats.dart';
import 'package:signaldesk_advisor/models/trade_card_model.dart';

// A data class to hold cached price data
class PriceCache {
  final Map<String, double> livePrices;
  final Map<String, double> prevClosePrices;

  PriceCache({required this.livePrices, required this.prevClosePrices});
}

// A data class to hold cached trade data
class TradesCache {
  final List<TradeCardModel> activeTrades;
  final List<TradeCardModel> closedTrades;

  TradesCache({required this.activeTrades, required this.closedTrades});
}

/// A singleton service for managing all app data caching via SharedPreferences.
class CacheService {
  static final CacheService _instance = CacheService._internal();

  factory CacheService() {
    return _instance;
  }

  CacheService._internal();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _prefsInstance async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Cache Keys
  static const String _instrumentCacheKey = 'instrument_list_cache';
  static const String _instrumentTimestampKey = 'instrument_list_timestamp';
  static const String _priceCacheKey = 'watchlist_price_cache';
  static const String _prevCloseCacheKey = 'watchlist_prev_close_cache';
  static const String _prevCloseTimestampKey = 'watchlist_prev_close_timestamp';
  static const String _activeTradesCacheKey = 'active_trades_cache';
  static const String _closedTradesCacheKey = 'closed_trades_cache';
  static const String _advisorStatsCacheKey = 'advisor_stats_cache';

  // Instrument Cache (for Search)
  Future<void> saveInstrumentCache(Map<String, dynamic> data) async {
    final prefs = await _prefsInstance;
    await prefs.setString(_instrumentCacheKey, json.encode(data));
    await prefs.setInt(
      _instrumentTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<Map<String, dynamic>?> getInstrumentCache() async {
    final prefs = await _prefsInstance;
    final timestamp = prefs.getInt(_instrumentTimestampKey);

    if (timestamp != null) {
      final cacheAge = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
      // Invalidate instrument cache daily
      if (cacheAge < const Duration(days: 1)) {
        final data = prefs.getString(_instrumentCacheKey);
        if (data != null) {
          return json.decode(data) as Map<String, dynamic>;
        }
      }
    }
    return null;
  }

  // Price Caches (for Watchlist & Active Trades)
  Future<void> saveLivePrices(Map<String, double> prices) async {
    final prefs = await _prefsInstance;
    await prefs.setString(_priceCacheKey, json.encode(prices));
  }

  Future<void> savePrevClosePrices(Map<String, double> prices) async {
    final prefs = await _prefsInstance;
    await prefs.setString(_prevCloseCacheKey, json.encode(prices));
    await prefs.setInt(
      _prevCloseTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<PriceCache> getPriceCaches() async {
    final prefs = await _prefsInstance;
    Map<String, double> livePrices = {};
    Map<String, double> prevClosePrices = {};

    // Load Live Prices (no expiry)
    try {
      final liveData = prefs.getString(_priceCacheKey);
      if (liveData != null) {
        livePrices = (json.decode(liveData) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, v as double),
        );
      }
    } catch (e) {
      //Ignore
    }

    // Load PrevClose Prices (daily expiry)
    try {
      final timestamp = prefs.getInt(_prevCloseTimestampKey);
      if (timestamp != null) {
        final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final nowDate = DateTime.now();
        if (cacheDate.day == nowDate.day &&
            cacheDate.month == nowDate.month &&
            cacheDate.year == nowDate.year) {
          final prevCloseData = prefs.getString(_prevCloseCacheKey);
          if (prevCloseData != null) {
            prevClosePrices = (json.decode(prevCloseData)
                    as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, v as double));
          }
        }
      }
    } catch (e) {
      /* Caching error, ignore */
    }

    return PriceCache(livePrices: livePrices, prevClosePrices: prevClosePrices);
  }

  bool isPrevCloseCacheStale() {
    final timestamp = _prefs?.getInt(_prevCloseTimestampKey);
    if (timestamp != null) {
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final nowDate = DateTime.now();
      if (cacheDate.day == nowDate.day &&
          cacheDate.month == nowDate.month &&
          cacheDate.year == nowDate.year) {
        return false; // Cache is fresh
      }
    }
    return true; // Cache is stale or empty
  }

  // Trade List Caches (for Home & Trade Screens)
  Future<void> saveActiveTrades(List<dynamic> tradesJson) async {
    final prefs = await _prefsInstance;
    await prefs.setString(_activeTradesCacheKey, json.encode(tradesJson));
  }

  Future<void> saveClosedTrades(List<dynamic> tradesJson) async {
    final prefs = await _prefsInstance;
    await prefs.setString(_closedTradesCacheKey, json.encode(tradesJson));
  }

  Future<TradesCache> getTradesCache() async {
    final prefs = await _prefsInstance;
    List<TradeCardModel> activeTrades = [];
    List<TradeCardModel> closedTrades = [];

    try {
      final activeData = prefs.getString(_activeTradesCacheKey);
      if (activeData != null) {
        activeTrades =
            (json.decode(activeData) as List)
                .map(
                  (item) =>
                      TradeCardModel.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      }
    } catch (e) {
      /* Caching error, ignore */
    }

    try {
      final closedData = prefs.getString(_closedTradesCacheKey);
      if (closedData != null) {
        closedTrades =
            (json.decode(closedData) as List)
                .map(
                  (item) =>
                      TradeCardModel.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      }
    } catch (e) {
      /* Caching error, ignore */
    }

    return TradesCache(activeTrades: activeTrades, closedTrades: closedTrades);
  }

  // Advisor Stats Cache (for Home Screen)
  Future<void> saveAdvisorStats(Map<String, dynamic> statsJson) async {
    final prefs = await _prefsInstance;
    await prefs.setString(_advisorStatsCacheKey, json.encode(statsJson));
  }

  Future<AdvisorStats?> getAdvisorStatsCache() async {
    final prefs = await _prefsInstance;
    try {
      final data = prefs.getString(_advisorStatsCacheKey);
      if (data != null) {
        return AdvisorStats.fromJson(json.decode(data) as Map<String, dynamic>);
      }
    } catch (e) {
      /* Caching error, ignore */
    }
    return null;
  }
}
