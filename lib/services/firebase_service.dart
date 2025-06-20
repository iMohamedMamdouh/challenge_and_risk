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

      // التحقق من تهيئة Firebase
      if (Firebase.apps.isEmpty) {
        print('❌ Firebase غير مهيأ');
        return null;
      }

      // التحقق من إعدادات Firestore
      try {
        await _firestore.enableNetwork();
        print('✅ تم تفعيل شبكة Firestore');
      } catch (e) {
        print('⚠️ تحذير: مشكلة في شبكة Firestore: $e');
      }

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
      print('🔑 معرف المستند: $roomCode');

      // إضافة معلومات تشخيصية إضافية
      final roomData = room.toFirestore();
      print('📄 بيانات الغرفة: ${roomData.keys}');

      // محاولة الكتابة مع مهلة زمنية
      await _roomsCollection
          .doc(roomCode)
          .set(roomData)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('انتهت مهلة الكتابة في Firestore');
            },
          );

      print('✅ تم حفظ الغرفة بنجاح!');

      // التحقق من أن الغرفة تم حفظها
      try {
        final savedDoc = await _roomsCollection.doc(roomCode).get();
        if (savedDoc.exists) {
          print('✅ تم التحقق من حفظ الغرفة');
        } else {
          print('⚠️ الغرفة غير موجودة بعد الحفظ');
        }
      } catch (e) {
        print('⚠️ خطأ في التحقق من الغرفة: $e');
      }

      return room;
    } catch (e, stackTrace) {
      print('❌ خطأ في إنشاء الغرفة: $e');
      print('تفاصيل الخطأ: ${e.toString()}');
      print('Stack trace: $stackTrace');

      // معلومات إضافية للتشخيص
      if (e.toString().contains('permission-denied')) {
        print('🔒 خطأ في الأذونات - تحقق من قواعد Firestore');
        print('💡 تأكد من نشر القواعد في Firebase Console');
      }

      return null;
    }
  }

  // Join an existing room
  Future<GameRoom?> joinRoom(String roomCode, String playerName) async {
    try {
      print('🚪 بدء عملية الانضمام للغرفة...');
      print('🔑 كود الغرفة: $roomCode');
      print('👤 اسم اللاعب: $playerName');

      final userId = currentUserId;
      print('🆔 معرف المستخدم: $userId');

      // التحقق من صحة البيانات
      if (roomCode.trim().isEmpty) {
        print('❌ كود الغرفة فارغ');
        return null;
      }

      if (playerName.trim().isEmpty) {
        print('❌ اسم اللاعب فارغ');
        return null;
      }

      // البحث عن الغرفة مع معالجة الأخطاء
      print('🔍 البحث عن الغرفة...');
      DocumentSnapshot roomDoc;

      try {
        roomDoc = await _roomsCollection
            .doc(roomCode)
            .get()
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw Exception('انتهت مهلة البحث عن الغرفة');
              },
            );
      } catch (e) {
        print('❌ فشل في البحث عن الغرفة: $e');
        if (e.toString().contains('permission-denied')) {
          print('🔒 مشكلة في الأذونات - تحقق من قواعد Firestore');
        } else if (e.toString().contains('network')) {
          print('🌐 مشكلة في الشبكة');
        }
        rethrow;
      }

      if (!roomDoc.exists) {
        print('❌ الغرفة غير موجودة');
        return null;
      }

      print('✅ تم العثور على الغرفة');

      // تحليل بيانات الغرفة
      GameRoom room;
      try {
        print('📊 تحليل بيانات الغرفة...');
        room = GameRoom.fromFirestore(roomDoc);
        print('📋 معلومات الغرفة:');
        print('   - المضيف: ${room.hostId}');
        print('   - عدد اللاعبين: ${room.players.length}/${room.maxPlayers}');
        print('   - الحالة: ${room.state}');
      } catch (e) {
        print('❌ فشل في تحليل بيانات الغرفة: $e');
        throw Exception('بيانات الغرفة تالفة: $e');
      }

      // التحقق من حالة الغرفة
      if (room.state != GameState.waiting) {
        print('❌ الغرفة ليست في حالة انتظار (الحالة: ${room.state})');
        return null;
      }

      if (room.isFull) {
        print('❌ الغرفة ممتلئة (${room.players.length}/${room.maxPlayers})');
        return null;
      }

      // التحقق من وجود اللاعب مسبقاً
      final existingPlayerIndex = room.players.indexWhere(
        (p) => p.id == userId,
      );

      if (existingPlayerIndex != -1) {
        print('🔄 اللاعب موجود مسبقاً - تحديث الحالة...');
        // Player already in room, just update online status
        final updatedPlayers = List<OnlinePlayer>.from(room.players);
        updatedPlayers[existingPlayerIndex] =
            updatedPlayers[existingPlayerIndex].copyWith(isOnline: true);

        try {
          await _roomsCollection.doc(roomCode).update({
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
          });
          print('✅ تم تحديث حالة اللاعب');
          return room.copyWith(players: updatedPlayers);
        } catch (e) {
          print('❌ فشل في تحديث حالة اللاعب: $e');
          rethrow;
        }
      }

      // إضافة لاعب جديد
      print('➕ إضافة لاعب جديد...');
      final newPlayer = OnlinePlayer(id: userId, name: playerName);
      final updatedPlayers = [...room.players, newPlayer];

      print('💾 حفظ اللاعب الجديد في Firebase...');
      try {
        await _roomsCollection
            .doc(roomCode)
            .update({'players': updatedPlayers.map((p) => p.toMap()).toList()})
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw Exception('انتهت مهلة حفظ اللاعب');
              },
            );

        print('✅ تم الانضمام للغرفة بنجاح!');
        print(
          '👥 عدد اللاعبين الحالي: ${updatedPlayers.length}/${room.maxPlayers}',
        );

        // التحقق من حفظ البيانات
        try {
          final verifyDoc = await _roomsCollection.doc(roomCode).get();
          if (verifyDoc.exists) {
            final verifyData = verifyDoc.data() as Map<String, dynamic>;
            final savedPlayers = verifyData['players'] as List<dynamic>;
            print(
              '✅ تم التحقق من حفظ البيانات - عدد اللاعبين: ${savedPlayers.length}',
            );
          }
        } catch (e) {
          print('⚠️ فشل في التحقق من حفظ البيانات: $e');
        }

        return room.copyWith(players: updatedPlayers);
      } catch (e) {
        print('❌ فشل في حفظ اللاعب الجديد: $e');
        if (e.toString().contains('permission-denied')) {
          print('🔒 مشكلة في الأذونات - تحقق من قواعد Firestore');
        } else if (e.toString().contains('network')) {
          print('🌐 مشكلة في الشبكة');
        }
        rethrow;
      }
    } catch (e) {
      print('❌ خطأ عام في الانضمام للغرفة: $e');
      print('🔍 نوع الخطأ: ${e.runtimeType}');
      print('📄 تفاصيل الخطأ: ${e.toString()}');

      // تحليل تفصيلي للخطأ
      if (e.toString().contains('permission-denied')) {
        print('💡 الحل المحتمل: تحقق من قواعد Firebase Security Rules');
      } else if (e.toString().contains('network')) {
        print('💡 الحل المحتمل: تحقق من اتصال الإنترنت');
      } else if (e.toString().contains('timeout')) {
        print('💡 الحل المحتمل: اتصال بطيء أو مشكلة في الخادم');
      }

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
      print('🚪 بدء عملية مغادرة الغرفة: $roomCode');
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) {
        print('❌ الغرفة غير موجودة أو محذوفة مسبقاً');
        return true; // نعتبر العملية ناجحة لأن الهدف تحقق (عدم وجود اللاعب في الغرفة)
      }

      final room = GameRoom.fromFirestore(roomDoc);
      print('👥 عدد اللاعبين الحالي: ${room.players.length}');

      // التحقق من وجود اللاعب في الغرفة
      final playerExists = room.players.any((player) => player.id == userId);
      if (!playerExists) {
        print('ℹ️ اللاعب غير موجود في الغرفة مسبقاً');
        return true;
      }

      bool roomDeleted = false;

      // إذا كان هذا هو اللاعب الوحيد، احذف الغرفة مباشرة
      if (room.players.length <= 1) {
        print('🗑️ آخر لاعب يغادر - حذف الغرفة تلقائياً');
        await _roomsCollection.doc(roomCode).delete();
        print('✅ تم حذف الغرفة تلقائياً');
        roomDeleted = true;
      }
      // إذا كان المضيف يغادر
      else if (room.hostId == userId) {
        print('👑 المضيف يغادر الغرفة');

        // العثور على لاعب آخر ليصبح المضيف الجديد
        final remainingPlayers =
            room.players.where((player) => player.id != userId).toList();

        if (remainingPlayers.isEmpty) {
          // لا يوجد لاعبين آخرين، احذف الغرفة
          print('🗑️ لا يوجد لاعبين آخرين - حذف الغرفة');
          await _roomsCollection.doc(roomCode).delete();
          print('✅ تم حذف الغرفة تلقائياً');
          roomDeleted = true;
        } else {
          // نقل المضيف للاعب التالي
          final newHost = remainingPlayers.first;
          final updatedPlayers =
              remainingPlayers.map((player) {
                if (player.id == newHost.id) {
                  return player.copyWith(isHost: true);
                }
                return player.copyWith(isHost: false);
              }).toList();

          print('👑 نقل المضيف إلى: ${newHost.name}');
          await _roomsCollection.doc(roomCode).update({
            'hostId': newHost.id,
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
          });
          print('✅ تم نقل المضيف وإزالة اللاعب');
        }
      } else {
        // لاعب عادي يغادر
        print('👤 لاعب عادي يغادر الغرفة');
        final updatedPlayers =
            room.players.where((player) => player.id != userId).toList();

        if (updatedPlayers.isEmpty) {
          // آخر لاعب يغادر، احذف الغرفة
          print('🗑️ آخر لاعب يغادر - حذف الغرفة');
          await _roomsCollection.doc(roomCode).delete();
          print('✅ تم حذف الغرفة تلقائياً');
          roomDeleted = true;
        } else {
          // تحديث قائمة اللاعبين فقط
          await _roomsCollection.doc(roomCode).update({
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
          });
          print('✅ تم إزالة اللاعب من الغرفة');
        }
      }

      // تحقق إضافي من أن الغرفة لم تصبح فارغة (فقط إذا لم يتم حذفها)
      if (!roomDeleted) {
        await _checkAndCleanEmptyRoom(roomCode);
      }

      return true;
    } catch (e) {
      print('❌ خطأ في مغادرة الغرفة: $e');
      print('🔍 نوع الخطأ: ${e.runtimeType}');
      print('📄 تفاصيل الخطأ: ${e.toString()}');
      return false;
    }
  }

  // دالة مساعدة للتحقق من الغرف الفارغة وحذفها
  Future<void> _checkAndCleanEmptyRoom(String roomCode) async {
    try {
      print('🔍 فحص الغرفة للتأكد من عدم كونها فارغة: $roomCode');

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) {
        print('ℹ️ الغرفة محذوفة مسبقاً أو غير موجودة');
        return;
      }

      final roomData = roomDoc.data() as Map<String, dynamic>?;
      if (roomData == null) {
        print('⚠️ بيانات الغرفة فارغة - حذف الغرفة');
        await _roomsCollection.doc(roomCode).delete();
        return;
      }

      final players = roomData['players'] as List<dynamic>? ?? [];

      if (players.isEmpty) {
        print('🧹 تم اكتشاف غرفة فارغة، يتم حذفها...');
        await _roomsCollection.doc(roomCode).delete();
        print('✅ تم حذف الغرفة الفارغة تلقائياً');
      } else {
        print('👥 الغرفة تحتوي على ${players.length} لاعب - لا حاجة للحذف');
      }
    } catch (e) {
      print('⚠️ خطأ في فحص الغرفة الفارغة: $e');
      // لا نرمي الخطأ هنا لتجنب مقاطعة عملية المغادرة الأساسية
    }
  }

  // دالة لمراقبة الغرف وحذف الفارغة تلقائياً (يمكن استدعاؤها دورياً)
  Future<int> autoCleanEmptyRooms() async {
    try {
      print('🤖 بدء التنظيف التلقائي للغرف الفارغة...');

      final querySnapshot = await _roomsCollection.get();
      int deletedCount = 0;

      for (final doc in querySnapshot.docs) {
        try {
          final roomData = doc.data() as Map<String, dynamic>;
          final players = roomData['players'] as List<dynamic>? ?? [];

          // حذف الغرف الفارغة
          if (players.isEmpty) {
            await doc.reference.delete();
            deletedCount++;
            print('🗑️ تم حذف الغرفة الفارغة تلقائياً: ${doc.id}');
          }
        } catch (e) {
          print('⚠️ خطأ في معالجة الغرفة ${doc.id}: $e');
        }
      }

      if (deletedCount > 0) {
        print('🎯 التنظيف التلقائي مكتمل: تم حذف $deletedCount غرفة فارغة');
      } else {
        print('✨ جميع الغرف تحتوي على لاعبين - لا حاجة للتنظيف');
      }

      return deletedCount;
    } catch (e) {
      print('❌ خطأ في التنظيف التلقائي: $e');
      return 0;
    }
  }

  // دالة محسّنة للانضمام للغرفة مع التحقق من عدم وجود غرف فارغة
  Future<GameRoom?> joinRoomWithAutoClean(
    String roomCode,
    String playerName,
  ) async {
    // تنظيف تلقائي قبل الانضمام
    await autoCleanEmptyRooms();

    // محاولة الانضمام العادية
    return await joinRoom(roomCode, playerName);
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

  // حذف الغرف الفارغة
  Future<int> deleteEmptyRooms() async {
    try {
      print('🧹 بدء عملية تنظيف الغرف الفارغة...');

      final querySnapshot = await _roomsCollection.get();
      int deletedCount = 0;

      for (final doc in querySnapshot.docs) {
        try {
          final roomData = doc.data() as Map<String, dynamic>;
          final players = roomData['players'] as List<dynamic>? ?? [];

          // حذف الغرف الفارغة (بدون لاعبين)
          if (players.isEmpty) {
            await doc.reference.delete();
            deletedCount++;
            print('🗑️ تم حذف الغرفة الفارغة: ${doc.id}');
          }
        } catch (e) {
          print('⚠️ خطأ في معالجة الغرفة ${doc.id}: $e');
        }
      }

      print('✅ تم حذف $deletedCount غرفة فارغة');
      return deletedCount;
    } catch (e) {
      print('❌ خطأ في تنظيف الغرف الفارغة: $e');
      return 0;
    }
  }

  // حذف الغرف القديمة المنتهية
  Future<int> deleteOldFinishedRooms({int hoursThreshold = 24}) async {
    try {
      print('🧹 بدء عملية تنظيف الغرف القديمة...');

      final cutoffTime = DateTime.now().subtract(
        Duration(hours: hoursThreshold),
      );
      final querySnapshot =
          await _roomsCollection
              .where('state', isEqualTo: GameState.finished.index)
              .get();

      int deletedCount = 0;

      for (final doc in querySnapshot.docs) {
        try {
          final roomData = doc.data() as Map<String, dynamic>;
          final createdAt = (roomData['createdAt'] as Timestamp?)?.toDate();

          if (createdAt != null && createdAt.isBefore(cutoffTime)) {
            await doc.reference.delete();
            deletedCount++;
            print('🗑️ تم حذف الغرفة القديمة: ${doc.id}');
          }
        } catch (e) {
          print('⚠️ خطأ في معالجة الغرفة ${doc.id}: $e');
        }
      }

      print('✅ تم حذف $deletedCount غرفة قديمة');
      return deletedCount;
    } catch (e) {
      print('❌ خطأ في تنظيف الغرف القديمة: $e');
      return 0;
    }
  }

  // تنظيف شامل للغرف
  Future<Map<String, int>> cleanupRooms() async {
    print('🧹 بدء التنظيف الشامل للغرف...');

    final emptyRoomsDeleted = await deleteEmptyRooms();
    final oldRoomsDeleted = await deleteOldFinishedRooms();

    final result = {
      'emptyRooms': emptyRoomsDeleted,
      'oldRooms': oldRoomsDeleted,
      'total': emptyRoomsDeleted + oldRoomsDeleted,
    };

    print('🏁 انتهت عملية التنظيف الشامل:');
    print('   - غرف فارغة: $emptyRoomsDeleted');
    print('   - غرف قديمة: $oldRoomsDeleted');
    print('   - المجموع: ${result['total']}');

    return result;
  }

  // دالة مساعدة لفحص وحذف الغرفة إذا كانت فارغة
  Future<bool> checkAndDeleteIfEmpty(String roomCode) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final roomData = roomDoc.data() as Map<String, dynamic>;
      final players = roomData['players'] as List<dynamic>? ?? [];

      if (players.isEmpty) {
        await _roomsCollection.doc(roomCode).delete();
        print('🗑️ تم حذف الغرفة الفارغة: $roomCode');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ خطأ في فحص الغرفة: $e');
      return false;
    }
  }

  // عرض الغرف المتاحة
  Future<Map<String, dynamic>> getAvailableRooms() async {
    final Map<String, dynamic> result = {
      'success': false,
      'rooms': [],
      'error': null,
    };

    try {
      print('🔍 البحث عن الغرف المتاحة...');

      final querySnapshot = await _roomsCollection
          .where('state', isEqualTo: 0) // 0 = waiting state
          .limit(10)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('انتهت مهلة البحث عن الغرف');
            },
          );

      result['rooms'] =
          querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final players = data['players'] as List<dynamic>;

            // البحث عن المضيف (المنشئ) من قائمة اللاعبين
            String hostName = 'غير معروف';
            final hostId = data['hostId'] as String;

            for (final playerData in players) {
              final player = playerData as Map<String, dynamic>;
              if (player['id'] == hostId) {
                hostName = player['name'] as String? ?? 'غير معروف';
                break;
              }
            }

            return {
              'id': doc.id,
              'hostId': data['hostId'],
              'hostName': hostName,
              'playersCount': players.length,
              'maxPlayers': data['maxPlayers'],
              'createdAt': data['createdAt'],
            };
          }).toList();

      result['success'] = true;
      print('✅ تم العثور على ${result['rooms'].length} غرفة متاحة');
    } catch (e) {
      result['error'] = 'فشل في البحث عن الغرف: $e';
      print('❌ فشل في البحث عن الغرف: $e');
    }

    return result;
  }
}
