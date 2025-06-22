class Question {
  final String? id;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String? category;
  final int usageCount;
  final String source;

  Question({
    this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    this.category,
    this.usageCount = 0,
    this.source = 'manual_add',
  });

  bool isCorrectAnswer(int selectedIndex) {
    return selectedIndex == correctAnswerIndex;
  }

  String get correctAnswer => options[correctAnswerIndex];

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      questionText: json['question'],
      options: List<String>.from(json['options']),
      correctAnswerIndex: json['correct_answer'],
      category: json['category'],
      usageCount: json['usage_count'] ?? 0,
      source: json['source'] ?? 'manual_add',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': questionText,
      'options': options,
      'correct_answer': correctAnswerIndex,
      'category': category,
      'usage_count': usageCount,
      'source': source,
    };
  }

  // دالة لإنشاء نسخة محدثة من السؤال
  Question copyWith({
    String? id,
    String? questionText,
    List<String>? options,
    int? correctAnswerIndex,
    String? category,
    int? usageCount,
    String? source,
  }) {
    return Question(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      category: category ?? this.category,
      usageCount: usageCount ?? this.usageCount,
      source: source ?? this.source,
    );
  }
}
