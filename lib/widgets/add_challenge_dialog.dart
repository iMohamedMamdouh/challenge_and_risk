import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../services/firebase_service.dart';

class AddChallengeDialog extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final VoidCallback onChallengeAdded;

  const AddChallengeDialog({
    super.key,
    required this.categories,
    required this.onChallengeAdded,
  });

  @override
  State<AddChallengeDialog> createState() => _AddChallengeDialogState();
}

class _AddChallengeDialogState extends State<AddChallengeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _challengeController = TextEditingController();

  String _selectedCategory = 'تحديات عامة';
  String _selectedDifficulty = 'متوسط';
  bool _isLoading = false;

  final List<String> _categories = [
    'تحديات عامة',
    'تحديات حركية',
    'تحديات فكرية',
    'تحديات إبداعية',
    'تحديات جماعية',
    'تحديات سريعة',
    'تحديات مضحكة',
    'تحديات صعبة',
  ];

  final List<String> _difficulties = ['سهل', 'متوسط', 'صعب'];

  @override
  void dispose() {
    _challengeController.dispose();
    super.dispose();
  }

  Future<void> _addChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newChallenge = Challenge(
        challengeText: _challengeController.text.trim(),
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        usageCount: 0,
        source: 'manual_add',
      );

      final result = await FirebaseService().addChallenge(newChallenge);

      switch (result) {
        case ChallengeAddResult.success:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم إضافة التحدي بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onChallengeAdded();
          break;

        case ChallengeAddResult.duplicate:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ هذا التحدي موجود مسبقاً في قاعدة البيانات'),
              backgroundColor: Colors.orange,
            ),
          );
          break;

        case ChallengeAddResult.error:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ فشل في إضافة التحدي'),
              backgroundColor: Colors.red,
            ),
          );
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في إضافة التحدي: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // العنوان
            Row(
              children: [
                Icon(Icons.sports_kabaddi, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'إضافة تحدي جديد',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),

            // النموذج
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // نص التحدي
                      TextFormField(
                        controller: _challengeController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'نص التحدي',
                          border: OutlineInputBorder(),
                          hintText:
                              'اكتب نص التحدي هنا...\nمثال: قم بأداء 10 تمارين ضغط',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال نص التحدي';
                          }
                          if (value.trim().length < 10) {
                            return 'يجب أن يكون التحدي أكثر من 10 أحرف';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // الفئة
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'فئة التحدي',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.category),
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
                      const SizedBox(height: 20),

                      // مستوى الصعوبة
                      const Text(
                        'مستوى الصعوبة',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children:
                            _difficulties.map((difficulty) {
                              final isSelected =
                                  _selectedDifficulty == difficulty;
                              final color = _getDifficultyColor(difficulty);
                              final icon = _getDifficultyIcon(difficulty);

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(
                                        () => _selectedDifficulty = difficulty,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? color.withOpacity(0.2)
                                                : Colors.grey.shade100,
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? color
                                                  : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(
                                            icon,
                                            color:
                                                isSelected
                                                    ? color
                                                    : Colors.grey,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            difficulty,
                                            style: TextStyle(
                                              color:
                                                  isSelected
                                                      ? color
                                                      : Colors.grey.shade600,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // ملاحظة
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb,
                              color: Colors.purple,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'اكتب تحدياً ممتعاً وآمناً يمكن للجميع تنفيذه',
                                style: TextStyle(
                                  color: Colors.purple.shade800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // أزرار الإجراءات
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
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
                            : const Text('إضافة التحدي'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
