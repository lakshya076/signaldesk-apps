import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String _apiBaseUrl = 'https://ee65c42e95ef.ngrok-free.app';

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
}
