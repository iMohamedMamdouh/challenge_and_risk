class Question {
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String? category;

  Question({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    this.category,
  });

  bool isCorrectAnswer(int selectedIndex) {
    return selectedIndex == correctAnswerIndex;
  }

  String get correctAnswer => options[correctAnswerIndex];

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      questionText: json['question'],
      options: List<String>.from(json['options']),
      correctAnswerIndex: json['correct_answer'],
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': questionText,
      'options': options,
      'correct_answer': correctAnswerIndex,
      'category': category,
    };
  }
}
