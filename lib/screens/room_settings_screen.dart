import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/question.dart';
import '../services/firebase_service.dart';
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

  // خيارات المدة الزمنية (بالثواني)
  final List<int> _timerDurations = [0, 5, 10, 15, 20];
  int _selectedTimerDuration = 10; // المدة بالثواني لكل سؤال

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
        timerDuration: _selectedTimerDuration,
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
                  timerDuration: _selectedTimerDuration, // تمرير إعدادات المؤقت
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

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('خطأ'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('موافق'),
              ),
            ],
          ),
    );
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
    });
  }

  String _getSelectedCategoriesText() {
    if (_selectedCategories.contains('جميع الفئات')) {
      return 'جميع الفئات';
    }
    return _selectedCategories.join('، ');
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

                    // Timer Duration Selection - moved before Max Players
                    _buildSectionCard(
                      title: 'مدة السؤال',
                      icon: Icons.timer,
                      child: Column(
                        children: [
                          const Text(
                            'اختر المدة الزمنية لكل سؤال',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          const SizedBox(height: 15),
                          Wrap(
                            runSpacing: 8,
                            spacing: 8,
                            children:
                                _timerDurations.map((duration) {
                                  final isSelected =
                                      _selectedTimerDuration == duration;
                                  return _buildTimerDurationChip(
                                    duration,
                                    isSelected,
                                  );
                                }).toList(),
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedTimerDuration == 0
                                      ? Icons.timer_off
                                      : Icons.access_time,
                                  color: Colors.orange.shade600,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedTimerDuration == 0
                                        ? 'المدة المختارة: بدون وقت محدد'
                                        : 'المدة المختارة: $_selectedTimerDuration ثانية لكل سؤال',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange.shade800,
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

                    // Max Players Selection - moved after Timer Duration
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
                          _buildSummaryRow(
                            'مدة السؤال',
                            _selectedTimerDuration == 0
                                ? 'بدون وقت'
                                : '$_selectedTimerDuration ثانية',
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

  Widget _buildTimerDurationChip(int duration, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTimerDuration = duration),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isSelected
                    ? [Colors.orange.shade400, Colors.orange.shade600]
                    : [Colors.grey.shade100, Colors.grey.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.orange.shade700 : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
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
              duration == 0 ? Icons.timer_off : Icons.timer,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              duration == 0 ? 'بدون' : '$duration',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (duration > 0) ...[
              const SizedBox(width: 4),
              Text(
                'ث',
                style: TextStyle(
                  color: isSelected ? Colors.white70 : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
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
}

// كلاس لبيانات الفئات
class CategoryData {
  final String name;
  final IconData icon;
  final bool isSpecial;

  CategoryData(this.name, this.icon, this.isSpecial);
}
