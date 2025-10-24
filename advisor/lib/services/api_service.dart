import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class ApiService {
  final String _apiBaseUrl = 'https://ee65c42e95ef.ngrok-free.app';

  Future<Map<String, Stock>> getAllStocks() async {
    final response = await http.get(Uri.parse('$_apiBaseUrl/get-all-stocks'));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final stockData = decoded['data'] as Map<String, dynamic>;
      return stockData.map(
            (key, value) => MapEntry(key, Stock.fromJson(key, value)),
      );
    } else {
      throw Exception('Failed to load stocks');
    }
  }

  Future<Map<String, double>> getLivePrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/get-live-prices'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'symbols': symbols}),
    );

    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final prices = (decoded['data'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
      );
      return prices;
    } else {
      throw Exception('Failed to load live prices');
    }
  }

  Future<void> createTrade(Map<String, dynamic> tradeData) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception("User is not authenticated");
    }

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/create-trade'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(tradeData),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create trade: ${response.body}');
    }
  }

  Future<void> subscribeToInstrument(String symbol) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/subscribe-instrument'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'symbol': symbol, 'action': 'add'}),
      );

      if (response.statusCode == 200) {
        debugPrint('✓ Subscribed to $symbol for live data');
      } else {
        debugPrint('⚠ Failed to subscribe to $symbol: ${response.body}');
      }
    } catch (e) {
      debugPrint('✗ Error subscribing to $symbol: $e');
    }
  }

  Future<void> unsubscribeFromInstrument(String symbol) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/subscribe-instrument'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'symbol': symbol, 'action': 'remove'}),
      );

      if (response.statusCode == 200) {
        debugPrint('✓ Unsubscribed from $symbol');
      }
    } catch (e) {
      debugPrint('✗ Error unsubscribing from $symbol: $e');
    }
  }

  Future<Map<String, dynamic>?> getStockData(String symbol) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/get-stock-data/$symbol'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded['data'] as Map<String, dynamic>?;
      } else if (response.statusCode == 404) {
        debugPrint('Stock $symbol not found');
        return null;
      } else {
        throw Exception('Failed to load stock data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching stock data for $symbol: $e');
      return null;
    }
  }

  Future<bool> checkMarketStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/check-market-status'),
      );

      // If we get a 200 OK, the market is open
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        return decoded['status'] == 'open';
      }

      // Any other status code (like 503) will be treated as closed
      return false;
    } catch (e) {
      // This will catch network errors and 503 exceptions
      debugPrint('Market check failed: $e');
      return false;
    }
  }
}
