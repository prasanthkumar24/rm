import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/video_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
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

      // If no session exists, perform auto-login
      if (user == null) {
        try {
          user = await authService.login(
            'https://rmvideo.in',
            'Appuser',
            'Smiles123\$',
          );
        } catch (e) {
          debugPrint('Auto-login failed: $e');
        }
      }

      if (mounted) {
        if (user != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => HomeScreen(user: user!)),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Initialization failed: $e');
      if (mounted) {
         Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
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
