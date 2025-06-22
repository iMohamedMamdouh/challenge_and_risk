import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class CategoryQuestionsScreen extends StatefulWidget {
  final String categoryName;
  final VoidCallback onRefresh;

  const CategoryQuestionsScreen({
    super.key,
    required this.categoryName,
    required this.onRefresh,
  });

  @override
  State<CategoryQuestionsScreen> createState() =>
      _CategoryQuestionsScreenState();
}

class _CategoryQuestionsScreenState extends State<CategoryQuestionsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _firebaseService.getQuestionsByCategory(
        widget.categoryName,
      );
      setState(() {
        _questions = questions;
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
    if (_searchQuery.isEmpty) return _questions;

    return _questions.where((question) {
      final questionText = (question['question'] as String).toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      return questionText.contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('أسئلة فئة: ${widget.categoryName}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadQuestions,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: TextField(
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
          ),

          // معلومات الفئة
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoCard(
                  'إجمالي الأسئلة',
                  '${_questions.length}',
                  Icons.quiz,
                  Colors.blue,
                ),
                _buildInfoCard(
                  'النتائج',
                  '${_filteredQuestions.length}',
                  Icons.search,
                  Colors.green,
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
                            _searchQuery.isEmpty
                                ? Icons.quiz_outlined
                                : Icons.search_off,
                            size: 80,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'لا توجد أسئلة في هذه الفئة'
                                : 'لا توجد نتائج للبحث',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          if (_searchQuery.isEmpty) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'يمكنك إضافة أسئلة جديدة من لوحة المشرف',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadQuestions,
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
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, int index) {
    final questionText = question['question'] as String;
    final options = List<String>.from(question['options'] ?? []);
    final correctAnswer = question['correct_answer'] as int;
    final usageCount = question['usage_count'] as int? ?? 0;
    final source = question['source'] as String? ?? 'unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.withOpacity(0.1),
          child: Text(
            '$index',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
        ),
        title: Text(
          questionText,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(Icons.play_arrow, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              'استُخدم $usageCount مرة',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getSourceColor(source).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getSourceLabel(source),
                style: TextStyle(
                  fontSize: 10,
                  color: _getSourceColor(source),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الخيارات:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...options.asMap().entries.map((entry) {
                  final optionIndex = entry.key;
                  final option = entry.value;
                  final isCorrect = optionIndex == correctAnswer;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isCorrect
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.05),
                      border: Border.all(
                        color: isCorrect ? Colors.green : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color:
                                isCorrect ? Colors.green : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(
                                65 + optionIndex,
                              ), // A, B, C, D
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontWeight:
                                  isCorrect
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color:
                                  isCorrect
                                      ? Colors.green.shade800
                                      : Colors.black87,
                            ),
                          ),
                        ),
                        if (isCorrect)
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // أزرار الإجراءات
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _editQuestion(question),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('تعديل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _deleteQuestionConfirm(question),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('حذف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
        return 'ملف محلي';
      case 'manual_add':
        return 'إضافة يدوية';
      default:
        return 'غير محدد';
    }
  }

  void _editQuestion(Map<String, dynamic> questionData) {
    // TODO: تنفيذ تعديل السؤال
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ميزة تعديل الأسئلة قيد التطوير'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _deleteQuestionConfirm(Map<String, dynamic> questionData) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content: const Text(
              'هل أنت متأكد من حذف هذا السؤال؟\n\nلا يمكن التراجع عن هذا الإجراء.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _deleteQuestion(questionData['id']);
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
        _loadQuestions(); // إعادة تحميل الأسئلة
        widget.onRefresh(); // تحديث الشاشة الرئيسية
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
