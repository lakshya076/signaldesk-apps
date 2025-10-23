import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/features/auth/login_screen.dart';
import 'package:signaldesk_user/features/user_main_screen.dart';
import 'package:signaldesk_user/features/auth/access_denied_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Map<String, dynamic>?> _getProfileData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final response =
    await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.session != null) {
          return FutureBuilder<Map<String, dynamic>?>(
            future: _getProfileData(),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final profile = profileSnapshot.data;
              if (profile == null) {
                return const LoginScreen(); // Fallback to login if profile doesn't exist
              }

              if (profile['role'] == 'user') {
                return const UserMainScreen();
              } else {
                return const AccessDeniedScreen();
              }
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}
