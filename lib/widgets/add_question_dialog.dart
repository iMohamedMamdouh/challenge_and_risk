import 'package:flutter/material.dart';

import '../models/question.dart';
import '../services/firebase_service.dart';

class AddQuestionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final VoidCallback onQuestionAdded;

  const AddQuestionDialog({
    super.key,
    required this.categories,
    required this.onQuestionAdded,
  });

  @override
  State<AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<AddQuestionDialog> {
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
    'أفلام',
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
      final newQuestion = Question(
        questionText: _questionController.text.trim(),
        options: [
          _option1Controller.text.trim(),
          _option2Controller.text.trim(),
          _option3Controller.text.trim(),
          _option4Controller.text.trim(),
        ],
        correctAnswerIndex: _correctAnswer,
        category: _selectedCategory,
        usageCount: 0,
        source: 'manual_add',
      );

      final result = await FirebaseService().addQuestion(newQuestion);

      switch (result) {
        case QuestionAddResult.success:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم إضافة السؤال بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          widget.onQuestionAdded();
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
              content: Text('❌ فشل في إضافة السؤال'),
              backgroundColor: Colors.red,
            ),
          );
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ خطأ في إضافة السؤال: $e'),
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
                Icon(Icons.add_circle, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Text(
                  'إضافة سؤال جديد',
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
                          hintText: 'اكتب نص السؤال هنا...',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'يرجى إدخال نص السؤال';
                          }
                          if (value.trim().length < 10) {
                            return 'يجب أن يكون السؤال أكثر من 10 أحرف';
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

                      // ملاحظة
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'تأكد من اختيار الإجابة الصحيحة بالضغط على الدائرة المجاورة للخيار',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
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
                    onPressed: _isLoading ? null : _addQuestion,
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
                            : const Text('إضافة السؤال'),
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
