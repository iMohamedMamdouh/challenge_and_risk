import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/question.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/add_challenge_dialog.dart';
import '../widgets/add_question_dialog.dart';
import '../widgets/category_questions_screen.dart';
import '../widgets/edit_category_dialog.dart';
import '../widgets/edit_challenge_dialog.dart';
import 'home_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirebaseService _firebaseService = FirebaseService();

  late TabController _tabController;

  // بيانات الإحصائيات
  Map<String, dynamic> _questionsStats = {};
  Map<String, dynamic> _challengesStats = {};
  List<AppUser> _users = [];
  List<Question> _questions = [];
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _deletedQuestions = [];
  List<Map<String, dynamic>> _deletedChallenges = [];

  // بيانات الفئات
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  // متغير البحث للتحديات
  final TextEditingController _challengeSearchController =
      TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // تحميل الإحصائيات والبيانات
      final futures = await Future.wait([
        _firebaseService.getQuestionsStats(),
        _firebaseService.getChallengesStats(),
        _authService.getUsers(),
        _firebaseService.loadQuestionsFromFirebase(count: 50),
        _firebaseService.getAllChallenges(),
        _firebaseService.getDeletedQuestions(),
        _firebaseService.getDeletedChallenges(),
      ]);

      setState(() {
        _questionsStats = futures[0] as Map<String, dynamic>;
        _challengesStats = futures[1] as Map<String, dynamic>;
        _users = futures[2] as List<AppUser>;
        _questions = futures[3] as List<Question>;
        _challenges = futures[4] as List<Map<String, dynamic>>;
        _deletedQuestions = futures[5] as List<Map<String, dynamic>>;
        _deletedChallenges = futures[6] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('فشل في تحميل البيانات: $e');
    }
  }

  Future<List<dynamic>> loadQuestionsFromJson() async {
    final String jsonString = await rootBundle.loadString(
      'assets/data/questions.json',
    );
    return json.decode(jsonString) as List<dynamic>;
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await _firebaseService.getAllCategories();
      // تحميل الأسئلة من الملف المحلي
      final questions = await loadQuestionsFromJson();
      final Map<String, int> categoryCounts = {};
      for (final q in questions) {
        final cat = q['category'] ?? 'غير محدد';
        categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
      }
      // ربط العدد بكل فئة
      for (final category in categories) {
        final name = category['name'] as String;
        category['questions_count'] = categoryCounts[name] ?? 0;
      }
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() => _isLoadingCategories = false);
      print('خطأ في تحميل الفئات: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _authService.logout();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'لوحة الإدارة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showUserProfile();
                  break;
                case 'home':
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text('${user?.username}'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'home',
                    child: Row(
                      children: [
                        Icon(Icons.home, color: Colors.deepPurple),
                        SizedBox(width: 8),
                        Text('الصفحة الرئيسية'),
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'المعلومات'),
            Tab(icon: Icon(Icons.category), text: 'الفئات'),
            Tab(icon: Icon(Icons.sports_kabaddi), text: 'التحديات'),
            Tab(icon: Icon(Icons.people), text: 'المستخدمين'),
            Tab(icon: Icon(Icons.delete_sweep), text: 'المحذوفات'),
          ],
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.deepPurple),
                    SizedBox(height: 16),
                    Text('جاري تحميل البيانات...'),
                  ],
                ),
              )
              : TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildCategoriesManagement(),
                  _buildChallengesOnlyTab(),
                  _buildUsersManagementTab(),
                  _buildDeletedQuestionsTab(),
                ],
              ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ترحيب
            _buildWelcomeCard(),
            const SizedBox(height: 20),

            // إحصائيات سريعة
            _buildQuickStats(),
            const SizedBox(height: 20),

            // توزيع الفئات
            _buildCategoriesChart(),
            const SizedBox(height: 20),

            // الأعمال السريعة
            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final user = _authService.currentUser;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade400, Colors.deepPurple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً ${user?.username}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user?.roleDisplayName ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'أهلاً بك في لوحة إدارة لعبة التحدي والمخاطرة',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      children: [
        // الصف الأول - الأسئلة والمستخدمين
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي الأسئلة',
                value: '${_questionsStats['total_questions'] ?? 0}',
                icon: Icons.quiz,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'إجمالي التحديات',
                value: '${_challengesStats['total_challenges'] ?? 0}',
                icon: Icons.sports_kabaddi,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // الصف الثاني - الاستخدام والمستخدمين
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'مرات الاستخدام',
                value:
                    '${(_questionsStats['total_usage'] ?? 0) + (_challengesStats['total_usage'] ?? 0)}',
                icon: Icons.trending_up,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                title: 'المستخدمين',
                value: '${_users.length}',
                icon: Icons.people,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesChart() {
    final categories =
        _questionsStats['categories'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text(
                'توزيع الأسئلة حسب الفئات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (categories.isEmpty)
            const Center(child: Text('لا توجد فئات متاحة'))
          else
            ...categories.entries.map((entry) {
              final total = categories.values.fold(
                0,
                (sum, value) => sum + (value as int),
              );
              final percentage =
                  total > 0 ? ((entry.value as int) / total * 100).round() : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(entry.key)),
                    Expanded(
                      flex: 5,
                      child: LinearProgressIndicator(
                        value: total > 0 ? (entry.value as int) / total : 0,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.deepPurple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.value} ($percentage%)'),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.flash_on, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text(
                'الأعمال السريعة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // الصف الأول - إضافة سؤال وإضافة تحدي
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddQuestionDialog,
                  icon: const Icon(Icons.quiz),
                  label: const Text('إضافة سؤال'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAddChallengeDialog,
                  icon: const Icon(Icons.sports_kabaddi),
                  label: const Text('إضافة تحدي'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // الصف الثاني - رفع الأسئلة والتحديات
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploadQuestions,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('رفع الأسئلة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploadChallenges,
                  icon: const Icon(Icons.upload),
                  label: const Text('رفع التحديات'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChallengesOnlyTab() {
    // فلترة التحديات حسب البحث
    final searchText = _challengeSearchController.text.toLowerCase();
    final filteredChallenges =
        _challenges.where((challenge) {
          if (searchText.isEmpty) return true;
          final challengeText =
              (challenge['challenge'] ?? '').toString().toLowerCase();
          final category =
              (challenge['category'] ?? '').toString().toLowerCase();
          final difficulty =
              (challenge['difficulty'] ?? '').toString().toLowerCase();

          return challengeText.contains(searchText) ||
              category.contains(searchText) ||
              difficulty.contains(searchText);
        }).toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // شريط الإجراءات العلوي
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                children: [
                  // الصف الأول - العنوان والأيقونات
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'إدارة التحديات',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            Text(
                              'عرض ${filteredChallenges.length} من أصل ${_challenges.length} تحدي',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // أيقون رفع التحديات
                      IconButton(
                        onPressed: _uploadChallenges,
                        icon: const Icon(Icons.upload),
                        tooltip: 'رفع التحديات',
                        color: Colors.blue,
                      ),
                      IconButton(
                        onPressed: () => _loadData(),
                        icon: const Icon(Icons.refresh),
                        tooltip: 'تحديث',
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // الصف الثاني - شريط البحث
                  TextField(
                    controller: _challengeSearchController,
                    decoration: InputDecoration(
                      hintText: 'البحث في التحديات...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.deepPurple,
                      ),
                      suffixIcon:
                          _challengeSearchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _challengeSearchController.clear();
                                  });
                                },
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.deepPurple),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        // تحديث واجهة المستخدم عند تغيير النص
                      });
                    },
                  ),
                ],
              ),
            ),

            // قائمة التحديات
            Expanded(
              child:
                  filteredChallenges.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _challengeSearchController.text.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.sports_kabaddi_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _challengeSearchController.text.isNotEmpty
                                  ? 'لا توجد تحديات تطابق البحث "${_challengeSearchController.text}"'
                                  : 'لا توجد تحديات متاحة',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_challengeSearchController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _challengeSearchController.clear();
                                  });
                                },
                                child: const Text('مسح البحث'),
                              ),
                            ],
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredChallenges.length,
                        itemBuilder: (context, index) {
                          final challenge = filteredChallenges[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getDifficultyColor(
                                  challenge['difficulty'] ?? 'متوسط',
                                ).withOpacity(0.2),
                                child: Icon(
                                  _getDifficultyIcon(
                                    challenge['difficulty'] ?? 'متوسط',
                                  ),
                                  color: _getDifficultyColor(
                                    challenge['difficulty'] ?? 'متوسط',
                                  ),
                                ),
                              ),
                              title: Text(
                                challenge['challenge'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الفئة: ${challenge['category'] ?? 'غير محدد'}',
                                  ),
                                  Row(
                                    children: [
                                      Text('الصعوبة: '),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getDifficultyColor(
                                            challenge['difficulty'] ?? 'متوسط',
                                          ).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          challenge['difficulty'] ?? 'متوسط',
                                          style: TextStyle(
                                            color: _getDifficultyColor(
                                              challenge['difficulty'] ??
                                                  'متوسط',
                                            ),
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if ((challenge['usage_count'] ?? 0) > 0)
                                    Text(
                                      'مرات الاستخدام: ${challenge['usage_count']}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.blue,
                                    ),
                                    onPressed: () => _editChallenge(challenge),
                                    tooltip: 'تحرير التحدي',
                                  ),
                                  if (_authService.currentUser
                                          ?.canDeleteQuestions() ==
                                      true)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () => _deleteChallenge(challenge),
                                      tooltip: 'حذف التحدي',
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddChallengeDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة تحدي'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        heroTag: "add_challenge_fab",
      ),
    );
  }

  Widget _buildUsersManagementTab() {
    // حساب الإحصائيات
    final adminCount =
        _users.where((user) => user.role == UserRole.admin).length;
    final userCount = _users.where((user) => user.role == UserRole.user).length;
    final totalUsers = _users.length;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس القسم
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إدارة المستخدمين',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'إجمالي المستخدمين: $totalUsers',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // الإحصائيات
            Row(
              children: [
                Expanded(
                  child: _buildUserStatCard(
                    title: 'المشرفين',
                    value: '$adminCount',
                    icon: Icons.admin_panel_settings,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUserStatCard(
                    title: 'المستخدمين',
                    value: '$userCount',
                    icon: Icons.person,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUserStatCard(
                    title: 'المجموع',
                    value: '$totalUsers',
                    icon: Icons.people,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // قائمة المستخدمين
            const Text(
              'قائمة المستخدمين',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),

            if (_users.isEmpty)
              const Center(
                child: Text(
                  'لا توجد مستخدمين مسجلين',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _users.length,
                itemBuilder: (context, index) {
                  final user = _users[index];
                  return _buildUserCard(user);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildUserCard(AppUser user) {
    final isAdmin = user.role == UserRole.admin;
    final registrationDate = _formatDate(user.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin ? Colors.red.shade100 : Colors.blue.shade100,
          child: Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: isAdmin ? Colors.red : Colors.blue,
          ),
        ),
        title: Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isAdmin ? Colors.red.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.roleDisplayName,
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isAdmin ? Colors.red.shade800 : Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.circle, color: Colors.green, size: 8),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'الإيميل: ${user.email}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'التسجيل: $registrationDate',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'delete':
                _showDeleteUserDialog(user);
                break;
              case 'details':
                _showUserDetailsDialog(user);
                break;
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('تفاصيل'),
                    ],
                  ),
                ),
                if (user.role != UserRole.admin || _canDeleteAdmin())
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف'),
                      ],
                    ),
                  ),
              ],
        ),
      ),
    );
  }

  bool _canDeleteAdmin() {
    // يمكن حذف المشرف فقط إذا كان هناك أكثر من مشرف واحد
    final adminCount =
        _users.where((user) => user.role == UserRole.admin).length;
    return adminCount > 1;
  }

  void _showUserDetailsDialog(AppUser user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  user.role == UserRole.admin
                      ? Icons.admin_panel_settings
                      : Icons.person,
                  color: user.role == UserRole.admin ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text('تفاصيل المستخدم'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('اسم المستخدم:', user.username),
                _buildDetailRow('البريد الإلكتروني:', user.email),
                _buildDetailRow('الدور:', user.roleDisplayName),
                _buildDetailRow(
                  'تاريخ التسجيل:',
                  _formatFullDate(user.createdAt),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime? date) {
    if (date == null) return 'غير محدد';
    return '${date.day}/${date.month}/${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteUserDialog(AppUser user) {
    final isAdmin = user.role == UserRole.admin;
    final currentUser = _authService.currentUser;

    // منع المستخدم من حذف نفسه
    if (currentUser?.id == user.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ لا يمكنك حذف حسابك الخاص'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text('تأكيد الحذف'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل أنت متأكد من حذف المستخدم "${user.username}"؟',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text('سيتم حذف:'),
                Text('• حساب المستخدم'),
                Text('• جميع بيانات المستخدم'),
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تحذير: هذا المستخدم مشرف في النظام!',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'هذا الإجراء لا يمكن التراجع عنه.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteUser(user);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حذف المستخدم'),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteUser(AppUser user) async {
    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('جاري حذف المستخدم...'),
              ],
            ),
          ),
    );

    try {
      final success = await _authService.deleteUser(user.id);
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم حذف المستخدم "${user.username}" بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData(); // إعادة تحميل البيانات
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في حذف المستخدم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في حذف المستخدم: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير محدد';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'اليوم';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else if (difference.inDays < 30) {
      return 'منذ ${(difference.inDays / 7).floor()} أسابيع';
    } else if (difference.inDays < 365) {
      return 'منذ ${(difference.inDays / 30).floor()} شهور';
    } else {
      return 'منذ ${(difference.inDays / 365).floor()} سنة';
    }
  }

  Widget _buildDeletedQuestionsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // شريط التبويبات مع تقليل المساحة
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: TabBar(
              labelColor: Colors.deepPurple,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.deepPurple,
              indicatorWeight: 2,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(vertical: 8),
              tabs: [
                Tab(
                  icon: Icon(Icons.quiz_outlined, size: 20),
                  text: 'الأسئلة المحذوفة (${_deletedQuestions.length})',
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.sports_kabaddi_outlined, size: 20),
                  text: 'التحديات المحذوفة (${_deletedChallenges.length})',
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),

          // المحتوى مع إزالة المساحة الزائدة
          Expanded(
            child: TabBarView(
              children: [
                _buildDeletedQuestionsSubTab(),
                _buildDeletedChallengesSubTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedQuestionsSubTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // شريط الإجراءات العلوي مع تقليل المساحة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'إدارة الأسئلة المحذوفة (${_deletedQuestions.length} سؤال)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _loadData(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث',
                ),
              ],
            ),
          ),

          // قائمة الأسئلة المحذوفة
          Expanded(
            child:
                _deletedQuestions.isEmpty
                    ? const Center(
                      child: Text(
                        'لا توجد أسئلة محذوفة',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(
                        12,
                      ), // تقليل المساحة من 16 إلى 12
                      itemCount: _deletedQuestions.length,
                      itemBuilder: (context, index) {
                        final question = _deletedQuestions[index];
                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: 8,
                          ), // تقليل المساحة من 12 إلى 8
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.withOpacity(0.2),
                              child: Icon(
                                Icons.quiz_outlined,
                                color: Colors.red,
                              ),
                            ),
                            title: Text(
                              question['question_text'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تاريخ الحذف: ${_formatDate((question['deleted_at'] as Timestamp?)?.toDate())}',
                                ),
                                Text(
                                  'محذوف بواسطة: ${question['deleted_by'] ?? 'غير محدد'}',
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.restore,
                                color: Colors.green,
                              ),
                              onPressed: () => _restoreQuestion(question),
                              tooltip:
                                  question['has_original_data'] == true
                                      ? 'إستعادة السؤال (استعادة كاملة)'
                                      : 'إستعادة السؤال (قد تفقد بعض البيانات)',
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeletedChallengesSubTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Column(
        children: [
          // شريط الإجراءات العلوي مع تقليل المساحة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'إدارة التحديات المحذوفة (${_deletedChallenges.length} تحدي)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _loadData(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث',
                ),
              ],
            ),
          ),

          // قائمة التحديات المحذوفة
          Expanded(
            child:
                _deletedChallenges.isEmpty
                    ? const Center(
                      child: Text(
                        'لا توجد تحديات محذوفة',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(
                        12,
                      ), // تقليل المساحة من 16 إلى 12
                      itemCount: _deletedChallenges.length,
                      itemBuilder: (context, index) {
                        final challenge = _deletedChallenges[index];
                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: 8,
                          ), // تقليل المساحة من 12 إلى 8
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              child: Icon(
                                Icons.sports_kabaddi_outlined,
                                color: Colors.orange,
                              ),
                            ),
                            title: Text(
                              challenge['challenge_text'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'تاريخ الحذف: ${_formatDate((challenge['deleted_at'] as Timestamp?)?.toDate())}',
                                ),
                                Text(
                                  'محذوف بواسطة: ${challenge['deleted_by'] ?? 'غير محدد'}',
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.restore,
                                color: Colors.green,
                              ),
                              onPressed: () => _restoreChallenge(challenge),
                              tooltip:
                                  challenge['has_original_data'] == true
                                      ? 'إستعادة التحدي (استعادة كاملة)'
                                      : 'إستعادة التحدي (قد تفقد بعض البيانات)',
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreQuestion(Map<String, dynamic> question) async {
    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('جاري إستعادة السؤال...'),
              ],
            ),
          ),
    );

    try {
      final success = await _firebaseService.restoreDeletedQuestion(
        question['question_text'],
      );
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        // عرض رسالة نجاح بسيطة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم استعادة السؤال وإضافته إلى الفئة الصحيحة'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        await _loadData(); // إعادة تحميل البيانات
      } else {
        // عرض رسالة فشل بسيطة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ فشل في استعادة السؤال - قد يكون موجود مسبقاً'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في إستعادة السؤال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restoreChallenge(Map<String, dynamic> challenge) async {
    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('جاري إستعادة التحدي...'),
              ],
            ),
          ),
    );

    try {
      final success = await _firebaseService.restoreDeletedChallenge(
        challenge['challenge_text'],
      );
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        // عرض رسالة نجاح مفصلة
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('تم استعادة التحدي بنجاح'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('✅ تم استعادة التحدي وإضافته إلى الفئة الصحيحة'),
                    const SizedBox(height: 8),
                    Text(
                      '📂 يمكنك الآن العثور على التحدي في قائمة التحديات العادية',
                    ),
                    const SizedBox(height: 8),
                    Text('🔄 قم بتحديث الصفحة لرؤية التغييرات'),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('موافق'),
                  ),
                ],
              ),
        );
        await _loadData(); // إعادة تحميل البيانات
      } else {
        // تحسين رسالة الفشل لتوضح الأسباب المحتملة
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text('فشل في استعادة التحدي'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'لم يتم استعادة التحدي للأسباب التالية:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text('• التحدي موجود مسبقاً في قائمة التحديات العادية'),
                    const SizedBox(height: 8),
                    Text('• البيانات الأصلية للتحدي قد تكون تالفة أو مفقودة'),
                    const SizedBox(height: 8),
                    Text('• مشكلة في الاتصال بقاعدة البيانات'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 اقتراحات الحل:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• تحقق من تبويب "التحديات" للتأكد من عدم وجود التحدي',
                          ),
                          Text('• حاول إعادة المحاولة بعد تحديث الصفحة'),
                          Text(
                            '• إذا استمرت المشكلة، قم بحذف التحدي من المحذوفات',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadData(); // إعادة تحميل البيانات للتحقق
                    },
                    child: const Text('تحديث البيانات'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في إستعادة التحدي: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===== دوال مساعدة للتحديات =====

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'سهل':
        return Colors.green;
      case 'متوسط':
        return Colors.orange;
      case 'صعب':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  IconData _getDifficultyIcon(String difficulty) {
    switch (difficulty) {
      case 'سهل':
        return Icons.sentiment_satisfied;
      case 'متوسط':
        return Icons.sentiment_neutral;
      case 'صعب':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }

  // ===== إدارة التحديات =====

  void _showAddChallengeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AddChallengeDialog(
            categories: _categories,
            onChallengeAdded: () {
              _loadData();
              Navigator.of(context).pop();
            },
          ),
    );
  }

  void _editChallenge(Map<String, dynamic> challenge) {
    showDialog(
      context: context,
      builder:
          (context) => EditChallengeDialog(
            challenge: challenge,
            categories: _categories,
            onChallengeUpdated: () {
              _loadData();
              Navigator.of(context).pop();
            },
          ),
    );
  }

  void _deleteChallenge(Map<String, dynamic> challenge) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text('تأكيد حذف التحدي'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل أنت متأكد من حذف هذا التحدي؟',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    challenge['challenge'] ?? '',
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text('الفئة: ${challenge['category'] ?? 'غير محدد'}'),
                Text('الصعوبة: ${challenge['difficulty'] ?? 'متوسط'}'),
                const SizedBox(height: 8),
                const Text(
                  'هذا الإجراء لا يمكن التراجع عنه.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _performDeleteChallenge(challenge);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حذف التحدي'),
              ),
            ],
          ),
    );
  }

  Future<void> _performDeleteChallenge(Map<String, dynamic> challenge) async {
    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('جاري حذف التحدي...'),
              ],
            ),
          ),
    );

    try {
      final success = await _firebaseService.deleteChallenge(
        challenge['id'] ?? '',
      );
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف التحدي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData(); // إعادة تحميل البيانات
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في حذف التحدي'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في حذف التحدي: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadChallenges() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('رفع التحديات'),
            content: const Text(
              'هل تريد رفع التحديات المحلية إلى Firebase？\nهذه العملية قد تستغرق بعض الوقت.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('رفع'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('جاري رفع التحديات...'),
              ],
            ),
          ),
    );

    try {
      final result = await _firebaseService.uploadLocalChallengesToFirebase();
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (result) {
        await _loadData();
        // عرض رسالة نجاح بسيطة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم رفع التحديات الجديدة بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // عرض رسالة فشل بسيطة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 لم يتم العثور على تحديات جديدة لرفعها'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      // عرض رسالة خطأ بسيطة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ خطأ في رفع التحديات: ${e.toString().substring(0, 50)}...',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () => _uploadChallenges(),
          ),
        ),
      );
    }
  }

  void _showUserProfile() {
    final user = _authService.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('الملف الشخصي'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اسم المستخدم: ${user.username}'),
                Text('البريد الإلكتروني: ${user.email}'),
                Text('الدور: ${user.roleDisplayName}'),
                Text(
                  'تاريخ الإنشاء: ${user.createdAt.toString().split(' ')[0]}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
    );
  }

  Widget _buildCategoriesManagement() {
    return RefreshIndicator(
      onRefresh: () async => _loadCategories(),
      child: Column(
        children: [
          // شريط البحث والإجراءات
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddCategoryDialog(),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة فئة جديدة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _loadCategories(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'تحديث',
                ),
              ],
            ),
          ),

          // قائمة الفئات
          Expanded(
            child:
                _isLoadingCategories
                    ? const Center(child: CircularProgressIndicator())
                    : _categories.isEmpty
                    ? const Center(
                      child: Text(
                        'لا توجد فئات متاحة',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return _buildCategoryCard(category);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final isCustom = category['is_custom'] as bool;
    final questionsCount = category['questions_count'] as int;
    final categoryName = category['name'] as String;
    final description = category['description'] as String;
    final iconName = category['icon'] as String;
    final colorValue = category['color'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Color(colorValue).withOpacity(0.2),
          child: Icon(_getIconData(iconName), color: Color(colorValue)),
        ),
        title: Text(
          categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.quiz, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '$questionsCount سؤال',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isCustom
                            ? Colors.orange.shade100
                            : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCustom ? 'مخصصة' : 'أساسية',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isCustom
                              ? Colors.orange.shade800
                              : Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // أزرار الإجراءات
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _viewCategoryQuestions(categoryName),
                      icon: const Icon(Icons.list, size: 16),
                      label: const Text('عرض الأسئلة'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    if (isCustom) ...[
                      ElevatedButton.icon(
                        onPressed: () => _showEditCategoryDialog(category),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('تعديل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _deleteCategoryConfirm(category),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('حذف'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'info':
        return Icons.info;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'mosque':
        return Icons.mosque;
      case 'movie':
        return Icons.movie;
      case 'computer':
        return Icons.computer;
      case 'psychology':
        return Icons.psychology;
      case 'science':
        return Icons.science;
      case 'library_books':
        return Icons.library_books;
      case 'category':
        return Icons.category;
      default:
        return Icons.help_outline;
    }
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AddCategoryDialog(
            onCategoryAdded: () {
              _loadCategories();
              Navigator.of(context).pop();
            },
          ),
    );
  }

  void _showEditCategoryDialog(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder:
          (context) => EditCategoryDialog(
            category: category,
            onCategoryUpdated: () {
              _loadCategories();
              Navigator.of(context).pop();
            },
          ),
    );
  }

  void _deleteCategoryConfirm(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف فئة "${category['name']}"؟\n\nسيتم نقل جميع الأسئلة في هذه الفئة إلى فئة "معلومات عامة".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteCategory(category['id']);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteCategory(String categoryId) async {
    try {
      final success = await _firebaseService.deleteCustomCategory(categoryId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف الفئة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadCategories();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في حذف الفئة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في حذف الفئة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewCategoryQuestions(String categoryName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (context) => CategoryQuestionsScreen(
              categoryName: categoryName,
              onRefresh: _loadData,
              categories: _categories,
            ),
      ),
    );
  }

  void _showAddQuestionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AddQuestionDialog(
            categories: _categories,
            onQuestionAdded: () {
              _loadData();
              Navigator.of(context).pop();
            },
          ),
    );
  }

  Future<void> _uploadQuestions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('رفع الأسئلة'),
            content: const Text(
              'هل تريد رفع الأسئلة المحلية إلى Firebase؟\nهذه العملية قد تستغرق بعض الوقت.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('رفع'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    // عرض مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('جاري رفع الأسئلة...'),
              ],
            ),
          ),
    );

    try {
      final result = await _firebaseService.uploadLocalQuestionsToFirebase();
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (result) {
        await _loadData();
        // عرض رسالة نجاح بسيطة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم رفع الأسئلة الجديدة بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        // عرض رسالة فشل بسيطة
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 لم يتم العثور على أسئلة جديدة لرفعها'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      // عرض رسالة خطأ بسيطة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ خطأ في رفع الأسئلة: ${e.toString().substring(0, 50)}...',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            textColor: Colors.white,
            onPressed: () => _uploadQuestions(),
          ),
        ),
      );
    }
  }
}
