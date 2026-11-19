import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'auth_service.dart';
import 'school_data_service.dart';
import 'school_signup_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Hive Local Database Initialization ---
  await Hive.initFlutter();

  // --- Firebase Initialization with Multi-Platform Fallback ---
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  runApp(const SmartSmsApp());
}

class SmartSmsApp extends StatelessWidget {
  const SmartSmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart SMS - School Management SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        // If not logged in -> Show Login Screen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const LoginScreen();
        }

        final user = authSnapshot.data!;

        // User is authenticated -> Check if School Profile exists
        return FutureBuilder<Map<String, String>?>(
          future: authService.fetchSchoolProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0F172A),
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.school, size: 64, color: Colors.blueAccent),
                      SizedBox(height: 24),
                      CircularProgressIndicator(color: Colors.blueAccent),
                      SizedBox(height: 16),
                      Text(
                        'Connecting to School Portal...',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            }

            final profile = profileSnapshot.data;

            // First-time Google user without an onboarded school
            if (profile == null) {
              return const SchoolSignupScreen();
            }

            // Existing School Profile Found -> Initialize Multi-Tenant DB & Enter Dashboard
            return FutureBuilder(
              future: SchoolDataService().initForUser(user.uid, initialSettings: profile),
              builder: (context, initSnapshot) {
                if (initSnapshot.connectionState == ConnectionState.waiting && !SchoolDataService().isInitialized) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0F172A),
                    body: Center(
                      child: CircularProgressIndicator(color: Colors.blueAccent),
                    ),
                  );
                }
                return const DashboardScreen();
              },
            );
          },
        );
      },
    );
  }
}

