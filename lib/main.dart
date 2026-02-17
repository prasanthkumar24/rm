import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/video_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => VideoService(),
      child: MaterialApp(
        title: 'RM LIVE',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // Define the deep teal/blue color scheme
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B6DCC), // Accent Blue
            secondary: Color(0xFF0E323E), // Card/Surface Color
            background: Color(0xFF00151C), // Deepest Background
            surface: Color(0xFF0E323E),
            onBackground: Colors.white,
            onSurface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFF00151C),
          useMaterial3: true,
          fontFamily: 'Sans', // Default to Sans, we will use Serif for headers
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontFamily: 'Serif', color: Colors.white),
            displayMedium: TextStyle(fontFamily: 'Serif', color: Colors.white),
            displaySmall: TextStyle(fontFamily: 'Serif', color: Colors.white),
            headlineLarge: TextStyle(fontFamily: 'Serif', color: Colors.white),
            headlineMedium: TextStyle(fontFamily: 'Serif', color: Colors.white),
            headlineSmall: TextStyle(fontFamily: 'Serif', color: Colors.white),
            titleLarge: TextStyle(fontFamily: 'Serif', color: Colors.white),
          ),
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
