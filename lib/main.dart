import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة Firebase مع معالجة أفضل للأخطاء
  try {
    print('🚀 بدء تهيئة Firebase...');

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ تم تهيئة Firebase بنجاح');
    } else {
      // استخدام التطبيق الموجود
      final app = Firebase.app();
      print('✅ استخدام تطبيق Firebase الموجود: ${app.name}');
    }

    // التحقق من تهيئة Firebase
    final app = Firebase.app();
    print('📱 تفاصيل التطبيق:');
    print('   الاسم: ${app.name}');
    print('   الخيارات: ${app.options}');
  } catch (e, stackTrace) {
    print('❌ خطأ في تهيئة Firebase: $e');
    print('Stack trace: $stackTrace');

    // محاولة الاستمرار بدون Firebase للاختبار
    print('⚠️ المتابعة بدون Firebase...');
  }

  runApp(const ChallengeAndRiskApp());
}

class ChallengeAndRiskApp extends StatelessWidget {
  const ChallengeAndRiskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Challenge and Risk',
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

      home: const SplashScreen(),
    );
  }
}
