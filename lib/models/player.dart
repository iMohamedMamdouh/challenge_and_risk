class Player {
  final String id;
  String name;
  int score;
  final bool isHost;
  final bool isOnline;

  Player({
    required this.id,
    required this.name,
    this.score = 0,
    this.isHost = false,
    this.isOnline = true,
  });

  void addPoint() {
    score++;
  }

  void resetScore() {
    score = 0;
  }

  // Convert Player to JSON for Firebase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'score': score,
      'isHost': isHost,
      'isOnline': isOnline,
    };
  }

  // Create Player from JSON
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      score: json['score'] ?? 0,
      isHost: json['isHost'] ?? false,
      isOnline: json['isOnline'] ?? true,
    );
  }

  @override
  String toString() {
    return 'Player{id: $id, name: $name, score: $score, isHost: $isHost, isOnline: $isOnline}';
  }
}
