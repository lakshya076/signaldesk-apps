// Backend address, set at build time: flutter run --dart-define=API_BASE_URL=https://your-host
// Android emulator reaching a backend on the host machine: http://10.0.2.2:8000
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
final String wsPricesUrl = '${apiBaseUrl.replaceFirst('http', 'ws')}/ws/prices';
