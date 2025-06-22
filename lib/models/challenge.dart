class Challenge {
  final String id;
  final String challengeText;
  final String category;
  final String difficulty; // سهل، متوسط، صعب
  final int usageCount;
  final String source;
  final DateTime? createdAt;

  const Challenge({
    this.id = '',
    required this.challengeText,
    this.category = 'تحديات عامة',
    this.difficulty = 'متوسط',
    this.usageCount = 0,
    this.source = 'manual_add',
    this.createdAt,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] ?? '',
      challengeText: json['challenge'] ?? json['challengeText'] ?? '',
      category: json['category'] ?? 'تحديات عامة',
      difficulty: json['difficulty'] ?? 'متوسط',
      usageCount: json['usage_count'] ?? 0,
      source: json['source'] ?? 'manual_add',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge': challengeText,
      'category': category,
      'difficulty': difficulty,
      'usage_count': usageCount,
      'source': source,
    };
  }

  Challenge copyWith({
    String? id,
    String? challengeText,
    String? category,
    String? difficulty,
    int? usageCount,
    String? source,
    DateTime? createdAt,
  }) {
    return Challenge(
      id: id ?? this.id,
      challengeText: challengeText ?? this.challengeText,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      usageCount: usageCount ?? this.usageCount,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Challenge &&
        other.id == id &&
        other.challengeText == challengeText &&
        other.category == category &&
        other.difficulty == difficulty;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        challengeText.hashCode ^
        category.hashCode ^
        difficulty.hashCode;
  }
}
