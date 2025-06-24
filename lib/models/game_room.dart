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
  final String? winner;
  final String? endReason;
  final int? timerDuration;

  // نظام تتبع الأدوار
  final List<int>? availablePlayerIndices;
  final int? lastPlayerIndex;

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
    this.winner,
    this.endReason,
    this.timerDuration,
    this.availablePlayerIndices,
    this.lastPlayerIndex,
  });

  factory GameRoom.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null || data is! Map<String, dynamic>) {
      throw Exception('بيانات الغرفة تالفة أو فارغة');
    }

    return GameRoom(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      maxPlayers: data['maxPlayers'] ?? 4,
      state: GameState.values[data['state'] ?? 0],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      players:
          (data['players'] as List<dynamic>? ?? [])
              .map((p) => OnlinePlayer.fromMap(p as Map<String, dynamic>))
              .toList(),
      questions:
          (data['questions'] as List<dynamic>? ?? [])
              .map((q) => Question.fromJson(q as Map<String, dynamic>))
              .toList(),
      currentQuestionIndex: data['currentQuestionIndex'] ?? 0,
      currentPlayerIndex: data['currentPlayerIndex'] ?? 0,
      currentChallenge: data['currentChallenge'],
      availablePlayerIndices:
          (data['availablePlayerIndices'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList(),
      lastPlayerIndex: data['lastPlayerIndex'],
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
      'winner': winner,
      'endReason': endReason,
      'timerDuration': timerDuration,
      'availablePlayerIndices': availablePlayerIndices,
      'lastPlayerIndex': lastPlayerIndex,
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
    String? winner,
    String? endReason,
    int? timerDuration,
    List<int>? availablePlayerIndices,
    int? lastPlayerIndex,
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
      winner: winner ?? this.winner,
      endReason: endReason ?? this.endReason,
      timerDuration: timerDuration ?? this.timerDuration,
      availablePlayerIndices:
          availablePlayerIndices ?? this.availablePlayerIndices,
      lastPlayerIndex: lastPlayerIndex ?? this.lastPlayerIndex,
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
  final DateTime? lastSeen;

  OnlinePlayer({
    required super.id,
    required super.name,
    super.score = 0,
    super.isHost = false,
    super.isOnline = true,
    this.selectedAnswer,
    this.lastSeen,
  });

  factory OnlinePlayer.fromMap(Map<String, dynamic> map) {
    return OnlinePlayer(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      score: map['score'] ?? 0,
      isHost: map['isHost'] ?? false,
      isOnline: map['isOnline'] ?? true,
      selectedAnswer: map['selectedAnswer'],
      lastSeen:
          map['lastSeen'] != null
              ? (map['lastSeen'] as Timestamp).toDate()
              : null,
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
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    };
  }

  OnlinePlayer copyWith({
    String? id,
    String? name,
    int? score,
    bool? isHost,
    bool? isOnline,
    int? selectedAnswer,
    DateTime? lastSeen,
  }) {
    return OnlinePlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      isHost: isHost ?? this.isHost,
      isOnline: isOnline ?? this.isOnline,
      selectedAnswer: selectedAnswer ?? this.selectedAnswer,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
