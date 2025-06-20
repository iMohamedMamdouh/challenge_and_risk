import 'package:cloud_firestore/cloud_firestore.dart';

import 'player.dart';
import 'question.dart';

enum GameState { waiting, inProgress, finished }

class GameRoom {
  final String id;
  final String hostId;
  final List<OnlinePlayer> players;
  final int maxPlayers;
  final GameState state;
  final List<Question> questions;
  final int currentQuestionIndex;
  final int currentPlayerIndex;
  final DateTime createdAt;
  final String? currentChallenge;

  GameRoom({
    required this.id,
    required this.hostId,
    required this.players,
    required this.maxPlayers,
    required this.state,
    required this.questions,
    required this.currentQuestionIndex,
    required this.currentPlayerIndex,
    required this.createdAt,
    this.currentChallenge,
  });

  factory GameRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameRoom(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      players:
          (data['players'] as List<dynamic>?)
              ?.map((p) => OnlinePlayer.fromMap(p))
              .toList() ??
          [],
      maxPlayers: data['maxPlayers'] ?? 2,
      state: GameState.values[data['state'] ?? 0],
      questions:
          (data['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromJson(q))
              .toList() ??
          [],
      currentQuestionIndex: data['currentQuestionIndex'] ?? 0,
      currentPlayerIndex: data['currentPlayerIndex'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentChallenge: data['currentChallenge'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'hostId': hostId,
      'players': players.map((p) => p.toMap()).toList(),
      'playerIds': players.map((p) => p.id).toList(),
      'maxPlayers': maxPlayers,
      'state': state.index,
      'questions': questions.map((q) => q.toJson()).toList(),
      'currentQuestionIndex': currentQuestionIndex,
      'currentPlayerIndex': currentPlayerIndex,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentChallenge': currentChallenge,
    };
  }

  GameRoom copyWith({
    String? id,
    String? hostId,
    List<OnlinePlayer>? players,
    int? maxPlayers,
    GameState? state,
    List<Question>? questions,
    int? currentQuestionIndex,
    int? currentPlayerIndex,
    DateTime? createdAt,
    String? currentChallenge,
  }) {
    return GameRoom(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      players: players ?? this.players,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      state: state ?? this.state,
      questions: questions ?? this.questions,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      createdAt: createdAt ?? this.createdAt,
      currentChallenge: currentChallenge ?? this.currentChallenge,
    );
  }

  bool get isFull => players.length >= maxPlayers;
  bool get canStart => players.length >= 2 && state == GameState.waiting;
  OnlinePlayer? get currentPlayer =>
      currentPlayerIndex < players.length ? players[currentPlayerIndex] : null;
  Question? get currentQuestion =>
      currentQuestionIndex < questions.length
          ? questions[currentQuestionIndex]
          : null;
}

class OnlinePlayer extends Player {
  final int? selectedAnswer;

  OnlinePlayer({
    required super.id,
    required super.name,
    super.score = 0,
    super.isHost = false,
    super.isOnline = true,
    this.selectedAnswer,
  });

  factory OnlinePlayer.fromMap(Map<String, dynamic> map) {
    return OnlinePlayer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      score: map['score'] ?? 0,
      isHost: map['isHost'] ?? false,
      isOnline: map['isOnline'] ?? true,
      selectedAnswer: map['selectedAnswer'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'score': score,
      'isHost': isHost,
      'isOnline': isOnline,
      'selectedAnswer': selectedAnswer,
    };
  }

  OnlinePlayer copyWith({
    String? id,
    String? name,
    int? score,
    bool? isHost,
    bool? isOnline,
    int? selectedAnswer,
  }) {
    return OnlinePlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      isHost: isHost ?? this.isHost,
      isOnline: isOnline ?? this.isOnline,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
    );
  }
}
