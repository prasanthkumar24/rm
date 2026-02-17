import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/video_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'mobile_login_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Artificial delay to ensure splash is visible for at least a moment (optional)
    await Future.delayed(const Duration(seconds: 3));

    try {
      // Initialize Hive
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) { // Assuming VideoModelAdapter id is 0 or similar, checking registration
         Hive.registerAdapter(VideoModelAdapter());
      }
      
      // Check session
      final authService = AuthService();
      User? user = await authService.getSession();

      if (user != null) {
        // Verify if the session is still valid on the server
        final isValid = await authService.validateSession(user);
        if (!isValid) {
          // Session is invalid (expired or revoked), clear it
          await authService.logout();
          user = null;
        }
      }

      // If no valid session exists, we don't auto-login here anymore
      // because we want the user to go through the Mobile OTP flow.
      // The auto-login to Jellyfin happens inside OtpVerificationScreen.

      if (mounted) {
        if (user != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(user: user!)),
          );
        } else {
          // If no session, go to Mobile Login instead of Jellyfin Login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Initialization failed: $e');
      if (mounted) {
         Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MobileLoginScreen()),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.black, 
        ),
        child: Image.asset(
          'assets/splash_screen.png',
          fit: BoxFit.cover, // Fills the screen
        ),
      ),
    );
  }
}
