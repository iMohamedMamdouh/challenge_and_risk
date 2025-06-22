import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class QuestionsManagementTab extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final VoidCallback onRefresh;

  const QuestionsManagementTab({
    super.key,
    required this.categories,
    required this.onRefresh,
  });

  @override
  State<QuestionsManagementTab> createState() => _QuestionsManagementTabState();
}

class _QuestionsManagementTabState extends State<QuestionsManagementTab> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _allQuestions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'الكل';

  @override
  void initState() {
    super.initState();
    _loadAllQuestions();
  }

  Future<void> _loadAllQuestions() async {
    setState(() => _isLoading = true);
    try {
      // تحميل جميع الأسئلة من جميع الفئات
      final allQuestions = <Map<String, dynamic>>[];

      for (final category in widget.categories) {
        final categoryName = category['name'] as String;
        final questions = await _firebaseService.getQuestionsByCategory(
          categoryName,
        );
        allQuestions.addAll(questions);
      }

      setState(() {
        _allQuestions = allQuestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الأسئلة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredQuestions {
    var questions = _allQuestions;

    // تصفية حسب الفئة
    if (_selectedCategory != 'الكل') {
      questions =
          questions.where((question) {
            return question['category'] == _selectedCategory;
          }).toList();
    }

    // تصفية حسب البحث
    if (_searchQuery.isNotEmpty) {
      questions =
          questions.where((question) {
            final questionText = (question['question'] as String).toLowerCase();
            final searchLower = _searchQuery.toLowerCase();
            return questionText.contains(searchLower);
          }).toList();
    }

    return questions;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // شريط البحث والتصفية
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            children: [
              // شريط البحث
              TextField(
                decoration: InputDecoration(
                  hintText: 'البحث في الأسئلة...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
              const SizedBox(height: 12),

              // مرشح الفئات
              Row(
                children: [
                  const Text(
                    'الفئة: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'الكل',
                          child: Text('جميع الفئات'),
                        ),
                        ...widget.categories.map((category) {
                          final categoryName = category['name'] as String;
                          return DropdownMenuItem(
                            value: categoryName,
                            child: Text(categoryName),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategory = value ?? 'الكل');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      _loadAllQuestions();
                      widget.onRefresh();
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: 'تحديث',
                  ),
                ],
              ),
            ],
          ),
        ),

        // إحصائيات
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'إجمالي الأسئلة',
                '${_allQuestions.length}',
                Icons.quiz,
                Colors.blue,
              ),
              _buildStatCard(
                'النتائج',
                '${_filteredQuestions.length}',
                Icons.search,
                Colors.green,
              ),
              _buildStatCard(
                'الفئات',
                '${widget.categories.length}',
                Icons.category,
                Colors.purple,
              ),
            ],
          ),
        ),

        // قائمة الأسئلة
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredQuestions.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty && _selectedCategory == 'الكل'
                              ? Icons.quiz_outlined
                              : Icons.search_off,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty && _selectedCategory == 'الكل'
                              ? 'لا توجد أسئلة'
                              : 'لا توجد نتائج للبحث أو التصفية',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'جرب تغيير معايير البحث أو إضافة أسئلة جديدة',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                  : RefreshIndicator(
                    onRefresh: _loadAllQuestions,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredQuestions.length,
                      itemBuilder: (context, index) {
                        final question = _filteredQuestions[index];
                        return _buildQuestionCard(question, index + 1);
                      },
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final questionText = question['question'] as String;
    final category = question['category'] as String;
    final usageCount = question['usage_count'] as int? ?? 0;
    final source = question['source'] as String? ?? 'unknown';

    // العثور على لون الفئة
    final categoryData = widget.categories.firstWhere(
      (cat) => cat['name'] == category,
      orElse: () => {'color': 0xFF9C27B0},
    );
    final categoryColor = Color(categoryData['color'] as int);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: categoryColor.withOpacity(0.2),
          child: Text(
            '$index',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: categoryColor,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          questionText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 10,
                      color: categoryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getSourceColor(source).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getSourceLabel(source),
                    style: TextStyle(
                      fontSize: 9,
                      color: _getSourceColor(source),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.play_arrow, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  'استُخدم $usageCount مرة',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'view':
                _viewQuestionDetails(question);
                break;
              case 'edit':
                _editQuestion(question);
                break;
              case 'delete':
                _deleteQuestionConfirm(question);
                break;
            }
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 16),
                      SizedBox(width: 8),
                      Text('عرض التفاصيل'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('تعديل'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
        ),
        onTap: () => _viewQuestionDetails(question),
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'local_upload':
        return Colors.blue;
      case 'manual_add':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getSourceLabel(String source) {
    switch (source) {
      case 'local_upload':
        return 'ملف';
      case 'manual_add':
        return 'يدوي';
      default:
        return 'غير محدد';
    }
  }

  void _viewQuestionDetails(Map<String, dynamic> question) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تفاصيل السؤال'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'السؤال:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(question['question'] as String),
                  const SizedBox(height: 16),

                  Text(
                    'الخيارات:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...List<String>.from(
                    question['options'] ?? [],
                  ).asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isCorrect =
                        index == (question['correct_answer'] as int);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green.withOpacity(0.1) : null,
                        border: Border.all(
                          color:
                              isCorrect ? Colors.green : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${String.fromCharCode(65 + index)}. ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? Colors.green : null,
                            ),
                          ),
                          Expanded(child: Text(option)),
                          if (isCorrect)
                            Icon(Icons.check, color: Colors.green, size: 16),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'الفئة: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(question['category'] as String),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'مرات الاستخدام: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('${question['usage_count'] ?? 0}'),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
    );
  }

  void _editQuestion(Map<String, dynamic> question) {
    // TODO: تنفيذ تعديل السؤال
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ميزة تعديل الأسئلة قيد التطوير'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _deleteQuestionConfirm(Map<String, dynamic> question) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: Text(
              'هل أنت متأكد من حذف السؤال:\n\n"${question['question']}"',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteQuestion(question['id']);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteQuestion(String questionId) async {
    try {
      final success = await _firebaseService.deleteQuestion(questionId);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف السؤال بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAllQuestions();
        widget.onRefresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في حذف السؤال'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في حذف السؤال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
