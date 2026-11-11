// Backend address, set at build time: flutter run --dart-define=API_BASE_URL=https://your-host
// Android emulator reaching a backend on the host machine: http://10.0.2.2:8000
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
final String wsPricesUrl = '${apiBaseUrl.replaceFirst('http', 'ws')}/ws/prices';

// Supabase project, set at build time: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
// Defaults to the SignalDesk project. The publishable key is safe to ship; access is enforced by RLS.
const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://wvnfmsgnqydelrrpwfic.supabase.co');
const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'sb_publishable_v2xTPguM2YQqSMOI1QHA3Q_MlQdj7Zu');
