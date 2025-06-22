import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/firebase_service.dart';

class EditQuestionDialog extends StatefulWidget {
  final Question question;
  final List<Map<String, dynamic>> categories;
  final VoidCallback onQuestionUpdated;

  const EditQuestionDialog({
    super.key,
    required this.question,
    required this.categories,
    required this.onQuestionUpdated,
  });

  @override
  State<EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends State<EditQuestionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _option4Controller = TextEditingController();

  String _selectedCategory = '';
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
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _questionController.text = widget.question.questionText;
    _option1Controller.text = widget.question.options[0];
    _option2Controller.text = widget.question.options[1];
    _option3Controller.text = widget.question.options[2];
    _option4Controller.text = widget.question.options[3];
    _selectedCategory = widget.question.category ?? 'معلومات عامة';
    _correctAnswer = widget.question.correctAnswerIndex;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _option4Controller.dispose();
    super.dispose();
  }

  Future<void> _updateQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedQuestion = Question(
        id: widget.question.id,
        questionText: _questionController.text.trim(),
        options: [
          _option1Controller.text.trim(),
          _option2Controller.text.trim(),
          _option3Controller.text.trim(),
          _option4Controller.text.trim(),
        ],
        correctAnswerIndex: _correctAnswer,
        category: _selectedCategory,
        usageCount: widget.question.usageCount,
        source: widget.question.source,
      );

      final success = await FirebaseService().updateQuestion(
        widget.question.id ?? '',
        updatedQuestion,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تحديث السؤال بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onQuestionUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل في تحديث السؤال'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في تحديث السؤال: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // العنوان
            Row(
              children: [
                Icon(Icons.edit, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'تحرير السؤال',
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
                      const Text(
                        'الخيارات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

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
                                    suffixIcon:
                                        _correctAnswer == index
                                            ? Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            )
                                            : null,
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

                      const SizedBox(height: 20),

                      // معلومات إضافية
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معلومات السؤال',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'معرف السؤال: ${widget.question.id ?? "غير محدد"}',
                            ),
                            Text(
                              'عدد مرات الاستخدام: ${widget.question.usageCount}',
                            ),
                            Text('المصدر: ${widget.question.source}'),
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
                    onPressed: _isLoading ? null : _updateQuestion,
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
