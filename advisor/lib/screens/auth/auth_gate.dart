import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/screens/auth/access_denied_screen.dart';
import 'package:signaldesk_advisor/screens/auth/login_screen.dart';
import 'package:signaldesk_advisor/screens/advisor_main_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pending_approval_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

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
            .select('role, is_verified')
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

              // Added explicit error handling for unexpected issues
              if (profileSnapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Text(
                      'Error loading profile: ${profileSnapshot.error}',
                    ),
                  ),
                );
              }

              final profile = profileSnapshot.data;
              // If the profile is null, the user is in an invalid state.
              // The safest action is to send them back to the login screen.
              if (profile == null) {
                return const LoginScreen();
              }

              if (profile['role'] == 'advisor') {
                if (!profile['is_verified']) {
                  return const PendingApprovalScreen();
                }
                return const AdvisorMainScreen();
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
