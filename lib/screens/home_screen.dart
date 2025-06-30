import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/audio_service.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'local_settings_screen.dart';
import 'login_screen.dart';
import 'online_home_screen.dart';
import 'user_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  final AuthService _authService = AuthService();

  // Animation controllers
  late AnimationController _logoController;
  late AnimationController _titleController;
  late AnimationController _cardsController;
  late AnimationController _tipController;
  late AnimationController _pulseController;

  // Animations
  late Animation<double> _logoAnimation;
  late Animation<double> _titleAnimation;
  late Animation<Offset> _cardsSlideAnimation;
  late Animation<double> _cardsFadeAnimation;
  late Animation<double> _tipAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioService.addListener(_onAudioStateChanged);
    _initializeAudio();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Title animation controller
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Cards animation controller
    _cardsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Tip animation controller
    _tipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Pulse animation controller (continuous)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Define animations
    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutBack),
    );

    _cardsSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _cardsController, curve: Curves.easeOutCubic),
    );

    _cardsFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _cardsController, curve: Curves.easeOut));

    _tipAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _tipController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations with delays
    _startAnimations();
  }

  void _startAnimations() {
    // Start logo animation immediately
    _logoController.forward();

    // Start title animation after logo
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _titleController.forward();
    });

    // Start cards animation after title
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _cardsController.forward();
    });

    // Start tip animation after cards
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _tipController.forward();
    });

    // Start continuous pulse animation
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioService.removeListener(_onAudioStateChanged);
    _logoController.dispose();
    _titleController.dispose();
    _cardsController.dispose();
    _tipController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _onAudioStateChanged() {
    if (mounted) {
      setState(() {
        // تحديث الواجهة عند تغيير حالة الصوت
        // هذا سيحدث الأيقونة تلقائياً
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // تأكد من استمرار تشغيل الموسيقى فقط إذا كانت مُفعلة
      _audioService.ensureMainMenuMusicPlaying();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // تأكد من استمرار تشغيل الموسيقى فقط إذا كانت مُفعلة
    if (mounted) {
      _audioService.ensureMainMenuMusicPlaying();
    }
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
    // تحديث الواجهة بعد تهيئة الصوت لضمان عرض الأيقونة الصحيحة
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleAudio() {
    _audioService.toggleMusic();
    // تحديث الواجهة فوراً بعد تغيير حالة الموسيقى
    setState(() {});
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _goToAdminDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
    );
  }

  void _goToUserDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserDashboardScreen()),
    );
  }

  void _logout() async {
    try {
      // عرض مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // تسجيل الخروج
      await _authService.logout();

      // إغلاق مؤشر التحميل
      if (mounted) {
        Navigator.of(context).pop();

        // تحديث الواجهة
        setState(() {});

        // إظهار رسالة نجاح
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل الخروج بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // إغلاق مؤشر التحميل في حالة الخطأ
      if (mounted) {
        Navigator.of(context).pop();

        // إظهار رسالة خطأ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تسجيل الخروج: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text(
          'التحدي والمخاطرة',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // زر تسجيل الدخول/إدارة المستخدم
            if (user == null)
              IconButton(
                icon: const Icon(Icons.login, color: Colors.white),
                onPressed: _goToLogin,
                tooltip: 'تسجيل الدخول',
              )
            else
              PopupMenuButton<String>(
                icon: const Icon(Icons.person, color: Colors.white),
                onSelected: (value) async {
                  switch (value) {
                    case 'dashboard':
                      _goToAdminDashboard();
                      break;
                    case 'user_dashboard':
                      _goToUserDashboard();
                      break;
                    case 'logout':
                      _logout();
                      break;
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 8,
                color: Colors.white,
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'مرحباً ${user.username}',
                            style: TextStyle(
                              color: Colors.deepPurple.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      if (user.canManageQuestions())
                        PopupMenuItem(
                          value: 'dashboard',
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Row(
                              children: [
                                Icon(Icons.dashboard, color: Colors.deepPurple),
                                SizedBox(width: 12),
                                Text(
                                  'لوحة الإدارة',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (!user.canManageQuestions())
                        PopupMenuItem(
                          value: 'user_dashboard',
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  color: Colors.deepPurple,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'لوحة المستخدم',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logout',
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: const Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 12),
                              Text(
                                'تسجيل الخروج',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
              ),
          ],
        ),
        actions: [
          // Audio control button
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: IconButton(
              onPressed: _toggleAudio,
              icon: Icon(
                _audioService.isMusicEnabled && _audioService.isMusicPlaying
                    ? Icons.volume_up
                    : Icons.volume_off,
                color: Colors.white,
                size: 28,
              ),
              tooltip:
                  _audioService.isMusicEnabled && _audioService.isMusicPlaying
                      ? 'إيقاف الصوت'
                      : 'تشغيل الصوت',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // App logo/icon with animation
            ScaleTransition(
              scale: _logoAnimation,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            spreadRadius: 5,
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // Welcome text with animation
            ScaleTransition(
              scale: _titleAnimation,
              child: const Text(
                'مرحباً بك في لعبة التحدي والمخاطرة!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ),

            const SizedBox(height: 10),

            FadeTransition(
              opacity: _titleAnimation,
              child: const Text(
                'اختر نمط اللعبة المفضل لديك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 25),

            // Online mode button with animation
            SlideTransition(
              position: _cardsSlideAnimation,
              child: FadeTransition(
                opacity: _cardsFadeAnimation,
                child: _buildGameModeCard(
                  context: context,
                  title: 'لعب أونلاين',
                  subtitle: 'العب مع الأصدقاء من خلال كود الغرفة',
                  icon: Icons.wifi,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OnlineHomeScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Local mode button with animation
            SlideTransition(
              position: _cardsSlideAnimation,
              child: FadeTransition(
                opacity: _cardsFadeAnimation,
                child: _buildGameModeCard(
                  context: context,
                  title: 'لعب محلي',
                  subtitle: 'العب مع الأصدقاء على نفس الجهاز',
                  icon: Icons.people,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LocalSettingsScreen(),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Tip container with animation
            FadeTransition(
              opacity: _tipAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _tipController,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200, width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.amber, size: 24),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'نصيحة: اللعب الأونلاين يتيح لك اللعب مع أصدقائك من أي مكان!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.amber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom padding to prevent overflow
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGameModeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
            child: SizedBox(
              width: double.infinity,
              child: Card(
                elevation: isHovered ? 12 : 8,
                shadowColor: color.withOpacity(isHovered ? 0.4 : 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: InkWell(
                  onTap: () {
                    // Add tap animation
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient:
                          isHovered
                              ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color.withOpacity(0.1),
                                  color.withOpacity(0.05),
                                ],
                              )
                              : null,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color:
                                isHovered
                                    ? color.withOpacity(0.2)
                                    : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow:
                                isHovered
                                    ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                    : null,
                          ),
                          child: AnimatedScale(
                            scale: isHovered ? 1.1 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              icon,
                              size: 30,
                              color: isHovered ? color.withOpacity(0.8) : color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isHovered
                                          ? color.withOpacity(0.8)
                                          : Colors.deepPurple,
                                ),
                                child: Text(title),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isHovered
                                          ? color.withOpacity(0.7)
                                          : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.translationValues(
                            isHovered ? 5.0 : 0.0,
                            0.0,
                            0.0,
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios,
                            color: isHovered ? color : Colors.grey.shade400,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
