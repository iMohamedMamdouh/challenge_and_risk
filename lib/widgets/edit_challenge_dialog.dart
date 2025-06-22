import 'package:flutter/material.dart';

import '../models/challenge.dart';
import '../services/firebase_service.dart';

class EditChallengeDialog extends StatefulWidget {
  final Map<String, dynamic> challenge;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onChallengeUpdated;

  const EditChallengeDialog({
    super.key,
    required this.challenge,
    required this.categories,
    required this.onChallengeUpdated,
  });

  @override
  State<EditChallengeDialog> createState() => _EditChallengeDialogState();
}

class _EditChallengeDialogState extends State<EditChallengeDialog> {
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
  void initState() {
    super.initState();
    _challengeController.text = widget.challenge['challenge'] ?? '';
    _selectedCategory = widget.challenge['category'] ?? 'تحديات عامة';
    _selectedDifficulty = widget.challenge['difficulty'] ?? 'متوسط';
  }

  @override
  void dispose() {
    _challengeController.dispose();
    super.dispose();
  }

  Future<void> _updateChallenge() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedChallenge = Challenge(
        id: widget.challenge['id'],
        challengeText: _challengeController.text.trim(),
        category: _selectedCategory,
        difficulty: _selectedDifficulty,
        usageCount: widget.challenge['usage_count'] ?? 0,
        source: widget.challenge['source'] ?? 'manual_add',
      );

      final success = await FirebaseService().updateChallenge(
        widget.challenge['id'],
        updatedChallenge,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تحديث التحدي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onChallengeUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في تحديث التحدي'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في تحديث التحدي: $e'),
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
                Icon(Icons.edit, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'تحرير التحدي',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
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
                      // معلومات التحدي الحالي
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معلومات التحدي الحالي:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('الفئة: ${widget.challenge['category']}'),
                            Text('الصعوبة: ${widget.challenge['difficulty']}'),
                            Text(
                              'مرات الاستخدام: ${widget.challenge['usage_count'] ?? 0}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // نص التحدي
                      TextFormField(
                        controller: _challengeController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'نص التحدي',
                          border: OutlineInputBorder(),
                          hintText: 'اكتب نص التحدي هنا...',
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
                    onPressed: _isLoading ? null : _updateChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
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
                            : const Text('حفظ التغييرات'),
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
