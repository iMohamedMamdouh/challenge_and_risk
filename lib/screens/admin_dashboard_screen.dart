import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../widgets/add_category_dialog.dart';
import '../widgets/category_questions_screen.dart';
import '../widgets/edit_category_dialog.dart';
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
  List<AppUser> _users = [];
  List<Question> _questions = [];

  // بيانات الفئات
  List<Map<String, dynamic>> _categories = [];
  bool _isLoadingCategories = true;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        _authService.getUsers(),
        _firebaseService.loadQuestionsFromFirebase(count: 50),
      ]);

      setState(() {
        _questionsStats = futures[0] as Map<String, dynamic>;
        _users = futures[1] as List<AppUser>;
        _questions = futures[2] as List<Question>;
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
            Tab(icon: Icon(Icons.add), text: 'إضافة سؤال'),
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
                  _buildAddQuestionTab(),
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
    return Row(
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
            title: 'مرات الاستخدام',
            value: '${_questionsStats['total_usage'] ?? 0}',
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
            color: Colors.orange,
          ),
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
          const TabBar(
            labelColor: Colors.deepPurple,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.deepPurple,
            tabs: [Tab(text: 'إضافة سؤال جديد'), Tab(text: 'عرض الأسئلة')],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildAddQuestionForm(), _buildQuestionsListView()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddQuestionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: QuestionAddForm(
            onQuestionAdded: _loadData,
            categories: _categories,
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionsListView() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _questions.length,
        itemBuilder: (context, index) {
          final question = _questions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                question.questionText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الفئة: ${question.category}'),
                  Text(
                    'الإجابة الصحيحة: ${question.options[question.correctAnswerIndex]}',
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editQuestion(question),
                  ),
                  if (_authService.currentUser?.canDeleteQuestions() == true)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteQuestion(question),
                    ),
                ],
              ),
            ),
          );
        },
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

  void _editQuestion(Question question) {
    // TODO: تنفيذ تحرير السؤال
    _showErrorSnackBar('ميزة تحرير الأسئلة قيد التطوير');
  }

  void _deleteQuestion(Question question) {
    // TODO: تنفيذ حذف السؤال
    _showErrorSnackBar('ميزة حذف الأسئلة قيد التطوير');
  }

  Widget _buildAddQuestionTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: QuestionAddForm(
        onQuestionAdded: _loadData,
        categories: _categories,
      ),
    );
  }
}

// نموذج إضافة سؤال جديد
class QuestionAddForm extends StatefulWidget {
  final VoidCallback onQuestionAdded;
  final List<Map<String, dynamic>> categories;

  const QuestionAddForm({
    super.key,
    required this.onQuestionAdded,
    required this.categories,
  });

  @override
  State<QuestionAddForm> createState() => _QuestionAddFormState();
}

class _QuestionAddFormState extends State<QuestionAddForm> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _option4Controller = TextEditingController();

  String _selectedCategory = 'معلومات عامة';
  int _correctAnswer = 0;
  bool _isLoading = false;

  final List<String> _categories = [
    'معلومات عامة',
    'رياضة',
    'ديني',
    'ترفيه',
    'تكنولوجيا',
    'ألغاز منطقية',
    'علوم',
    'ثقافة',
  ];

  @override
  void dispose() {
    _questionController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _option4Controller.dispose();
    super.dispose();
  }

  Future<void> _addQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final question = Question(
        questionText: _questionController.text.trim(),
        options: [
          _option1Controller.text.trim(),
          _option2Controller.text.trim(),
          _option3Controller.text.trim(),
          _option4Controller.text.trim(),
        ],
        correctAnswerIndex: _correctAnswer,
        category: _selectedCategory,
      );

      final result = await FirebaseService().addQuestion(question);

      switch (result) {
        case QuestionAddResult.success:
          widget.onQuestionAdded();
          _clearForm();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم إضافة السؤال بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          break;
        case QuestionAddResult.duplicate:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ هذا السؤال موجود مسبقاً في قاعدة البيانات'),
              backgroundColor: Colors.orange,
            ),
          );
          break;
        case QuestionAddResult.error:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ فشل في إضافة السؤال - حدث خطأ'),
              backgroundColor: Colors.red,
            ),
          );
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ غير متوقع: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _questionController.clear();
    _option1Controller.clear();
    _option2Controller.clear();
    _option3Controller.clear();
    _option4Controller.clear();
    setState(() {
      _correctAnswer = 0;
      _selectedCategory = 'معلومات عامة';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إضافة سؤال جديد',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 20),

          // نص السؤال
          TextFormField(
            controller: _questionController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'نص السؤال',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال نص السؤال';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // الخيارات
          ...List.generate(4, (index) {
            final controllers = [
              _option1Controller,
              _option2Controller,
              _option3Controller,
              _option4Controller,
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Radio<int>(
                    value: index,
                    groupValue: _correctAnswer,
                    onChanged: (value) {
                      setState(() => _correctAnswer = value!);
                    },
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: controllers[index],
                      decoration: InputDecoration(
                        labelText: 'الخيار ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'يرجى إدخال الخيار ${index + 1}';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            );
          }),

          // الفئة
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'الفئة',
              border: OutlineInputBorder(),
            ),
            items:
                _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
            onChanged: (value) {
              setState(() => _selectedCategory = value!);
            },
          ),

          const SizedBox(height: 24),

          // أزرار الإجراءات
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Text('إضافة السؤال'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearForm,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('مسح النموذج'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
