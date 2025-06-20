import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/question.dart';
import '../services/firebase_service.dart';
import '../utils/join_room_test.dart';
import '../utils/quick_join_test.dart';
import 'online_lobby_screen.dart';

class RoomSettingsScreen extends StatefulWidget {
  final String playerName;

  const RoomSettingsScreen({super.key, required this.playerName});

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  // إعدادات الغرفة
  String selectedCategory = 'جميع الفئات';
  int numberOfQuestions = 10;
  int maxPlayers = 4;
  bool isLoading = false;
  List<String> availableCategories = [];
  List<Question> allQuestions = [];

  // خيارات عدد الأسئلة
  final List<int> _questionCounts = [10, 15, 20];
  int _selectedQuestionCount = 10;

  // خيارات عدد اللاعبين
  final List<int> _maxPlayersOptions = [2, 3, 4, 5, 6, 7, 8];
  int _selectedMaxPlayers = 4;

  // الفئات المتاحة مع بياناتها
  final List<CategoryData> _categories = [
    CategoryData('جميع الفئات', Icons.all_inclusive, true),
    CategoryData('معلومات عامة', Icons.info, false),
    CategoryData('رياضة', Icons.sports_soccer, false),
    CategoryData('ديني', Icons.mosque, false),
    CategoryData('ترفيه', Icons.movie, false),
    CategoryData('تكنولوجيا', Icons.computer, false),
    CategoryData('ألغاز منطقية', Icons.psychology, false),
    CategoryData('علوم', Icons.science, false),
    CategoryData('ثقافة', Icons.library_books, false),
  ];

  // قائمة الفئات المختارة
  List<String> _selectedCategories = ['جميع الفئات'];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/questions.json',
      );
      final List<dynamic> data = json.decode(response);
      allQuestions = data.map((json) => Question.fromJson(json)).toList();

      setState(() {
        availableCategories = _categories.map((cat) => cat.name).toList();
      });
    } catch (e) {
      print('خطأ في تحميل الأسئلة: $e');
    }
  }

  void _createRoom() async {
    setState(() => isLoading = true);

    try {
      final room = await _firebaseService.createRoom(
        widget.playerName,
        _selectedMaxPlayers,
        questionsCount: _selectedQuestionCount,
      );

      if (room != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => OnlineLobbyScreen(
                  roomCode: room.id,
                  playerName: widget.playerName,
                  isHost: true,
                ),
          ),
        );
      } else {
        _showErrorDialog('فشل في إنشاء الغرفة');
      }
    } catch (e) {
      _showErrorDialog('حدث خطأ أثناء إنشاء الغرفة: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _testConnection() async {
    // إظهار رسالة اختبار الاتصال
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('الاتصال جيد ✓'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _testJoinRoom() async {
    // إظهار نافذة إدخال بيانات الاختبار
    await showDialog(
      context: context,
      builder: (context) => _JoinRoomTestDialog(),
    );
  }

  void _listAvailableRooms() async {
    setState(() => isLoading = true);

    try {
      final result = await JoinRoomTest.listAvailableRooms();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _AvailableRoomsDialog(result: result),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _createTestRoom() async {
    setState(() => isLoading = true);

    try {
      final roomCode = await JoinRoomTest.createTestRoom();

      if (mounted) {
        if (roomCode != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم إنشاء غرفة تجريبية: $roomCode'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'نسخ',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: roomCode));
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ فشل في إنشاء غرفة تجريبية'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _runFullTest() async {
    setState(() => isLoading = true);

    try {
      // تشغيل الاختبار الشامل في الخلفية وإظهار النتائج
      await QuickJoinTest.fullTest();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ تم تشغيل الاختبار الشامل - تحقق من وحدة التحكم للتفاصيل',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل الاختبار الشامل: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _toggleCategory(String categoryName) {
    setState(() {
      if (categoryName == 'جميع الفئات') {
        // إذا اختار "جميع الفئات"، اختر هذه الفئة فقط
        _selectedCategories = ['جميع الفئات'];
      } else {
        // إذا كانت "جميع الفئات" مختارة، قم بإزالتها أولاً
        if (_selectedCategories.contains('جميع الفئات')) {
          _selectedCategories.remove('جميع الفئات');
        }

        // تبديل حالة الفئة المختارة
        if (_selectedCategories.contains(categoryName)) {
          _selectedCategories.remove(categoryName);
        } else {
          _selectedCategories.add(categoryName);
        }

        // إذا لم تعد هناك فئات مختارة، اختر "جميع الفئات"
        if (_selectedCategories.isEmpty) {
          _selectedCategories = ['جميع الفئات'];
        }
      }

      // تحديث selectedCategory للتوافق مع باقي الكود
      if (_selectedCategories.contains('جميع الفئات')) {
        selectedCategory = 'جميع الفئات';
      } else {
        selectedCategory = _selectedCategories.first;
      }
    });
  }

  String _getSelectedCategoriesText() {
    if (_selectedCategories.contains('جميع الفئات')) {
      return 'جميع الفئات';
    }
    return _selectedCategories.join('، ');
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade400),
                const SizedBox(width: 10),
                const Text('خطأ'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('موافق'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text(
          'إعدادات الغرفة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body:
          isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.deepPurple),
                    SizedBox(height: 20),
                    Text(
                      'جاري إنشاء الغرفة...',
                      style: TextStyle(fontSize: 16, color: Colors.deepPurple),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome message
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade400,
                            Colors.deepPurple.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withOpacity(0.3),
                            spreadRadius: 3,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.settings,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'مرحباً ${widget.playerName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'اختر إعدادات الغرفة التي تريد إنشاؤها',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Question Categories Selection
                    _buildSectionCard(
                      title: 'فئات الأسئلة',
                      icon: Icons.category,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'اختر فئة أو أكثر للأسئلة (اسحب لليمين لرؤية المزيد)',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            height: 120,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(right: 10),
                              child: Row(
                                children:
                                    _categories.map((category) {
                                      final isSelected = _selectedCategories
                                          .contains(category.name);
                                      return Container(
                                        margin: const EdgeInsets.only(left: 12),
                                        child: _buildCategoryChip(
                                          category: category,
                                          isSelected: isSelected,
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Selected category display
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'الفئات المختارة: ${_getSelectedCategoriesText()}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Question Count Selection
                    _buildSectionCard(
                      title: 'عدد الأسئلة',
                      icon: Icons.quiz,
                      child: Column(
                        children: [
                          const Text(
                            'اختر عدد الأسئلة في اللعبة',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children:
                                _questionCounts.map((count) {
                                  final isSelected =
                                      _selectedQuestionCount == count;
                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: _buildQuestionCountCard(
                                        count,
                                        isSelected,
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Max Players Selection
                    _buildSectionCard(
                      title: 'عدد اللاعبين الأقصى',
                      icon: Icons.group,
                      child: Column(
                        children: [
                          const Text(
                            'اختر العدد الأقصى للاعبين في الغرفة',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            runSpacing: 8,
                            spacing: 8,
                            children:
                                _maxPlayersOptions.map((players) {
                                  final isSelected =
                                      _selectedMaxPlayers == players;
                                  return _buildPlayerCountChip(
                                    players,
                                    isSelected,
                                  );
                                }).toList(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Test Buttons Section
                    _buildSectionCard(
                      title: 'أدوات الاختبار',
                      icon: Icons.bug_report,
                      child: Column(
                        children: [
                          const Text(
                            'أدوات لاختبار وظائف الانضمام للغرف',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            runSpacing: 8,
                            spacing: 8,
                            children: [
                              // Test Join Room Button
                              _buildTestButton(
                                icon: Icons.login,
                                label: 'اختبار الانضمام',
                                color: Colors.purple,
                                onPressed: _testJoinRoom,
                              ),

                              // List Available Rooms Button
                              _buildTestButton(
                                icon: Icons.list,
                                label: 'عرض الغرف',
                                color: Colors.orange,
                                onPressed: _listAvailableRooms,
                              ),

                              // Create Test Room Button
                              _buildTestButton(
                                icon: Icons.science,
                                label: 'غرفة تجريبية',
                                color: Colors.teal,
                                onPressed: _createTestRoom,
                              ),

                              // Full Test Button
                              _buildTestButton(
                                icon: Icons.play_circle,
                                label: 'اختبار شامل',
                                color: Colors.indigo,
                                onPressed: _runFullTest,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Test Connection Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.blue.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _testConnection,
                          borderRadius: BorderRadius.circular(12),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_find,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'اختبار الاتصال',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Create Room Button
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade600,
                          ],
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
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _createRoom,
                          borderRadius: BorderRadius.circular(15),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle,
                                  color: Colors.white,
                                  size: 28,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'إنشاء الغرفة',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'ملخص الإعدادات',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _buildSummaryRow(
                            'فئات الأسئلة',
                            _getSelectedCategoriesText(),
                          ),
                          _buildSummaryRow(
                            'عدد الأسئلة',
                            '$_selectedQuestionCount سؤال',
                          ),
                          _buildSummaryRow(
                            'عدد اللاعبين الأقصى',
                            '$_selectedMaxPlayers لاعبين',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildCategoryChip({
    required CategoryData category,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => _toggleCategory(category.name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isSelected
                    ? category.isSpecial
                        ? [Colors.amber.shade400, Colors.amber.shade600]
                        : [
                          Colors.deepPurple.shade400,
                          Colors.deepPurple.shade600,
                        ]
                    : [Colors.grey.shade200, Colors.grey.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color:
                isSelected
                    ? category.isSpecial
                        ? Colors.amber.shade700
                        : Colors.deepPurple.shade700
                    : Colors.grey.shade400,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: (category.isSpecial
                              ? Colors.amber
                              : Colors.deepPurple)
                          .withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              category.icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCountCard(int count, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedQuestionCount = count),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isSelected
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : [Colors.grey.shade100, Colors.grey.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Column(
          children: [
            Icon(
              Icons.quiz,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'سؤال',
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCountChip(int count, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedMaxPlayers = count),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isSelected
                    ? [Colors.blue.shade400, Colors.blue.shade600]
                    : [Colors.grey.shade100, Colors.grey.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Icon(icon, color: Colors.deepPurple),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 16, color: Colors.blue.shade700),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 140,
      height: 80,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(color, Colors.white, 0.2)!,
              Color.lerp(color, Colors.black, 0.2)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// نوافذ الاختبار
class _JoinRoomTestDialog extends StatefulWidget {
  @override
  State<_JoinRoomTestDialog> createState() => _JoinRoomTestDialogState();
}

class _JoinRoomTestDialogState extends State<_JoinRoomTestDialog> {
  final _roomCodeController = TextEditingController();
  final _playerNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    _playerNameController.dispose();
    super.dispose();
  }

  void _runTest() async {
    if (_roomCodeController.text.trim().isEmpty ||
        _playerNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال جميع البيانات'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await JoinRoomTest.testJoinRoom(
        _roomCodeController.text.trim(),
        _playerNameController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (context) => _TestResultDialog(result: result),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.science, color: Colors.purple),
          SizedBox(width: 10),
          Text('اختبار الانضمام للغرفة'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _roomCodeController,
            decoration: const InputDecoration(
              labelText: 'كود الغرفة',
              hintText: '123456',
              border: OutlineInputBorder(),
            ),
            textAlign: TextAlign.center,
            maxLength: 6,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _playerNameController,
            decoration: const InputDecoration(
              labelText: 'اسم اللاعب',
              hintText: 'اسم تجريبي',
              border: OutlineInputBorder(),
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
          onPressed: _isLoading ? null : _runTest,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('تشغيل الاختبار'),
        ),
      ],
    );
  }
}

class _TestResultDialog extends StatelessWidget {
  final Map<String, dynamic> result;

  const _TestResultDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final steps = result['steps'] as List<dynamic>;
    final isSuccess = result['success'] as bool;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Text(
            isSuccess ? 'نجح الاختبار!' : 'فشل الاختبار',
            style: TextStyle(color: isSuccess ? Colors.green : Colors.red),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isSuccess && result['error'] != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'خطأ: ${result['error']}',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
            ],
            const Text(
              'خطوات الاختبار:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  final step = steps[index] as String;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(step, style: const TextStyle(fontSize: 14)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

class _AvailableRoomsDialog extends StatelessWidget {
  final Map<String, dynamic> result;

  const _AvailableRoomsDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final rooms = result['rooms'] as List<dynamic>;
    final isSuccess = result['success'] as bool;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.list, color: Colors.orange),
          SizedBox(width: 10),
          Text('الغرف المتاحة'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child:
            isSuccess
                ? rooms.isNotEmpty
                    ? ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index] as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.meeting_room),
                            title: Text('غرفة ${room['id']}'),
                            subtitle: Text(
                              'اللاعبين: ${room['playersCount']}/${room['maxPlayers']}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: room['id'].toString()),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم نسخ كود الغرفة'),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    )
                    : const Center(child: Text('لا توجد غرف متاحة'))
                : Center(
                  child: Text(
                    'خطأ: ${result['error']}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}

// كلاس لبيانات الفئات
class CategoryData {
  final String name;
  final IconData icon;
  final bool isSpecial;

  CategoryData(this.name, this.icon, this.isSpecial);
}
