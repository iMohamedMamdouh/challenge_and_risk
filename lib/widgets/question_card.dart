import 'package:flutter/material.dart';

import '../models/question.dart';

class QuestionCard extends StatefulWidget {
  final Question question;
  final Function(int)? onAnswerSelected;
  final bool isLoading;
  final int? selectedAnswer;

  const QuestionCard({
    super.key,
    required this.question,
    this.onAnswerSelected,
    this.isLoading = false,
    this.selectedAnswer,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  @override
  void didUpdateWidget(QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إعادة تعيين الإجابة المختارة عند تغيير السؤال أو عند تغيير selectedAnswer من الخارج
    if (oldWidget.question != widget.question ||
        oldWidget.selectedAnswer != widget.selectedAnswer) {
      // لا نحتاج لحفظ حالة داخلية بعد الآن
    }
  }

  void _selectAnswer(int index) {
    if (widget.onAnswerSelected != null && !widget.isLoading) {
      widget.onAnswerSelected!(index);
    }
  }

  Color _getButtonColor(int index) {
    if (widget.selectedAnswer == index) {
      return Colors.deepPurple.shade600;
    }
    return Colors.white;
  }

  Color _getTextColor(int index) {
    if (widget.selectedAnswer == index) {
      return Colors.white;
    }
    return Colors.deepPurple.shade700;
  }

  Color _getBorderColor(int index) {
    if (widget.selectedAnswer == index) {
      return Colors.deepPurple.shade600;
    }
    return Colors.deepPurple.shade300;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 3,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Question text
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.shade200),
            ),
            child: Text(
              widget.question.questionText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade800,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Answer options
          ...widget.question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = widget.selectedAnswer == index;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                elevation: isSelected ? 6 : 2,
                borderRadius: BorderRadius.circular(12),
                shadowColor:
                    isSelected
                        ? Colors.deepPurple.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.2),
                child: InkWell(
                  onTap: widget.isLoading ? null : () => _selectAnswer(index),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getButtonColor(index),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getBorderColor(index),
                        width: 2,
                      ),
                      gradient:
                          isSelected
                              ? LinearGradient(
                                colors: [
                                  Colors.deepPurple.shade500,
                                  Colors.deepPurple.shade700,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                              : null,
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.deepPurple.shade600,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: (isSelected
                                        ? Colors.white
                                        : Colors.deepPurple)
                                    .withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index), // A, B, C, D
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.deepPurple.shade700
                                        : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _getTextColor(index),
                            ),
                          ),
                        ),
                        if (isSelected && !widget.isLoading) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.deepPurple.shade600,
                              size: 18,
                            ),
                          ),
                        ],
                        if (widget.isLoading && isSelected) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.deepPurple.shade600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          if (widget.isLoading) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.deepPurple.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.deepPurple.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'جاري معالجة الإجابة...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.deepPurple.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
