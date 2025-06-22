import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'local_settings_screen.dart';
import 'login_screen.dart';
import 'online_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AudioService _audioService = AudioService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioService.addListener(_onAudioStateChanged);
    _initializeAudio();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioService.removeListener(_onAudioStateChanged);
    super.dispose();
  }

  void _onAudioStateChanged() {
    if (mounted) {
      setState(() {
        // تحديث الواجهة عند تغيير حالة الصوت
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
    // إزالة التشغيل الإجباري - النظام سيتولى ذلك حسب الإعدادات المحفوظة
  }

  void _toggleAudio() {
    _audioService.toggleMusic();
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

  void _logout() async {
    await _authService.logout();
    setState(() {});
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
                onSelected: (value) {
                  switch (value) {
                    case 'dashboard':
                      _goToAdminDashboard();
                      break;
                    case 'logout':
                      _logout();
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Text('مرحباً ${user.username}'),
                      ),
                      if (user.canManageQuestions())
                        const PopupMenuItem(
                          value: 'dashboard',
                          child: Row(
                            children: [
                              Icon(Icons.dashboard, color: Colors.deepPurple),
                              SizedBox(width: 8),
                              Text('لوحة الإدارة'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 8),
                            Text('تسجيل الخروج'),
                          ],
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
                _audioService.isMusicEnabled
                    ? Icons.volume_up
                    : Icons.volume_off,
                color: Colors.white,
                size: 28,
              ),
              tooltip:
                  _audioService.isMusicEnabled ? 'إيقاف الصوت' : 'تشغيل الصوت',
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

            // App logo/icon
            Container(
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

            const SizedBox(height: 30),

            // Welcome text
            const Text(
              'مرحباً بك في لعبة التحدي والمخاطرة!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'اختر نمط اللعبة المفضل لديك',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 25),

            // Online mode button
            _buildGameModeCard(
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

            const SizedBox(height: 20),

            // Local mode button
            _buildGameModeCard(
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

            const SizedBox(height: 40),

            Container(
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
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 30, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
