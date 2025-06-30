import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/user_dashboard_screen.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';

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

    // اختبار اتصال قاعدة البيانات
    print('🔗 اختبار اتصال قاعدة البيانات...');
    final authService = AuthService();
    final dbConnected = await authService.testDatabaseConnection();

    if (!dbConnected) {
      print('⚠️ تحذير: مشكلة في اتصال قاعدة البيانات');
    }

    // إنشاء المشرف الافتراضي
    print('👤 إنشاء المشرف الافتراضي...');
    await authService.createDefaultAdmin();
    print('✅ تم التحقق من إنشاء المشرف الافتراضي');
  } catch (e, stackTrace) {
    print('❌ خطأ في تهيئة Firebase: $e');
    print('Stack trace: $stackTrace');

    // محاولة الاستمرار بدون Firebase للاختبار
    print('⚠️ المتابعة بدون Firebase...');
  }

  runApp(const ChallengeAndRiskApp());
}

class ChallengeAndRiskApp extends StatefulWidget {
  const ChallengeAndRiskApp({super.key});

  @override
  State<ChallengeAndRiskApp> createState() => _ChallengeAndRiskAppState();
}

class _ChallengeAndRiskAppState extends State<ChallengeAndRiskApp>
    with WidgetsBindingObserver {
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.detached:
        // إيقاف كامل للصوت عند الخروج النهائي من التطبيق
        _audioService.stopAllAudio();
        print('تم إيقاف جميع الأصوات - الخروج من التطبيق');
        break;
      case AppLifecycleState.paused:
        // إيقاف مؤقت عند إخفاء التطبيق
        _audioService.pauseMusic();
        print('تم إيقاف الصوت مؤقتاً - التطبيق في الخلفية');
        break;
      case AppLifecycleState.resumed:
        // استئناف الصوت عند العودة للتطبيق (إذا كان مُفعلاً)
        if (_audioService.isMusicEnabled) {
          _audioService.ensureMainMenuMusicPlaying();
          print('تم استئناف الصوت - التطبيق نشط');
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // إيقاف مؤقت للصوت
        _audioService.pauseMusic();
        break;
    }
  }

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

      home: const AuthCheckScreen(),
    );
  }
}

// شاشة فحص المصادقة
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final AuthService _authService = AuthService();
  final bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // انتظار لمدة 3 ثوانٍ لعرض Splash Screen
      await Future.delayed(const Duration(seconds: 3));

      // محاولة تسجيل الدخول التلقائي
      final autoLoginSuccess = await _authService.tryAutoLogin();

      if (mounted) {
        if (autoLoginSuccess) {
          final user = _authService.currentUser;
          if (user != null && user.canManageQuestions()) {
            // إذا كان المستخدم مشرف، الذهاب للوحة الإدارة
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const AdminDashboardScreen(),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
          } else if (user != null) {
            // المستخدم عادي، الذهاب للوحة المستخدم
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const UserDashboardScreen(),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
          } else {
            // لا يوجد مستخدم، الذهاب للصفحة الرئيسية
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder:
                    (context, animation, secondaryAnimation) =>
                        const HomeScreen(),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 800),
              ),
            );
          }
        } else {
          // لا يوجد تسجيل دخول سابق، عرض الصفحة الرئيسية
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const HomeScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 800),
            ),
          );
        }
      }
    } catch (e) {
      print('خطأ في فحص حالة المصادقة: $e');
      // في حالة الخطأ، الذهاب للصفحة الرئيسية
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) => const HomeScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
