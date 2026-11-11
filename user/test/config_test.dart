import 'package:flutter_test/flutter_test.dart';
import 'package:signaldesk_user/core/config.dart';

void main() {
  test('WebSocket URL is derived from the API base URL', () {
    // Default build (no --dart-define): local backend
    expect(apiBaseUrl, 'http://localhost:8000');
    expect(wsPricesUrl, 'ws://localhost:8000/ws/prices');
    // https backends must map to wss, not "ws" + "s://"
    expect('https://api.example.com'.replaceFirst('http', 'ws'), 'wss://api.example.com');
  });
}
