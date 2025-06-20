import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/game_room.dart';
import '../models/question.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal() {
    _ensureFirebaseInitialized();
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // معرف المستخدم الحالي (يتم إنشاؤه محلياً)
  String? _currentUserId;
  String get currentUserId {
    _currentUserId ??= _uuid.v4();
    return _currentUserId!;
  }

  // التأكد من تهيئة Firebase
  void _ensureFirebaseInitialized() {
    try {
      if (Firebase.apps.isEmpty) {
        throw Exception(
          'Firebase not initialized. Call Firebase.initializeApp() first.',
        );
      }
    } catch (e) {
      print('Firebase check error: $e');
    }
  }

  // Collection references
  CollectionReference get _roomsCollection =>
      _firestore.collection('game_rooms');

  // Generate room code
  String generateRoomCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Load questions from assets
  Future<List<Question>> _loadQuestions({int count = 10}) async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/questions.json',
      );
      final List<dynamic> data = json.decode(response);
      final List<Question> allQuestions =
          data.map((json) => Question.fromJson(json)).toList();

      // Shuffle and take specified number of questions
      final random = Random();
      allQuestions.shuffle(random);
      return allQuestions.take(count).toList();
    } catch (e) {
      print('Error loading questions: $e');
      return [];
    }
  }

  // Create a new game room
  Future<GameRoom?> createRoom(
    String hostName,
    int maxPlayers, {
    int questionsCount = 10,
  }) async {
    try {
      print('🚀 بدء إنشاء الغرفة...');
      print('اسم اللاعب: $hostName');
      print('عدد اللاعبين الأقصى: $maxPlayers');
      print('عدد الأسئلة: $questionsCount');

      final userId = currentUserId;
      print('✅ معرف المستخدم: $userId');

      final roomCode = generateRoomCode();
      print('🎲 تم إنشاء كود الغرفة: $roomCode');

      print('📚 جاري تحميل الأسئلة...');
      final questions = await _loadQuestions(count: questionsCount);
      if (questions.isEmpty) {
        print('❌ فشل في تحميل الأسئلة');
        return null;
      }
      print('✅ تم تحميل ${questions.length} سؤال');

      final host = OnlinePlayer(id: userId, name: hostName, isHost: true);

      final room = GameRoom(
        id: roomCode,
        hostId: userId,
        players: [host],
        maxPlayers: maxPlayers,
        state: GameState.waiting,
        questions: questions,
        currentQuestionIndex: 0,
        currentPlayerIndex: 0,
        createdAt: DateTime.now(),
      );

      print('💾 جاري حفظ الغرفة في Firebase...');
      await _roomsCollection.doc(roomCode).set(room.toFirestore());
      print('✅ تم حفظ الغرفة بنجاح!');

      return room;
    } catch (e) {
      print('❌ خطأ في إنشاء الغرفة: $e');
      print('تفاصيل الخطأ: ${e.toString()}');
      return null;
    }
  }

  // Join an existing room
  Future<GameRoom?> joinRoom(String roomCode, String playerName) async {
    try {
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return null;

      final room = GameRoom.fromFirestore(roomDoc);
      if (room.isFull || room.state != GameState.waiting) return null;

      // Check if player already exists
      final existingPlayerIndex = room.players.indexWhere(
        (p) => p.id == userId,
      );
      if (existingPlayerIndex != -1) {
        // Player already in room, just update online status
        final updatedPlayers = List<OnlinePlayer>.from(room.players);
        updatedPlayers[existingPlayerIndex] =
            updatedPlayers[existingPlayerIndex].copyWith(isOnline: true);

        await _roomsCollection.doc(roomCode).update({
          'players': updatedPlayers.map((p) => p.toMap()).toList(),
        });

        return room.copyWith(players: updatedPlayers);
      }

      // Add new player
      final newPlayer = OnlinePlayer(id: userId, name: playerName);

      final updatedPlayers = [...room.players, newPlayer];

      await _roomsCollection.doc(roomCode).update({
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
      });

      return room.copyWith(players: updatedPlayers);
    } catch (e) {
      print('Error joining room: $e');
      return null;
    }
  }

  // Start the game (host only)
  Future<bool> startGame(String roomCode) async {
    try {
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final room = GameRoom.fromFirestore(roomDoc);
      if (room.hostId != userId || !room.canStart) return false;

      await _roomsCollection.doc(roomCode).update({
        'state': GameState.inProgress.index,
      });

      return true;
    } catch (e) {
      print('Error starting game: $e');
      return false;
    }
  }

  // Submit answer
  Future<bool> submitAnswer(String roomCode, int answerIndex) async {
    try {
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final room = GameRoom.fromFirestore(roomDoc);
      final currentPlayer = room.currentPlayer;

      if (currentPlayer?.id != userId) return false;

      // Update player's selected answer
      final updatedPlayers =
          room.players.map((player) {
            if (player.id == userId) {
              return player.copyWith(selectedAnswer: answerIndex);
            }
            return player;
          }).toList();

      await _roomsCollection.doc(roomCode).update({
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
      });

      return true;
    } catch (e) {
      print('Error submitting answer: $e');
      return false;
    }
  }

  // Process answer and move to next turn
  Future<bool> processAnswer(String roomCode, bool isCorrect) async {
    try {
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final room = GameRoom.fromFirestore(roomDoc);
      final currentPlayer = room.currentPlayer;

      if (currentPlayer?.id != userId) return false;

      // Update score if correct
      final updatedPlayers =
          room.players.map((player) {
            if (player.id == userId && isCorrect) {
              return player.copyWith(score: player.score + 1);
            }
            return player.copyWith(selectedAnswer: null);
          }).toList();

      // Move to next turn
      int nextPlayerIndex = (room.currentPlayerIndex + 1) % room.players.length;
      int nextQuestionIndex = room.currentQuestionIndex;

      // If we completed a full round, move to next question
      if (nextPlayerIndex == 0) {
        nextQuestionIndex++;
      }

      // Check if game is finished
      final gameState =
          nextQuestionIndex >= room.questions.length
              ? GameState.finished
              : GameState.inProgress;

      await _roomsCollection.doc(roomCode).update({
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
        'currentPlayerIndex': nextPlayerIndex,
        'currentQuestionIndex': nextQuestionIndex,
        'state': gameState.index,
        'currentChallenge': isCorrect ? null : 'challenge_needed',
      });

      return true;
    } catch (e) {
      print('Error processing answer: $e');
      return false;
    }
  }

  // Set challenge for wrong answer
  Future<bool> setChallenge(String roomCode, String challenge) async {
    try {
      await _roomsCollection.doc(roomCode).update({
        'currentChallenge': challenge,
      });
      return true;
    } catch (e) {
      print('Error setting challenge: $e');
      return false;
    }
  }

  // Complete challenge and continue
  Future<bool> completeChallenge(String roomCode) async {
    try {
      await _roomsCollection.doc(roomCode).update({'currentChallenge': null});
      return true;
    } catch (e) {
      print('Error completing challenge: $e');
      return false;
    }
  }

  // Leave room
  Future<bool> leaveRoom(String roomCode) async {
    try {
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final room = GameRoom.fromFirestore(roomDoc);

      // If host leaves, delete the room
      if (room.hostId == userId) {
        await _roomsCollection.doc(roomCode).delete();
        return true;
      }

      // Remove player from room
      final updatedPlayers =
          room.players.where((player) => player.id != userId).toList();

      if (updatedPlayers.isEmpty) {
        // No players left, delete room
        await _roomsCollection.doc(roomCode).delete();
      } else {
        await _roomsCollection.doc(roomCode).update({
          'players': updatedPlayers.map((p) => p.toMap()).toList(),
        });
      }

      return true;
    } catch (e) {
      print('Error leaving room: $e');
      return false;
    }
  }

  // Listen to room changes
  Stream<GameRoom?> listenToRoom(String roomCode) {
    return _roomsCollection.doc(roomCode).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return GameRoom.fromFirestore(snapshot);
    });
  }

  // Reset room for new game
  Future<bool> resetRoom(String roomCode) async {
    try {
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final room = GameRoom.fromFirestore(roomDoc);
      if (room.hostId != userId) return false;

      final questions = await _loadQuestions();

      // Reset scores and game state
      final resetPlayers =
          room.players.map((player) {
            return player.copyWith(score: 0, selectedAnswer: null);
          }).toList();

      await _roomsCollection.doc(roomCode).update({
        'players': resetPlayers.map((p) => p.toMap()).toList(),
        'state': GameState.waiting.index,
        'questions': questions.map((q) => q.toJson()).toList(),
        'currentQuestionIndex': 0,
        'currentPlayerIndex': 0,
        'currentChallenge': null,
      });

      return true;
    } catch (e) {
      print('Error resetting room: $e');
      return false;
    }
  }
}
