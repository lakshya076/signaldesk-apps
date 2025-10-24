import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ApiService {
  final String _apiBaseUrl = 'https://6f974a04bb48.ngrok-free.app';

  Future<Map<String, double>> getLivePrices(List<String> symbols) async {
    if (symbols.isEmpty) return {};
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/get-live-prices'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'symbols': symbols}),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      return (decoded['data'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
    } else {
      throw Exception('Failed to load live prices');
    }
  }

  Future<void> subscribeToInstrument(String symbol) async {
    if (symbol.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/subscribe-instrument'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'symbol': symbol, 'action': 'add'}),
      );

      if (response.statusCode == 200) {
        debugPrint('User App: ✓ Subscribed to $symbol for live data');
      } else {
        debugPrint(
          'User App: ⚠ Failed to subscribe to $symbol: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('User App: ✗ Error subscribing to $symbol: $e');
    }
  }

  Future<void> bulkSubscribeInstruments(List<String> symbols) async {
    if (symbols.isEmpty) return;
    try {
      // Calls the /bulk-subscribe endpoint created for the advisor app
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/bulk-subscribe'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'symbols': symbols, 'action': 'add'}),
      );

      if (response.statusCode == 200 || response.statusCode == 207) {
        debugPrint(
          'Bulk subscription request processed for ${symbols.length} instruments. Response: ${response.body}',
        );
      } else {
        debugPrint(
          'Failed to bulk subscribe: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error during bulk subscription: $e');
    }
  }
}
