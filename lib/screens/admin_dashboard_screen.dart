import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
import '../widgets/edit_question_dialog.dart';
import 'home_screen.dart';
import 'login_screen.dart';

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

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await _firebaseService.getAllCategories();
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
        MaterialPageRoute(builder: (context) => const LoginScreen()),
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
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.person, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  _showUserProfile();
                  break;
                case 'home':
                  Navigator.push(
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
            Tab(icon: Icon(Icons.dashboard), text: 'لوحة المعلومات'),
            Tab(icon: Icon(Icons.category), text: 'إدارة الفئات'),
            Tab(icon: Icon(Icons.quiz), text: 'إدارة الأسئلة'),
            Tab(icon: Icon(Icons.people), text: 'إدارة المستخدمين'),
            Tab(icon: Icon(Icons.delete_sweep), text: 'العناصر المحذوفة'),
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
                  _buildQuestionsTab(),
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة سؤال'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploadQuestions,
                  icon: const Icon(Icons.upload),
                  label: const Text('رفع الأسئلة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // شريط التبويبات مع تحسين المساحة
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
                  icon: Icon(Icons.quiz, size: 20),
                  text: 'الأسئلة (${_questions.length})',
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.sports_kabaddi, size: 20),
                  text: 'التحديات (${_challenges.length})',
                  iconMargin: const EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),

          // المحتوى
          Expanded(
            child: TabBarView(
              children: [_buildQuestionsSubTab(), _buildChallengesSubTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSubTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // شريط الإجراءات العلوي مع تحسين المساحة
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
                      'إدارة الأسئلة (${_questions.length} سؤال)',
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
                  IconButton(
                    onPressed: _uploadQuestions,
                    icon: const Icon(Icons.upload_file),
                    tooltip: 'رفع الأسئلة من الملف المحلي',
                  ),
                ],
              ),
            ),

            // قائمة الأسئلة
            Expanded(
              child:
                  _questions.isEmpty
                      ? const Center(
                        child: Text(
                          'لا توجد أسئلة متاحة',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final question = _questions[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.withOpacity(0.2),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              title: Text(
                                question.questionText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الفئة: ${question.category ?? 'غير محدد'}',
                                  ),
                                  if (question.usageCount > 0)
                                    Text(
                                      'مرات الاستخدام: ${question.usageCount}',
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
                                    onPressed: () => _editQuestion(question),
                                    tooltip: 'تحرير السؤال',
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
                                          () => _deleteQuestion(question),
                                      tooltip: 'حذف السؤال',
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
        onPressed: _showAddQuestionDialog,
        icon: const Icon(Icons.add),
        label: const Text('إضافة سؤال'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        heroTag: "add_question_fab",
      ),
    );
  }

  Widget _buildChallengesSubTab() {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: Column(
          children: [
            // شريط الإجراءات العلوي مع تحسين المساحة
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
                      'إدارة التحديات (${_challenges.length} تحدي)',
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
                  IconButton(
                    onPressed: _uploadChallenges,
                    icon: const Icon(Icons.upload_file),
                    tooltip: 'رفع التحديات من الملف المحلي',
                  ),
                ],
              ),
            ),

            // قائمة التحديات
            Expanded(
              child:
                  _challenges.isEmpty
                      ? const Center(
                        child: Text(
                          'لا توجد تحديات متاحة',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _challenges.length,
                        itemBuilder: (context, index) {
                          final challenge = _challenges[index];
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
                const SizedBox(height: 12),
                // إحصائيات الفئة
                FutureBuilder<Map<String, dynamic>>(
                  future: _firebaseService.getCategoryDetailedStats(
                    categoryName,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 40,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Text('لا توجد إحصائيات');
                    }

                    final stats = snapshot.data!;
                    return _buildCategoryStats(stats);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStats(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'إجمالي الأسئلة',
                '${stats['total_questions']}',
                Icons.quiz,
              ),
              _buildStatItem(
                'مرات الاستخدام',
                '${stats['total_usage']}',
                Icons.play_arrow,
              ),
              _buildStatItem(
                'متوسط الاستخدام',
                '${stats['average_usage']}',
                Icons.analytics,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'غير مستخدمة',
                '${stats['questions_without_usage']}',
                Icons.help_outline,
              ),
              _buildStatItem(
                'من الملف المحلي',
                '${stats['questions_from_local_upload']}',
                Icons.upload_file,
              ),
              _buildStatItem(
                'مضافة يدوياً',
                '${stats['questions_from_manual_add']}',
                Icons.add_circle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
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
            ),
      ),
    );
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
      final success = await _firebaseService.uploadLocalQuestionsToFirebase();
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        _showSuccessSnackBar('تم رفع الأسئلة بنجاح');
        await _loadData();
      } else {
        _showErrorSnackBar('فشل في رفع الأسئلة');
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      _showErrorSnackBar('خطأ في رفع الأسئلة: $e');
    }
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

  void _editQuestion(Question question) {
    showDialog(
      context: context,
      builder:
          (context) => EditQuestionDialog(
            question: question,
            categories: _categories,
            onQuestionUpdated: () {
              _loadData();
              Navigator.of(context).pop();
            },
          ),
    );
  }

  void _deleteQuestion(Question question) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                Text('تأكيد حذف السؤال'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'هل أنت متأكد من حذف هذا السؤال؟',
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
                    question.questionText,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Text('الفئة: ${question.category}'),
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
                  _performDeleteQuestion(question);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('حذف السؤال'),
              ),
            ],
          ),
    );
  }

  Future<void> _performDeleteQuestion(Question question) async {
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
                Text('جاري حذف السؤال...'),
              ],
            ),
          ),
    );

    try {
      final success = await _firebaseService.deleteQuestion(question.id ?? '');
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف السؤال بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData(); // إعادة تحميل البيانات
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في حذف السؤال'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في حذف السؤال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                child: const Text('حذف'),
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
                              tooltip: 'إستعادة السؤال',
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
                              tooltip: 'إستعادة التحدي',
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إستعادة السؤال بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData(); // إعادة تحميل البيانات
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في إستعادة السؤال'),
            backgroundColor: Colors.red,
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
        challenge['challenge'],
      );
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم إستعادة التحدي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadData(); // إعادة تحميل البيانات
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في إستعادة التحدي'),
            backgroundColor: Colors.red,
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
              'هل تريد رفع التحديات المحلية إلى Firebase؟\nهذه العملية قد تستغرق بعض الوقت.',
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
      final success = await _firebaseService.uploadLocalChallengesToFirebase();
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (success) {
        _showSuccessSnackBar('تم رفع التحديات بنجاح');
        await _loadData();
      } else {
        _showErrorSnackBar('فشل في رفع التحديات');
      }
    } catch (e) {
      Navigator.pop(context); // إغلاق مؤشر التحميل
      _showErrorSnackBar('خطأ في رفع التحديات: $e');
    }
  }
}
