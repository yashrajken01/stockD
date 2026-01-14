import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gemini/flutter_gemini.dart';

import 'package:smart_grocery/firebase_options.dart';
import 'package:smart_grocery/screens/splash_screen.dart';
import 'theme/app_colors.dart';
import 'config/keys.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ SAFE Firebase init (prevents duplicate-app crash)
  if (Firebase.apps.isEmpty) {
    if (Platform.isAndroid) {
      // ✅ Let Android auto-initialize Firebase
      await Firebase.initializeApp();
    } else {
      // ✅ Required for web / desktop
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }

  // ✅ Initialize Gemini ONCE
  Gemini.init(apiKey: ApiKeys.gemini);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'stockD',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.surface,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.accent,
          surface: AppColors.surface,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
