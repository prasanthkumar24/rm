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
    try {
      await Future.delayed(const Duration(seconds: 2));

      // Initialize Hive
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
         Hive.registerAdapter(VideoModelAdapter());
      }
      
      final authService = AuthService();

      // Check if user has ever authenticated via mobile
      final bool isMobileAuthenticated = await authService.isMobileAuthenticated();

      if (isMobileAuthenticated) {
        // User has logged in with OTP before, go straight to home screen logic
        User? user = await authService.getSession();
        bool isServerAvailable = true;

        // Try to do a fresh login if we have credentials
        final credentials = await authService.getVideoCredentials();
        final username = credentials['username'];
        final password = credentials['password'];

        if (username != null && password != null) {
          try {
            // Attempt a fresh login on every app start
            final freshUser = await authService.login(
              user?.serverUrl ?? 'https://rmvideo.in',
              username,
              password,
            );
            if (freshUser != null) {
              user = freshUser;
              isServerAvailable = true;
            }
          } catch (e) {
            debugPrint('Automatic login failed on splash: $e');
            isServerAvailable = false;
            // If fresh login fails, we still have the cached session from getSession()
            // If user is null, we'll use a dummy user below.
          }
        } else if (user != null) {
          // If no credentials saved, just validate the existing session
          final result = await authService.validateSession(user);
          isServerAvailable = result.isServerAvailable;
          if (!result.isValid) {
            await authService.logout(); // Clear server-specific data, but not mobile auth flag
            user = null;
          }
        }

        if (user == null) {
          // Fallback if no user exists and login failed
          user = User(id: '', name: '', accessToken: '', serverUrl: 'https://rmvideo.in');
          isServerAvailable = false;
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => HomeScreen(
                user: user!,
                initialServerAvailable: isServerAvailable,
              ),
            ),
          );
        }
      } else {
        // First-time user, go to mobile login
        if (mounted) {
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
