import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/game_mode_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase - تحقق من عدم التهيئة المسبقة
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // إذا كان Firebase مهيأ بالفعل، استخدم التطبيق الموجود
      Firebase.app();
    }
  } catch (e) {
    print('Firebase initialization error: $e');
    // حاول استخدام التطبيق الافتراضي إذا كان موجوداً
    try {
      Firebase.app();
    } catch (e2) {
      print('Firebase app access error: $e2');
    }
  }

  runApp(const ChallengeAndRiskApp());
}

class ChallengeAndRiskApp extends StatelessWidget {
  const ChallengeAndRiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'التحدي والمخاطرة',
      debugShowCheckedModeBanner: false,

      // دعم اللغة العربية
      locale: const Locale('ar', 'SA'),

      // إعدادات الـ RTL للعربية
      builder: (context, child) {
        return Directionality(textDirection: TextDirection.rtl, child: child!);
      },

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,

        // خط مناسب للعربية
        fontFamily: 'Arial',

        // إعدادات AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),

        // إعدادات الأزرار
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 3,
          ),
        ),

        // إعدادات حقول النص
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
      ),

      home: const GameModeScreen(),
    );
  }
}
