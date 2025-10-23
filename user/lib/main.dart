import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/advisor_filter_provider.dart';
import 'package:signaldesk_user/core/theme.dart';
import 'package:signaldesk_user/core/theme_provider.dart';
import 'package:signaldesk_user/features/auth/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- App Initialization ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: "https://wvnfmsgnqydelrrpwfic.supabase.co",
    anonKey: "sb_publishable_v2xTPguM2YQqSMOI1QHA3Q_MlQdj7Zu",
  );

  final themeProvider = ThemeProvider();
  await themeProvider.init(); // Load theme preference

  final advisorFilterProvider = AdvisorFilterProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => advisorFilterProvider),
      ],
      child: const UserApp(),
    ),
  );
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 4. Change this to a Consumer
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'SignalDesk User',
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AuthGate(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
