import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'features/auth/pages/welcome.dart';
import 'features/resident/pages/resident_dashboard.dart';
import 'features/worker/pages/worker_dashboard.dart';
import 'features/security/pages/security_dashboard.dart';
import 'features/authority/pages/authority_dashboard.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🛡️ Initialize App Check (Debug for dev, PlayIntegrity for prod)
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
  );

  // 🔔 Initialize Notification Service
  await NotificationService.initialize();

  runApp(const SafeNetApp());
}

class SafeNetApp extends StatelessWidget {
  const SafeNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AuthChecker(),
    );
  }
}

// Auth checker to handle auto-login
class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Splash delay

    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('user_role');
    final user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    // Check for authority login (uses SharedPreferences)
    if (userRole == 'authority' && prefs.getString('authority_uid') != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthorityDashboardPage()),
      );
      return;
    }

    // Check for Firebase Auth user (resident, worker, security)
    if (user != null && userRole != null) {
      Widget dashboard;
      switch (userRole) {
        case 'resident':
          dashboard = ResidentDashboardPage();
          break;
        case 'worker':
          dashboard = const WorkerDashboardPage();
          break;
        case 'security':
          dashboard = const SecurityDashboardPage();
          break;
        default:
          dashboard = const SafeNetWelcomePage();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dashboard),
      );
      return;
    }

    // No saved login, show welcome page
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SafeNetWelcomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
