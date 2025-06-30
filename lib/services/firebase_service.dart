import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/challenge.dart';
import '../models/game_room.dart';
import '../models/question.dart';

// enum لنتائج إضافة الأسئلة
enum QuestionAddResult {
  success, // تم إضافة السؤال بنجاح
  duplicate, // السؤال موجود مسبقاً
  error, // حدث خطأ أثناء الإضافة
}

// enum لنتائج إضافة التحديات
enum ChallengeAddResult {
  success, // تم إضافة التحدي بنجاح
  duplicate, // التحدي موجود مسبقاً
  error, // حدث خطأ أثناء الإضافة
}

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

  // مفاتيح SharedPreferences للغرفة الأخيرة
  static const String _lastRoomCodeKey = 'last_room_code';
  static const String _lastPlayerNameKey = 'last_player_name';
  static const String _lastIsHostKey = 'last_is_host';

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
    // محاولة تحميل من Firebase أولاً، ثم المحلي كاحتياطي
    return await loadQuestionsFromFirebase(count: count);
  }

  // Create a new game room
  Future<GameRoom?> createRoom(
    String hostName,
    int maxPlayers, {
    int questionsCount = 10,
    int? timerDuration, // المدة الزمنية لكل سؤال بالثواني
  }) async {
    try {
      print('🚀 بدء إنشاء الغرفة...');
      print('اسم اللاعب: $hostName');
      print('عدد اللاعبين الأقصى: $maxPlayers');
      print('عدد الأسئلة: $questionsCount');
      print('مدة السؤال: ${timerDuration ?? 'غير محدد'} ثانية');

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
        timerDuration: timerDuration,
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

          // حفظ بيانات الغرفة محلياً
          await _saveLastRoomData(roomCode, hostName, true);
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
            final verifyData = verifyDoc.data();
            if (verifyData != null && verifyData is Map<String, dynamic>) {
              final savedPlayers =
                  verifyData['players'] as List<dynamic>? ?? [];
              print(
                '✅ تم التحقق من حفظ البيانات - عدد اللاعبين: ${savedPlayers.length}',
              );

              // حفظ بيانات الغرفة محلياً
              await _saveLastRoomData(roomCode, playerName, false);
            }
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

      // تهيئة نظام الدوران للعبة الجديدة
      final totalPlayers = room.players.length;
      List<int> availableIndices = List.generate(
        totalPlayers,
        (index) => index,
      );
      availableIndices.remove(0); // إزالة اللاعب الأول (سيبدأ هو)

      await _roomsCollection.doc(roomCode).update({
        'state': GameState.inProgress.index,
        'availablePlayerIndices': availableIndices,
        'lastPlayerIndex': null, // لا يوجد لاعب سابق في البداية
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

      // Update score if correct and clear selected answers
      final updatedPlayers =
          room.players.map((player) {
            if (player.id == userId && isCorrect) {
              return player.copyWith(
                score: player.score + 1,
                selectedAnswer: null,
              );
            }
            return player.copyWith(selectedAnswer: null);
          }).toList();

      Map<String, dynamic> updateData = {
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
      };

      if (isCorrect) {
        // إجابة صحيحة: الانتقال للسؤال التالي + تغيير الدور
        final nextQuestionIndex = room.currentQuestionIndex + 1;

        // اختيار اللاعب التالي بنفس نظام اللعب المحلي المحسّن
        final nextPlayerIndex = _selectNextPlayerIndex(room);

        updateData.addAll({
          'currentQuestionIndex': nextQuestionIndex,
          'currentPlayerIndex': nextPlayerIndex,
        });

        // تحديث بيانات الدوران
        await _updateRotationData(roomCode, room, nextPlayerIndex);

        // إذا انتهت الأسئلة، إنهاء اللعبة
        if (nextQuestionIndex >= room.questions.length) {
          updateData['state'] = GameState.finished.index;
        }
      } else {
        // إجابة خاطئة: تغيير الدور فقط (نفس السؤال)
        final nextPlayerIndex = _selectNextPlayerIndex(room);
        updateData['currentPlayerIndex'] = nextPlayerIndex;

        // تحديث بيانات الدوران
        await _updateRotationData(roomCode, room, nextPlayerIndex);
      }

      await _roomsCollection.doc(roomCode).update(updateData);
      return true;
    } catch (e) {
      print('Error processing answer: $e');
      return false;
    }
  }

  // اختيار اللاعب التالي بنفس نظام اللعب المحلي المحسّن
  int _selectNextPlayerIndex(GameRoom room) {
    final currentIndex = room.currentPlayerIndex;
    final totalPlayers = room.players.length;

    if (totalPlayers <= 1) return currentIndex;

    // الحصول على القوائم المحفوظة أو إنشاء جديدة
    List<int> availableIndices =
        room.availablePlayerIndices != null
            ? List.from(room.availablePlayerIndices!)
            : List.generate(totalPlayers, (index) => index);

    int? lastPlayerIndex = room.lastPlayerIndex;

    // إزالة اللاعب الحالي من المتاحين
    availableIndices.remove(currentIndex);

    // إذا انتهت القائمة، إعادة تهيئة الجولة
    if (availableIndices.isEmpty) {
      availableIndices = List.generate(totalPlayers, (index) => index);
      lastPlayerIndex = null; // مسح السجل للجولة الجديدة
    }

    // إنشاء قائمة اللاعبين المؤهلين (استبعاد اللاعب السابق إذا أمكن)
    List<int> eligiblePlayers = List.from(availableIndices);

    // إذا كان هناك أكثر من لاعب متاح ولاعب سابق، استبعد اللاعب السابق
    if (eligiblePlayers.length > 1 && lastPlayerIndex != null) {
      eligiblePlayers.remove(lastPlayerIndex);
    }

    // إذا لم يعد هناك لاعبين مؤهلين، استخدم جميع المتاحين
    if (eligiblePlayers.isEmpty) {
      eligiblePlayers = List.from(availableIndices);
    }

    // اختيار عشوائي من المؤهلين
    final random = Random();
    final randomIndex = random.nextInt(eligiblePlayers.length);
    final selectedPlayer = eligiblePlayers[randomIndex];

    return selectedPlayer;
  }

  // تحديث بيانات الدوران في Firebase
  Future<void> _updateRotationData(
    String roomCode,
    GameRoom room,
    int nextPlayerIndex,
  ) async {
    List<int> availableIndices =
        room.availablePlayerIndices != null
            ? List.from(room.availablePlayerIndices!)
            : List.generate(room.players.length, (index) => index);

    // إزالة اللاعب المختار من المتاحين
    availableIndices.remove(nextPlayerIndex);

    // إذا انتهت القائمة، إعادة تهيئة
    if (availableIndices.isEmpty) {
      availableIndices = List.generate(room.players.length, (index) => index);
      availableIndices.remove(nextPlayerIndex);
    }

    await _roomsCollection.doc(roomCode).update({
      'availablePlayerIndices': availableIndices,
      'lastPlayerIndex': room.currentPlayerIndex,
    });
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

  // إكمال التحدي والانتقال للاعب التالي
  Future<bool> completeChallengeAndSwitchTurn(String roomCode) async {
    try {
      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final room = GameRoom.fromFirestore(roomDoc);

      // اختيار اللاعب التالي عشوائياً (تجنب نفس اللاعب)
      int nextPlayerIndex = room.currentPlayerIndex;
      if (room.players.length > 1) {
        List<int> availableIndices = [];
        for (int i = 0; i < room.players.length; i++) {
          if (i != room.currentPlayerIndex) {
            availableIndices.add(i);
          }
        }
        if (availableIndices.isNotEmpty) {
          final random = Random();
          nextPlayerIndex =
              availableIndices[random.nextInt(availableIndices.length)];
        }
      }

      await _roomsCollection.doc(roomCode).update({
        'currentChallenge': null,
        'currentPlayerIndex': nextPlayerIndex,
      });

      return true;
    } catch (e) {
      print('Error completing challenge and switching turn: $e');
      return false;
    }
  }

  // تحديث الدور الحالي في Firebase
  Future<bool> updateCurrentPlayer(String roomCode, int playerIndex) async {
    try {
      await _roomsCollection.doc(roomCode).update({
        'currentPlayerIndex': playerIndex,
      });
      return true;
    } catch (e) {
      print('Error updating current player: $e');
      return false;
    }
  }

  // Leave room - تعيين حالة غير متصل بدلاً من الحذف
  Future<bool> leaveRoom(String roomCode, {bool permanentLeave = false}) async {
    try {
      print('🚪 بدء عملية مغادرة الغرفة: $roomCode (نهائية: $permanentLeave)');
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) {
        print('❌ الغرفة غير موجودة أو محذوفة مسبقاً');
        await _clearLastRoomData(); // حذف البيانات المحفوظة
        return true;
      }

      final room = GameRoom.fromFirestore(roomDoc);
      print('👥 عدد اللاعبين الحالي: ${room.players.length}');

      // التحقق من وجود اللاعب في الغرفة
      final playerIndex = room.players.indexWhere(
        (player) => player.id == userId,
      );
      if (playerIndex == -1) {
        print('ℹ️ اللاعب غير موجود في الغرفة مسبقاً');
        await _clearLastRoomData();
        return true;
      }

      final currentPlayer = room.players[playerIndex];

      if (permanentLeave) {
        // مغادرة نهائية: حذف اللاعب تماماً
        print('🚪 مغادرة نهائية - حذف اللاعب من الغرفة');

        // حذف البيانات المحفوظة
        await _clearLastRoomData();

        // إذا كان هذا هو اللاعب الوحيد، احذف الغرفة مباشرة
        if (room.players.length <= 1) {
          print('🗑️ آخر لاعب يغادر - حذف الغرفة تلقائياً');
          await _roomsCollection.doc(roomCode).delete();
          return true;
        }

        // إذا كان المضيف يغادر نهائياً، نقل المضيف لآخر
        if (currentPlayer.isHost) {
          final remainingPlayers =
              room.players.where((p) => p.id != userId).toList();
          if (remainingPlayers.isNotEmpty) {
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
          }
        } else {
          // لاعب عادي يغادر نهائياً
          final updatedPlayers =
              room.players.where((p) => p.id != userId).toList();
          await _roomsCollection.doc(roomCode).update({
            'players': updatedPlayers.map((p) => p.toMap()).toList(),
          });
        }
      } else {
        // مغادرة مؤقتة: تعيين حالة غير متصل فقط
        print('📱 مغادرة مؤقتة - تعيين حالة غير متصل');

        final updatedPlayers =
            room.players.map((player) {
              if (player.id == userId) {
                return player.copyWith(
                  isOnline: false,
                  lastSeen: DateTime.now(),
                );
              }
              return player;
            }).toList();

        await _roomsCollection.doc(roomCode).update({
          'players': updatedPlayers.map((p) => p.toMap()).toList(),
        });

        print('✅ تم تعيين حالة غير متصل للاعب');
      }

      return true;
    } catch (e) {
      print('❌ خطأ في مغادرة الغرفة: $e');
      print('🔍 نوع الخطأ: ${e.runtimeType}');
      print('📄 تفاصيل الخطأ: ${e.toString()}');
      return false;
    }
  }

  // مغادرة نهائية للغرفة (حذف اللاعب تماماً)
  Future<bool> permanentLeaveRoom(String roomCode) async {
    return await leaveRoom(roomCode, permanentLeave: true);
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

      final roomData = roomDoc.data();
      if (roomData == null || roomData is! Map<String, dynamic>) {
        print('⚠️ بيانات الغرفة فارغة أو تالفة - حذف الغرفة');
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
          final roomData = doc.data();
          if (roomData == null || roomData is! Map<String, dynamic>) {
            print('⚠️ بيانات الغرفة ${doc.id} تالفة - تم تخطيها');
            continue;
          }
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
          final roomData = doc.data();
          if (roomData == null || roomData is! Map<String, dynamic>) {
            print('⚠️ بيانات الغرفة ${doc.id} تالفة - تم تخطيها');
            continue;
          }
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
          final roomData = doc.data();
          if (roomData == null || roomData is! Map<String, dynamic>) {
            print('⚠️ بيانات الغرفة ${doc.id} تالفة - تم تخطيها');
            continue;
          }
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

      final roomData = roomDoc.data();
      if (roomData == null || roomData is! Map<String, dynamic>) {
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
          querySnapshot.docs
              .map((doc) {
                final data = doc.data();
                if (data == null || data is! Map<String, dynamic>) {
                  return null;
                }

                print('📄 معالجة غرفة: ${doc.id}');

                // إرسال البيانات الكاملة للغرفة
                final roomData = {
                  'id': doc.id,
                  'hostId': data['hostId'],
                  'players': data['players'] ?? [],
                  'maxPlayers': data['maxPlayers'] ?? 4,
                  'state': data['state'] ?? 0,
                  'questions': data['questions'] ?? [],
                  'currentQuestionIndex': data['currentQuestionIndex'] ?? 0,
                  'currentPlayerIndex': data['currentPlayerIndex'] ?? 0,
                  'createdAt': data['createdAt'],
                  'timerDuration': data['timerDuration'],
                };

                print(
                  '👥 عدد اللاعبين: ${(data['players'] as List?)?.length ?? 0}',
                );
                print(
                  '❓ عدد الأسئلة: ${(data['questions'] as List?)?.length ?? 0}',
                );
                print('🎯 الحد الأقصى للاعبين: ${data['maxPlayers'] ?? 4}');

                return roomData;
              })
              .where((room) => room != null)
              .toList();

      result['success'] = true;
      print('✅ تم العثور على ${result['rooms'].length} غرفة متاحة');
      print('📊 إجمالي البيانات المُرسلة: ${result['rooms'].length} غرفة');

      // طباعة تفاصيل كل غرفة للتأكد
      for (int i = 0; i < result['rooms'].length; i++) {
        final room = result['rooms'][i];
        print('🏠 غرفة ${i + 1}: ${room['id']}');
        print(
          '   👥 لاعبين: ${(room['players'] as List).length}/${room['maxPlayers']}',
        );
        print('   ❓ أسئلة: ${(room['questions'] as List).length}');
      }
    } catch (e) {
      result['error'] = 'فشل في البحث عن الغرف: $e';
      print('❌ فشل في البحث عن الغرف: $e');
    }

    return result;
  }

  // طرد لاعب من الغرفة (للمضيف فقط)
  Future<bool> kickPlayer(String roomCode, String playerIdToKick) async {
    try {
      print('🥾 بدء عملية طرد اللاعب: $playerIdToKick من الغرفة: $roomCode');
      final userId = currentUserId;

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) {
        print('❌ الغرفة غير موجودة');
        return false;
      }

      final room = GameRoom.fromFirestore(roomDoc);

      // التحقق من أن المستخدم الحالي هو المضيف
      if (room.hostId != userId) {
        print('❌ فقط المضيف يمكنه طرد اللاعبين');
        return false;
      }

      // التحقق من أن اللاعب المراد طرده موجود في الغرفة
      final playerExists = room.players.any(
        (player) => player.id == playerIdToKick,
      );
      if (!playerExists) {
        print('❌ اللاعب المراد طرده غير موجود في الغرفة');
        return false;
      }

      // التأكد من أن المضيف لا يحاول طرد نفسه
      if (playerIdToKick == userId) {
        print('❌ المضيف لا يمكنه طرد نفسه');
        return false;
      }

      // إزالة اللاعب من قائمة اللاعبين
      final updatedPlayers =
          room.players.where((player) => player.id != playerIdToKick).toList();

      print('👥 تحديث قائمة اللاعبين: ${updatedPlayers.length} لاعب متبقي');

      await _roomsCollection.doc(roomCode).update({
        'players': updatedPlayers.map((p) => p.toMap()).toList(),
      });

      print('✅ تم طرد اللاعب بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في طرد اللاعب: $e');
      return false;
    }
  }

  // تحديث حالة اللاعب (متصل/غير متصل)
  Future<bool> updatePlayerStatus(String roomCode, bool isOnline) async {
    try {
      print('🔄 تحديث حالة الاتصال: $isOnline للغرفة: $roomCode');

      final userId = currentUserId;
      final roomRef = _roomsCollection.doc(roomCode);

      // استخدام الترانزاكشن لضمان التحديث الآمن
      await _firestore.runTransaction((transaction) async {
        final roomDoc = await transaction.get(roomRef);

        if (!roomDoc.exists) {
          print('❌ الغرفة غير موجودة');
          return;
        }

        final data = roomDoc.data();
        if (data == null || data is! Map<String, dynamic>) {
          print('❌ بيانات الغرفة تالفة');
          return;
        }
        final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

        // البحث عن اللاعب وتحديث حالته
        for (int i = 0; i < players.length; i++) {
          if (players[i]['id'] == userId) {
            players[i]['isOnline'] = isOnline;
            players[i]['lastSeen'] = FieldValue.serverTimestamp();
            break;
          }
        }

        // تحديث الغرفة
        transaction.update(roomRef, {
          'players': players,
          'lastActivity': FieldValue.serverTimestamp(),
        });
      });

      print('✅ تم تحديث حالة الاتصال بنجاح');
      return true;
    } catch (e) {
      print('⚠️ خطأ في تحديث حالة الاتصال: $e');
      return false;
    }
  }

  // تحديث حالة اتصال اللاعبين بناءً على آخر نشاط (بدون إزالة من الغرفة)
  Future<bool> removeInactivePlayers(String roomCode) async {
    try {
      print('🔄 تحديث حالات اتصال اللاعبين في الغرفة: $roomCode');

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final room = GameRoom.fromFirestore(roomDoc);
      final now = DateTime.now();
      bool hasChanges = false;

      // تحديث حالة اللاعبين بناءً على آخر نشاط (بدون إزالة أحد)
      final updatedPlayers =
          room.players.map((player) {
            // إذا كان اللاعب الحالي، اتركه كمتصل دائماً
            if (player.id == currentUserId) {
              if (!player.isOnline) {
                hasChanges = true;
                return player.copyWith(isOnline: true, lastSeen: now);
              }
              return player.copyWith(lastSeen: now);
            }

            // للاعبين الآخرين، تحقق من آخر نشاط
            if (player.lastSeen != null) {
              final timeSinceLastSeen = now.difference(player.lastSeen!);
              final shouldBeOffline = timeSinceLastSeen.inSeconds > 8;

              if (player.isOnline && shouldBeOffline) {
                print(
                  '📴 اللاعب ${player.name} أصبح غير متصل (آخر نشاط: ${timeSinceLastSeen.inSeconds} ثانية)',
                );
                hasChanges = true;
                return player.copyWith(isOnline: false);
              } else if (!player.isOnline && !shouldBeOffline) {
                print('📱 اللاعب ${player.name} أصبح متصل');
                hasChanges = true;
                return player.copyWith(isOnline: true);
              }
            } else if (player.isOnline) {
              // إذا لم يكن لديه وقت آخر مشاهدة وهو متصل، اجعله غير متصل
              print('📴 اللاعب ${player.name} بدون آخر نشاط - غير متصل');
              hasChanges = true;
              return player.copyWith(isOnline: false);
            }

            return player;
          }).toList();

      // إذا كان هناك تغييرات في حالة الاتصال، حدث الغرفة
      if (hasChanges) {
        await _roomsCollection.doc(roomCode).update({
          'players': updatedPlayers.map((p) => p.toMap()).toList(),
          'lastActivity': FieldValue.serverTimestamp(),
        });

        final onlineCount = updatedPlayers.where((p) => p.isOnline).length;
        final offlineCount = updatedPlayers.length - onlineCount;
        print(
          '✅ تم تحديث حالات الاتصال - متصل: $onlineCount، غير متصل: $offlineCount',
        );
      }

      return true;
    } catch (e) {
      print('❌ خطأ في تحديث حالات اتصال اللاعبين: $e');
      return false;
    }
  }

  // إزالة اللاعبين الذين غادروا نهائياً من الغرفة (معطلة حالياً)
  // تم تعطيل هذه الوظيفة بناءً على طلب المستخدم - لا إزالة تلقائية للاعبين
  Future<bool> removeDisconnectedPlayers(
    String roomCode, {
    int disconnectedTimeoutMinutes = 30,
  }) async {
    try {
      print('🧹 تم تعطيل إزالة اللاعبين المنقطعين - الوظيفة غير فعالة');

      // تم تعليق الكود التالي بناءً على طلب المستخدم
      // لعدم الرغبة في الإزالة التلقائية للاعبين
      /*
      print('🧹 إزالة اللاعبين المنقطعين لفترة طويلة من الغرفة: $roomCode');

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) return false;

      final room = GameRoom.fromFirestore(roomDoc);
      final now = DateTime.now();
      final cutoffTime = now.subtract(
        Duration(minutes: disconnectedTimeoutMinutes),
      );

      // البحث عن اللاعبين الذين انقطعوا لفترة طويلة جداً (30 دقيقة افتراضياً)
      final activePlayers =
          room.players.where((player) {
            // احتفظ باللاعب الحالي دائماً
            if (player.id == currentUserId) return true;

            // احتفظ باللاعبين المتصلين
            if (player.isOnline) return true;

            // احتفظ باللاعبين الذين انقطعوا لفترة قصيرة
            if (player.lastSeen != null &&
                player.lastSeen!.isAfter(cutoffTime)) {
              return true;
            }

            // إزالة اللاعبين الذين انقطعوا لفترة طويلة جداً
            print(
              '🗑️ إزالة اللاعب ${player.name} - منقطع لأكثر من $disconnectedTimeoutMinutes دقيقة',
            );
            return false;
          }).toList();

      // إذا لم يتغير عدد اللاعبين، لا حاجة للتحديث
      if (activePlayers.length == room.players.length) {
        return true;
      }

      // إذا لم يبق أي لاعبين، احذف الغرفة
      if (activePlayers.isEmpty) {
        print('🗑️ لا يوجد لاعبين نشطين - حذف الغرفة');
        await _roomsCollection.doc(roomCode).delete();
        return true;
      }

      // إذا بقي لاعب واحد فقط في اللعبة، انته اللعبة
      if (activePlayers.length == 1 && room.state == GameState.inProgress) {
        print('🏆 لاعب واحد متبقي في اللعبة - إنهاء اللعبة');
        await _roomsCollection.doc(roomCode).update({
          'players': activePlayers.map((p) => p.toMap()).toList(),
          'state': GameState.finished.index,
          'winner': activePlayers.first.id,
          'endReason': 'single_player_remaining',
        });
        return true;
      }

      // تحديث قائمة اللاعبين النشطين
      await _roomsCollection.doc(roomCode).update({
        'players': activePlayers.map((p) => p.toMap()).toList(),
      });

      print(
        '✅ تم إزالة ${room.players.length - activePlayers.length} لاعب منقطع لفترة طويلة',
      );
      */

      return true;
    } catch (e) {
      print('❌ خطأ في إزالة اللاعبين المنقطعين: $e');
      return false;
    }
  }

  // مراقبة دورية لحالة اتصال اللاعبين (تحديث حالة الاتصال فقط بدون إزالة)
  Timer? _inactivityTimer;

  Future<void> startInactivityMonitoring(String roomCode) async {
    // إيقاف أي مراقبة سابقة
    _inactivityTimer?.cancel();

    // مراقبة أسرع كل 5 ثوانٍ لاكتشاف انقطاع الاتصال بسرعة
    _inactivityTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      try {
        // التحقق من وجود الغرفة
        final roomDoc = await _roomsCollection.doc(roomCode).get();
        if (!roomDoc.exists) {
          timer.cancel();
          return;
        }

        final room = GameRoom.fromFirestore(roomDoc);

        // إذا انتهت اللعبة، أوقف المراقبة
        if (room.state == GameState.finished) {
          timer.cancel();
          return;
        }

        // تحديث حالة اللاعب الحالي كمتصل
        await updatePlayerStatus(roomCode, true);

        // تحديث حالات اتصال جميع اللاعبين (بدون إزالة أحد)
        await removeInactivePlayers(roomCode);
      } catch (e) {
        print('⚠️ خطأ في المراقبة الدورية: $e');
      }
    });
  }

  // إيقاف مراقبة عدم النشاط
  void stopInactivityMonitoring() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  // مراقبة دورية للتنظيف (تم تعطيل إزالة اللاعبين المنقطعين)
  Timer? _cleanupTimer;

  Future<void> startPeriodicCleanup(String roomCode) async {
    // إيقاف أي تنظيف سابق
    _cleanupTimer?.cancel();

    // تنظيف دوري كل 10 دقائق (تم تعطيل إزالة اللاعبين)
    _cleanupTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        // التحقق من وجود الغرفة
        final roomDoc = await _roomsCollection.doc(roomCode).get();
        if (!roomDoc.exists) {
          timer.cancel();
          return;
        }

        final room = GameRoom.fromFirestore(roomDoc);

        // إذا انتهت اللعبة، أوقف التنظيف
        if (room.state == GameState.finished) {
          timer.cancel();
          return;
        }

        // تم تعطيل إزالة اللاعبين المنقطعين لفترة طويلة حسب طلب المستخدم
        // await removeDisconnectedPlayers(roomCode);
        print('🔄 التنظيف الدوري نشط (إزالة اللاعبين معطلة)');
      } catch (e) {
        print('⚠️ خطأ في التنظيف الدوري: $e');
      }
    });
  }

  // إيقاف التنظيف الدوري
  void stopPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  // حفظ بيانات الغرفة الأخيرة محلياً
  Future<void> _saveLastRoomData(
    String roomCode,
    String playerName,
    bool isHost,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastRoomCodeKey, roomCode);
      await prefs.setString(_lastPlayerNameKey, playerName);
      await prefs.setBool(_lastIsHostKey, isHost);
      print('💾 تم حفظ بيانات الغرفة الأخيرة: $roomCode');
    } catch (e) {
      print('⚠️ خطأ في حفظ بيانات الغرفة: $e');
    }
  }

  // استرداد بيانات الغرفة الأخيرة
  Future<Map<String, dynamic>?> getLastRoomData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomCode = prefs.getString(_lastRoomCodeKey);
      final playerName = prefs.getString(_lastPlayerNameKey);
      final isHost = prefs.getBool(_lastIsHostKey) ?? false;

      if (roomCode != null && playerName != null) {
        // التحقق من وجود الغرفة وأن اللاعب لا يزال بها
        final roomDoc = await _roomsCollection.doc(roomCode).get();
        if (roomDoc.exists) {
          final room = GameRoom.fromFirestore(roomDoc);
          final playerExists = room.players.any((p) => p.id == currentUserId);

          if (playerExists && room.state != GameState.finished) {
            return {
              'roomCode': roomCode,
              'playerName': playerName,
              'isHost': isHost,
              'room': room,
            };
          }
        }
      }
    } catch (e) {
      print('⚠️ خطأ في استرداد بيانات الغرفة الأخيرة: $e');
    }

    // حذف البيانات المحفوظة إذا لم تعد صالحة
    await _clearLastRoomData();
    return null;
  }

  // حذف بيانات الغرفة المحفوظة
  Future<void> _clearLastRoomData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastRoomCodeKey);
      await prefs.remove(_lastPlayerNameKey);
      await prefs.remove(_lastIsHostKey);
      print('🗑️ تم حذف بيانات الغرفة المحفوظة');
    } catch (e) {
      print('⚠️ خطأ في حذف بيانات الغرفة: $e');
    }
  }

  // دالة عامة لحذف بيانات الغرفة المحفوظة
  Future<void> clearLastRoomData() async {
    await _clearLastRoomData();
  }

  // العودة للغرفة باستخدام البيانات المحفوظة
  Future<GameRoom?> rejoinRoom(String roomCode, String playerName) async {
    try {
      print('🔄 محاولة العودة للغرفة: $roomCode');

      final roomDoc = await _roomsCollection.doc(roomCode).get();
      if (!roomDoc.exists) {
        print('❌ الغرفة غير موجودة');
        return null;
      }

      final room = GameRoom.fromFirestore(roomDoc);
      final userId = currentUserId;

      // البحث عن اللاعب في الغرفة
      final existingPlayerIndex = room.players.indexWhere(
        (p) => p.id == userId,
      );

      if (existingPlayerIndex != -1) {
        // تحديث حالة الاتصال للاعب الموجود
        await updatePlayerStatus(roomCode, true);
        print('✅ تم العودة للغرفة كلاعب موجود');
        return room;
      } else {
        // محاولة الانضمام كلاعب جديد (إذا كانت الغرفة غير ممتلئة)
        print('🔄 محاولة الانضمام كلاعب جديد...');
        return await joinRoom(roomCode, playerName);
      }
    } catch (e) {
      print('⚠️ خطأ في العودة للغرفة: $e');
      return null;
    }
  }

  // ===== إدارة الأسئلة من Firebase =====

  /// تحميل الأسئلة من Firebase مع الحفاظ على نفس هيكل JSON
  Future<List<Question>> loadQuestionsFromFirebase({int count = 10}) async {
    try {
      print('📚 جاري تحميل الأسئلة من Firebase...');

      final snapshot = await _firestore.collection('questions').get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ لا توجد أسئلة في Firebase، سيتم تحميل الأسئلة المحلية');
        return await _loadLocalQuestions(count: count);
      }

      final questions =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return Question(
              id: doc.id,
              questionText: data['question'] ?? '',
              options: List<String>.from(data['options'] ?? []),
              correctAnswerIndex: data['correct_answer'] ?? 0,
              category: data['category'] ?? 'معلومات عامة',
              usageCount: data['usage_count'] ?? 0,
              source: data['source'] ?? 'firebase',
            );
          }).toList();

      // خلط الأسئلة واختيار العدد المطلوب
      final random = Random();
      questions.shuffle(random);
      final selectedQuestions = questions.take(count).toList();

      print('✅ تم تحميل ${selectedQuestions.length} سؤال من Firebase');
      return selectedQuestions;
    } catch (e) {
      print('❌ خطأ في تحميل الأسئلة من Firebase: $e');
      print('🔄 العودة للأسئلة المحلية...');
      return await _loadLocalQuestions(count: count);
    }
  }

  /// تحميل الأسئلة المحلية كاحتياطي
  Future<List<Question>> _loadLocalQuestions({int count = 10}) async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/questions.json',
      );
      final List<dynamic> jsonData = json.decode(response);

      final questions =
          jsonData.map((json) => Question.fromJson(json)).toList();

      // خلط الأسئلة واختيار العدد المطلوب
      final random = Random();
      questions.shuffle(random);
      return questions.take(count).toList();
    } catch (e) {
      print('❌ خطأ في تحميل الأسئلة المحلية: $e');
      return [];
    }
  }

  /// تحميل أسئلة حسب الفئة
  Future<List<Question>> loadQuestionsByCategory(
    String category, {
    int count = 10,
  }) async {
    try {
      print('📚 جاري تحميل أسئلة فئة: $category');

      final snapshot =
          await _firestore
              .collection('questions')
              .where('category', isEqualTo: category)
              .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ لا توجد أسئلة في فئة $category، جاري تحميل جميع الأسئلة');
        return await loadQuestionsFromFirebase(count: count);
      }

      final questions =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return Question(
              id: doc.id,
              questionText: data['question'] ?? '',
              options: List<String>.from(data['options'] ?? []),
              correctAnswerIndex: data['correct_answer'] ?? 0,
              category: data['category'] ?? 'معلومات عامة',
              usageCount: data['usage_count'] ?? 0,
              source: data['source'] ?? 'firebase',
            );
          }).toList();

      // خلط الأسئلة واختيار العدد المطلوب
      final random = Random();
      questions.shuffle(random);
      final selectedQuestions = questions.take(count).toList();

      print('✅ تم تحميل ${selectedQuestions.length} سؤال من فئة $category');
      return selectedQuestions;
    } catch (e) {
      print('❌ خطأ في تحميل أسئلة الفئة $category: $e');
      return await loadQuestionsFromFirebase(count: count);
    }
  }

  /// تحميل الفئات المتاحة
  Future<List<String>> loadCategories() async {
    try {
      print('📚 جاري تحميل الفئات المتاحة...');

      final snapshot = await _firestore.collection('questions').get();

      final categories = <String>{};

      for (final doc in snapshot.docs) {
        final category = doc.data()['category'] as String?;
        if (category != null && category.isNotEmpty) {
          categories.add(category);
        }
      }

      final categoriesList = categories.toList()..sort();
      print('✅ تم تحميل ${categoriesList.length} فئة: $categoriesList');
      return categoriesList;
    } catch (e) {
      print('❌ خطأ في تحميل الفئات: $e');
      return [
        'معلومات عامة',
        'رياضة',
        'ديني',
        'أفلام',
        'تكنولوجيا',
        'ألغاز منطقية',
        'علوم',
        'ثقافة',
      ];
    }
  }

  /// رفع الأسئلة المحلية إلى Firebase (للمشرفين)
  Future<bool> uploadLocalQuestionsToFirebase() async {
    try {
      print('📤 جاري رفع الأسئلة المحلية إلى Firebase...');

      // تحميل الأسئلة المحلية
      final String response = await rootBundle.loadString(
        'assets/data/questions.json',
      );
      final List<dynamic> jsonData = json.decode(response);

      // تحميل الأسئلة الموجودة في Firebase للمقارنة
      print('🔍 جاري فحص الأسئلة الموجودة في Firebase...');
      final existingSnapshot = await _firestore.collection('questions').get();

      // تحميل الأسئلة المحذوفة من Firebase
      print('🗑️ جاري فحص الأسئلة المحذوفة...');
      final deletedSnapshot =
          await _firestore.collection('deleted_questions').get();

      // إنشاء مجموعة من الأسئلة الموجودة للمقارنة السريعة
      final existingQuestions = <String>{};
      for (final doc in existingSnapshot.docs) {
        final data = doc.data();
        final questionText = data['question'] as String? ?? '';
        if (questionText.isNotEmpty) {
          // استخدام نص السؤال كمعرف فريد (بعد تنظيفه)
          existingQuestions.add(_normalizeQuestionText(questionText));
        }
      }

      // إنشاء مجموعة من الأسئلة المحذوفة للتحقق منها
      final deletedQuestions = <String>{};
      for (final doc in deletedSnapshot.docs) {
        final data = doc.data();
        final questionText = data['question_text'] as String? ?? '';
        if (questionText.isNotEmpty) {
          deletedQuestions.add(_normalizeQuestionText(questionText));
        }
      }

      print(
        '📊 تم العثور على ${existingQuestions.length} سؤال موجود في Firebase',
      );
      print('🗑️ تم العثور على ${deletedQuestions.length} سؤال محذوف');

      int successCount = 0;
      int duplicateCount = 0;
      int deletedCount = 0;
      int errorCount = 0;

      for (final questionData in jsonData) {
        try {
          final questionText = questionData['question'] as String? ?? '';
          final normalizedText = _normalizeQuestionText(questionText);

          // فحص ما إذا كان السؤال محذوف مسبقاً
          if (deletedQuestions.contains(normalizedText)) {
            print(
              '🗑️ تم تخطي سؤال محذوف مسبقاً: ${questionText.substring(0, 50)}...',
            );
            deletedCount++;
            continue;
          }

          // فحص ما إذا كان السؤال موجود مسبقاً
          if (existingQuestions.contains(normalizedText)) {
            print('⏭️ تم تخطي سؤال مكرر: ${questionText.substring(0, 50)}...');
            duplicateCount++;
            continue;
          }

          // رفع السؤال إذا لم يكن موجوداً أو محذوفاً
          await _firestore.collection('questions').add({
            'question': questionText,
            'options': questionData['options'],
            'correct_answer': questionData['correct_answer'],
            'category': questionData['category'],
            'created_at': FieldValue.serverTimestamp(),
            'usage_count': 0,
            'source': 'local_upload',
            'question_hash': _generateQuestionHash(
              questionText,
            ), // إضافة hash للسؤال
          });

          // إضافة السؤال للمجموعة لتجنب التكرار في نفس العملية
          existingQuestions.add(normalizedText);
          successCount++;

          print('✅ تم رفع سؤال جديد: ${questionText.substring(0, 50)}...');
        } catch (e) {
          print('❌ خطأ في رفع سؤال: $e');
          errorCount++;
        }
      }

      print('📊 نتائج الرفع:');
      print('   ✅ أسئلة جديدة: $successCount');
      print('   ⏭️ أسئلة مكررة: $duplicateCount');
      print('   🗑️ أسئلة محذوفة مسبقاً: $deletedCount');
      print('   ❌ أخطاء: $errorCount');
      print('   📝 إجمالي الأسئلة المعالجة: ${jsonData.length}');

      return successCount > 0;
    } catch (e) {
      print('❌ خطأ في رفع الأسئلة: $e');
      return false;
    }
  }

  /// تطبيع نص السؤال للمقارنة (إزالة المسافات الزائدة وتوحيد الحالة)
  String _normalizeQuestionText(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // استبدال عدة مسافات بمسافة واحدة
        .toLowerCase(); // تحويل للأحرف الصغيرة للمقارنة
  }

  /// إنشاء hash للسؤال لضمان الفرادة
  String _generateQuestionHash(String questionText) {
    // استخدام hash بسيط للسؤال
    return questionText.hashCode.toString();
  }

  /// إضافة سؤال جديد (للمشرفين فقط)
  Future<QuestionAddResult> addQuestion(Question question) async {
    try {
      print('➕ جاري إضافة سؤال جديد...');

      // فحص عدم وجود السؤال مسبقاً
      final normalizedText = _normalizeQuestionText(question.questionText);

      print('🔍 جاري فحص عدم تكرار السؤال...');
      final existingQuery =
          await _firestore
              .collection('questions')
              .where(
                'question_hash',
                isEqualTo: _generateQuestionHash(question.questionText),
              )
              .get();
      if (existingQuery.docs.isNotEmpty) {
        print('⚠️ السؤال موجود مسبقاً في قاعدة البيانات');
        return QuestionAddResult.duplicate; // السؤال موجود مسبقاً
      }

      // فحص إضافي بالبحث في نص السؤال
      final allQuestionsSnapshot =
          await _firestore.collection('questions').get();
      for (final doc in allQuestionsSnapshot.docs) {
        final data = doc.data();
        final existingQuestionText = data['question'] as String? ?? '';
        if (_normalizeQuestionText(existingQuestionText) == normalizedText) {
          print(
            '⚠️ تم العثور على سؤال مشابه: ${existingQuestionText.substring(0, 50)}...',
          );
          return QuestionAddResult.duplicate; // السؤال مشابه لسؤال موجود
        }
      }

      // إضافة السؤال إذا لم يكن موجوداً
      await _firestore.collection('questions').add({
        'question': question.questionText,
        'options': question.options,
        'correct_answer': question.correctAnswerIndex,
        'category': question.category,
        'created_at': FieldValue.serverTimestamp(),
        'usage_count': 0,
        'source': 'manual_add',
        'question_hash': _generateQuestionHash(question.questionText),
      });

      print('✅ تم إضافة السؤال بنجاح');
      return QuestionAddResult.success;
    } catch (e) {
      print('❌ خطأ في إضافة السؤال: $e');
      return QuestionAddResult.error;
    }
  }

  /// تحديث عداد استخدام السؤال
  Future<void> incrementQuestionUsage(String questionId) async {
    try {
      await _firestore.collection('questions').doc(questionId).update({
        'usage_count': FieldValue.increment(1),
        'last_used': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ خطأ في تحديث عداد الاستخدام: $e');
    }
  }

  /// الحصول على إحصائيات الأسئلة
  Future<Map<String, dynamic>> getQuestionsStats() async {
    try {
      final snapshot = await _firestore.collection('questions').get();

      int totalQuestions = snapshot.docs.length;
      int totalUsage = 0;
      final categoryStats = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final usage = data['usage_count'] as int? ?? 0;
        final category = data['category'] as String? ?? 'غير محدد';

        totalUsage += usage;
        categoryStats[category] = (categoryStats[category] ?? 0) + 1;
      }

      return {
        'total_questions': totalQuestions,
        'total_usage': totalUsage,
        'categories': categoryStats,
      };
    } catch (e) {
      print('❌ خطأ في الحصول على إحصائيات الأسئلة: $e');
      return {'total_questions': 0, 'total_usage': 0, 'categories': {}};
    }
  }

  // ===== إدارة الفئات المخصصة =====

  /// إضافة فئة جديدة
  Future<bool> addCustomCategory(
    String categoryName, {
    String? description,
    String? icon,
    Color? color,
  }) async {
    try {
      print('➕ جاري إضافة فئة جديدة: $categoryName');

      // التحقق من عدم وجود الفئة مسبقاً
      final existingCategory =
          await _firestore
              .collection('categories')
              .where('name', isEqualTo: categoryName.trim())
              .get();

      if (existingCategory.docs.isNotEmpty) {
        print('⚠️ الفئة موجودة مسبقاً');
        return false;
      }

      // إضافة الفئة الجديدة
      await _firestore.collection('categories').add({
        'name': categoryName.trim(),
        'description': description ?? '',
        'icon': icon ?? 'category',
        'color': color?.value ?? 0xFF9C27B0, // اللون الافتراضي بنفسجي
        'created_at': FieldValue.serverTimestamp(),
        'questions_count': 0,
        'usage_count': 0,
        'is_custom': true,
      });

      print('✅ تم إضافة الفئة بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في إضافة الفئة: $e');
      return false;
    }
  }

  /// حذف فئة مخصصة
  Future<bool> deleteCustomCategory(String categoryId) async {
    try {
      print('🗑️ جاري حذف الفئة: $categoryId');

      // التحقق من وجود الفئة
      final categoryDoc =
          await _firestore.collection('categories').doc(categoryId).get();
      if (!categoryDoc.exists) {
        print('❌ الفئة غير موجودة');
        return false;
      }

      final categoryData = categoryDoc.data()!;
      final categoryName = categoryData['name'] as String;
      final isCustom = categoryData['is_custom'] as bool? ?? false;

      // منع حذف الفئات الأساسية
      if (!isCustom) {
        print('❌ لا يمكن حذف الفئات الأساسية');
        return false;
      }

      // التحقق من وجود أسئلة في هذه الفئة
      final questionsInCategory =
          await _firestore
              .collection('questions')
              .where('category', isEqualTo: categoryName)
              .get();

      if (questionsInCategory.docs.isNotEmpty) {
        print('⚠️ توجد ${questionsInCategory.docs.length} أسئلة في هذه الفئة');

        // نقل الأسئلة إلى فئة "معلومات عامة"
        final batch = _firestore.batch();
        for (final doc in questionsInCategory.docs) {
          batch.update(doc.reference, {'category': 'معلومات عامة'});
        }
        await batch.commit();
        print('🔄 تم نقل الأسئلة إلى فئة "معلومات عامة"');
      }

      // حذف الفئة
      await _firestore.collection('categories').doc(categoryId).delete();
      print('✅ تم حذف الفئة بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في حذف الفئة: $e');
      return false;
    }
  }

  /// تحديث فئة مخصصة
  Future<bool> updateCustomCategory(
    String categoryId, {
    String? name,
    String? description,
    String? icon,
    Color? color,
  }) async {
    try {
      print('🔄 جاري تحديث الفئة: $categoryId');

      final updateData = <String, dynamic>{};

      if (name != null) updateData['name'] = name.trim();
      if (description != null) updateData['description'] = description;
      if (icon != null) updateData['icon'] = icon;
      if (color != null) updateData['color'] = color.value;

      updateData['updated_at'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('categories')
          .doc(categoryId)
          .update(updateData);
      print('✅ تم تحديث الفئة بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في تحديث الفئة: $e');
      return false;
    }
  }

  /// الحصول على جميع الفئات (الأساسية والمخصصة)
  Future<List<Map<String, dynamic>>> getAllCategories() async {
    try {
      print('📚 جاري تحميل جميع الفئات...');

      // الفئات الأساسية (افتراضية)
      final defaultCategories = [
        {
          'id': 'default_general',
          'name': 'معلومات عامة',
          'description': 'أسئلة ثقافية ومعلومات عامة',
          'icon': 'info',
          'color': 0xFF2196F3,
          'is_custom': false,
          'questions_count': 0,
          'usage_count': 0,
        },
        {
          'id': 'default_sports',
          'name': 'رياضة',
          'description': 'أسئلة رياضية ومعلومات عن الرياضة',
          'icon': 'sports_soccer',
          'color': 0xFF4CAF50,
          'is_custom': false,
          'questions_count': 0,
          'usage_count': 0,
        },
        {
          'id': 'default_religion',
          'name': 'ديني',
          'description': 'أسئلة دينية وإسلامية',
          'icon': 'mosque',
          'color': 0xFF8BC34A,
          'is_custom': false,
          'questions_count': 0,
          'usage_count': 0,
        },
        {
          'id': 'default_movies',
          'name': 'أفلام',
          'description': 'أسئلة أفلام وسينما وكرتون وألعاب',
          'icon': 'movie',
          'color': 0xFFFF9800,
          'is_custom': false,
          'questions_count': 0,
          'usage_count': 0,
        },
        {
          'id': 'default_technology',
          'name': 'تكنولوجيا',
          'description': 'أسئلة تقنية وحاسوب',
          'icon': 'computer',
          'color': 0xFF9C27B0,
          'is_custom': false,
          'questions_count': 0,
          'usage_count': 0,
        },
        {
          'id': 'default_logic',
          'name': 'ألغاز منطقية',
          'description': 'ألغاز وأسئلة منطقية',
          'icon': 'psychology',
          'color': 0xFFE91E63,
          'is_custom': false,
          'questions_count': 0,
          'usage_count': 0,
        },
        {
          'id': 'default_science',
          'name': 'علوم',
          'description': 'أسئلة علمية وطبيعية',
          'icon': 'science',
          'color': 0xFF00BCD4,
          'is_custom': false,
          'questions_count': 0,
          'usage_count': 0,
        },
        {
          'id': 'default_culture',
          'name': 'ثقافة',
          'description': 'أسئلة ثقافية وتاريخية',
          'icon': 'library_books',
          'color': 0xFF795548,
          'is_custom': false,
          'questions_count': 0,
          'usage_count': 0,
        },
      ];

      // الفئات المخصصة من Firebase
      final customCategoriesSnapshot =
          await _firestore.collection('categories').get();
      final customCategories =
          customCategoriesSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] ?? '',
              'description': data['description'] ?? '',
              'icon': data['icon'] ?? 'category',
              'color': data['color'] ?? 0xFF9C27B0,
              'is_custom': data['is_custom'] ?? true,
              'questions_count': data['questions_count'] ?? 0,
              'usage_count': data['usage_count'] ?? 0,
            };
          }).toList();

      // دمج الفئات الأساسية والمخصصة
      final allCategories = [...defaultCategories, ...customCategories];

      // حساب عدد الأسئلة لكل فئة
      final questionsSnapshot = await _firestore.collection('questions').get();
      final categoryQuestionCounts = <String, int>{};

      for (final doc in questionsSnapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'معلومات عامة';
        categoryQuestionCounts[category] =
            (categoryQuestionCounts[category] ?? 0) + 1;
      }

      // تحديث عدد الأسئلة لكل فئة
      for (final category in allCategories) {
        final categoryName = category['name'] as String;
        category['questions_count'] = categoryQuestionCounts[categoryName] ?? 0;
      }

      // ترتيب الفئات (الأساسية أولاً، ثم المخصصة حسب الاسم)
      allCategories.sort((a, b) {
        final aIsCustom = a['is_custom'] as bool;
        final bIsCustom = b['is_custom'] as bool;

        if (aIsCustom == bIsCustom) {
          return (a['name'] as String).compareTo(b['name'] as String);
        }
        return aIsCustom ? 1 : -1; // الأساسية أولاً
      });

      print(
        '✅ تم تحميل ${allCategories.length} فئة (${defaultCategories.length} أساسية + ${customCategories.length} مخصصة)',
      );
      return allCategories;
    } catch (e) {
      print('❌ خطأ في تحميل الفئات: $e');
      return [];
    }
  }

  /// الحصول على الأسئلة حسب الفئة مع تفاصيل إضافية
  Future<List<Map<String, dynamic>>> getQuestionsByCategory(
    String categoryName,
  ) async {
    try {
      print('📚 جاري تحميل أسئلة فئة: $categoryName');

      final snapshot =
          await _firestore
              .collection('questions')
              .where('category', isEqualTo: categoryName)
              .get();

      final questions =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'question': data['question'] ?? '',
              'options': List<String>.from(data['options'] ?? []),
              'correct_answer': data['correct_answer'] ?? 0,
              'category': data['category'] ?? 'معلومات عامة',
              'created_at': data['created_at'],
              'usage_count': data['usage_count'] ?? 0,
              'source': data['source'] ?? 'unknown',
            };
          }).toList();

      // ترتيب الأسئلة حسب تاريخ الإنشاء (الأحدث أولاً)
      questions.sort((a, b) {
        final aTime = a['created_at'] as Timestamp?;
        final bTime = b['created_at'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      print('✅ تم تحميل ${questions.length} سؤال من فئة $categoryName');
      return questions;
    } catch (e) {
      print('❌ خطأ في تحميل أسئلة الفئة: $e');
      return [];
    }
  }

  /// حذف سؤال معين
  Future<bool> deleteQuestion(String questionId) async {
    try {
      print('🗑️ جاري حذف السؤال: $questionId');

      // الحصول على بيانات السؤال قبل حذفه
      final questionDoc =
          await _firestore.collection('questions').doc(questionId).get();
      if (!questionDoc.exists) {
        print('❌ السؤال غير موجود');
        return false;
      }

      final questionData = questionDoc.data()!;
      final questionText = questionData['question'] as String;
      final questionHash = _generateQuestionHash(questionText);

      // حذف السؤال من مجموعة الأسئلة
      await _firestore.collection('questions').doc(questionId).delete();

      // إضافة السؤال المحذوف إلى مجموعة الأسئلة المحذوفة مع جميع بياناته الأصلية
      await _firestore.collection('deleted_questions').add({
        'question_id': questionId,
        'question_text': questionText,
        'question_hash': questionHash,
        'original_data': questionData, // حفظ جميع البيانات الأصلية للسؤال
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by': 'admin', // يمكن تحسين هذا لاحقاً لإضافة معرف المشرف
      });

      print('✅ تم حذف السؤال بنجاح وإضافته لقائمة المحذوفات');
      return true;
    } catch (e) {
      print('❌ خطأ في حذف السؤال: $e');
      return false;
    }
  }

  /// تحديث سؤال معين
  Future<bool> updateQuestion(
    String questionId,
    Question updatedQuestion,
  ) async {
    try {
      print('🔄 جاري تحديث السؤال: $questionId');

      await _firestore.collection('questions').doc(questionId).update({
        'question': updatedQuestion.questionText,
        'options': updatedQuestion.options,
        'correct_answer': updatedQuestion.correctAnswerIndex,
        'category': updatedQuestion.category,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('✅ تم تحديث السؤال بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في تحديث السؤال: $e');
      return false;
    }
  }

  /// البحث في الأسئلة
  Future<List<Map<String, dynamic>>> searchQuestions(String searchTerm) async {
    try {
      print('🔍 البحث عن: $searchTerm');

      final snapshot = await _firestore.collection('questions').get();
      final searchTermLower = searchTerm.toLowerCase();

      final results =
          snapshot.docs
              .where((doc) {
                final data = doc.data();
                final question =
                    (data['question'] as String? ?? '').toLowerCase();
                final category =
                    (data['category'] as String? ?? '').toLowerCase();

                return question.contains(searchTermLower) ||
                    category.contains(searchTermLower);
              })
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'question': data['question'] ?? '',
                  'options': List<String>.from(data['options'] ?? []),
                  'correct_answer': data['correct_answer'] ?? 0,
                  'category': data['category'] ?? 'معلومات عامة',
                  'created_at': data['created_at'],
                  'usage_count': data['usage_count'] ?? 0,
                  'source': data['source'] ?? 'unknown',
                };
              })
              .toList();

      print('✅ تم العثور على ${results.length} نتيجة');
      return results;
    } catch (e) {
      print('❌ خطأ في البحث: $e');
      return [];
    }
  }

  /// إحصائيات مفصلة لكل فئة
  Future<Map<String, dynamic>> getCategoryDetailedStats(
    String categoryName,
  ) async {
    try {
      print('📊 جاري حساب إحصائيات فئة: $categoryName');

      final snapshot =
          await _firestore
              .collection('questions')
              .where('category', isEqualTo: categoryName)
              .get();

      int totalQuestions = snapshot.docs.length;
      int totalUsage = 0;
      int questionsWithoutUsage = 0;
      int questionsFromLocalUpload = 0;
      int questionsFromManualAdd = 0;

      DateTime? oldestQuestion;
      DateTime? newestQuestion;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final usage = data['usage_count'] as int? ?? 0;
        final source = data['source'] as String? ?? 'unknown';
        final createdAt = (data['created_at'] as Timestamp?)?.toDate();

        totalUsage += usage;
        if (usage == 0) questionsWithoutUsage++;

        if (source == 'local_upload') questionsFromLocalUpload++;
        if (source == 'manual_add') questionsFromManualAdd++;

        if (createdAt != null) {
          if (oldestQuestion == null || createdAt.isBefore(oldestQuestion)) {
            oldestQuestion = createdAt;
          }
          if (newestQuestion == null || createdAt.isAfter(newestQuestion)) {
            newestQuestion = createdAt;
          }
        }
      }

      final stats = {
        'category_name': categoryName,
        'total_questions': totalQuestions,
        'total_usage': totalUsage,
        'average_usage':
            totalQuestions > 0 ? (totalUsage / totalQuestions).round() : 0,
        'questions_without_usage': questionsWithoutUsage,
        'questions_from_local_upload': questionsFromLocalUpload,
        'questions_from_manual_add': questionsFromManualAdd,
        'oldest_question': oldestQuestion,
        'newest_question': newestQuestion,
      };

      print('✅ تم حساب إحصائيات فئة $categoryName');
      return stats;
    } catch (e) {
      print('❌ خطأ في حساب إحصائيات الفئة: $e');
      return {
        'category_name': categoryName,
        'total_questions': 0,
        'total_usage': 0,
        'average_usage': 0,
        'questions_without_usage': 0,
        'questions_from_local_upload': 0,
        'questions_from_manual_add': 0,
        'oldest_question': null,
        'newest_question': null,
      };
    }
  }

  /// استعادة سؤال محذوف (إعادة إضافته إلى مجموعة الأسئلة العادية)
  Future<bool> restoreDeletedQuestion(String questionText) async {
    try {
      print('🔄 جاري استعادة السؤال المحذوف...');

      final normalizedText = _normalizeQuestionText(questionText);

      // البحث عن السؤال في قائمة المحذوفات
      final deletedSnapshot =
          await _firestore
              .collection('deleted_questions')
              .where(
                'question_hash',
                isEqualTo: _generateQuestionHash(questionText),
              )
              .get();

      if (deletedSnapshot.docs.isEmpty) {
        print('❌ السؤال غير موجود في قائمة المحذوفات');
        return false;
      }

      // الحصول على بيانات السؤال الأصلية
      final deletedDoc = deletedSnapshot.docs.first;
      final deletedData = deletedDoc.data();
      final originalData =
          deletedData['original_data'] as Map<String, dynamic>?;

      if (originalData == null) {
        print('❌ البيانات الأصلية للسؤال غير متوفرة');
        return false;
      }

      // فحص ما إذا كان السؤال موجود مسبقاً في مجموعة الأسئلة العادية
      final existingSnapshot =
          await _firestore
              .collection('questions')
              .where(
                'question_hash',
                isEqualTo: _generateQuestionHash(questionText),
              )
              .get();

      if (existingSnapshot.docs.isNotEmpty) {
        print('⚠️ السؤال موجود مسبقاً في مجموعة الأسئلة العادية');
        // حذف من قائمة المحذوفات فقط
        await deletedDoc.reference.delete();
        print('✅ تم حذف السؤال من قائمة المحذوفات');
        return true;
      }

      // إعادة إضافة السؤال إلى مجموعة الأسئلة العادية مع البيانات الأصلية
      final restoredData = Map<String, dynamic>.from(originalData);
      // إضافة معلومات الاستعادة
      restoredData['restored_at'] = FieldValue.serverTimestamp();
      restoredData['restored_from_deleted'] = true;
      // إزالة الحقول التي قد تكون مشكلة عند الإضافة
      restoredData.remove('id');

      await _firestore.collection('questions').add(restoredData);

      // حذف السؤال من قائمة المحذوفات
      await deletedDoc.reference.delete();

      print('✅ تم استعادة السؤال بنجاح وإضافته إلى مجموعة الأسئلة العادية');
      return true;
    } catch (e) {
      print('❌ خطأ في استعادة السؤال: $e');
      return false;
    }
  }

  /// الحصول على قائمة الأسئلة المحذوفة
  Future<List<Map<String, dynamic>>> getDeletedQuestions() async {
    try {
      print('📋 جاري تحميل قائمة الأسئلة المحذوفة...');

      final snapshot =
          await _firestore
              .collection('deleted_questions')
              .orderBy('deleted_at', descending: true)
              .get();

      final deletedQuestions =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'question_text': data['question_text'] ?? '',
              'deleted_at': data['deleted_at'],
              'deleted_by': data['deleted_by'] ?? 'unknown',
              // إضافة البيانات الأصلية للتحقق من وجودها عند الاستعادة
              'has_original_data': data['original_data'] != null,
            };
          }).toList();

      print('✅ تم تحميل ${deletedQuestions.length} سؤال محذوف');
      return deletedQuestions;
    } catch (e) {
      print('❌ خطأ في تحميل الأسئلة المحذوفة: $e');
      return [];
    }
  }

  /// تنظيف قائمة الأسئلة المحذوفة (حذف السجلات القديمة)
  Future<bool> cleanupDeletedQuestions({int daysOld = 30}) async {
    try {
      print('🧹 جاري تنظيف قائمة الأسئلة المحذوفة...');

      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final snapshot =
          await _firestore
              .collection('deleted_questions')
              .where('deleted_at', isLessThan: Timestamp.fromDate(cutoffDate))
              .get();

      int deletedCount = 0;
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
        deletedCount++;
      }

      print('✅ تم حذف $deletedCount سجل قديم من قائمة المحذوفات');
      return true;
    } catch (e) {
      print('❌ خطأ في تنظيف قائمة المحذوفات: $e');
      return false;
    }
  }

  // ===== إدارة التحديات =====

  /// تحميل التحديات من Firebase
  Future<List<Challenge>> loadChallengesFromFirebase({int count = 10}) async {
    try {
      print('🎯 جاري تحميل التحديات من Firebase...');

      final snapshot = await _firestore.collection('challenges').get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ لا توجد تحديات في Firebase');
        return [];
      }

      final challenges =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return Challenge(
              id: doc.id,
              challengeText: data['challenge'] ?? '',
              category: data['category'] ?? 'تحديات عامة',
              difficulty: data['difficulty'] ?? 'متوسط',
              usageCount: data['usage_count'] ?? 0,
              source: data['source'] ?? 'firebase',
            );
          }).toList();

      // خلط التحديات واختيار العدد المطلوب
      final random = Random();
      challenges.shuffle(random);
      final selectedChallenges = challenges.take(count).toList();

      print('✅ تم تحميل ${selectedChallenges.length} تحدي من Firebase');
      return selectedChallenges;
    } catch (e) {
      print('❌ خطأ في تحميل التحديات من Firebase: $e');
      return [];
    }
  }

  /// تحميل التحديات حسب الفئة
  Future<List<Challenge>> loadChallengesByCategory(
    String category, {
    int count = 10,
  }) async {
    try {
      print('🎯 جاري تحميل تحديات فئة: $category');

      final snapshot =
          await _firestore
              .collection('challenges')
              .where('category', isEqualTo: category)
              .get();

      if (snapshot.docs.isEmpty) {
        print('⚠️ لا توجد تحديات في فئة $category، جاري تحميل جميع التحديات');
        return await loadChallengesFromFirebase(count: count);
      }

      final challenges =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return Challenge(
              id: doc.id,
              challengeText: data['challenge'] ?? '',
              category: data['category'] ?? 'تحديات عامة',
              difficulty: data['difficulty'] ?? 'متوسط',
              usageCount: data['usage_count'] ?? 0,
              source: data['source'] ?? 'firebase',
            );
          }).toList();

      // خلط التحديات واختيار العدد المطلوب
      final random = Random();
      challenges.shuffle(random);
      final selectedChallenges = challenges.take(count).toList();

      print('✅ تم تحميل ${selectedChallenges.length} تحدي من فئة $category');
      return selectedChallenges;
    } catch (e) {
      print('❌ خطأ في تحميل تحديات الفئة $category: $e');
      return await loadChallengesFromFirebase(count: count);
    }
  }

  /// إضافة تحدي جديد
  Future<ChallengeAddResult> addChallenge(Challenge challenge) async {
    try {
      print('➕ جاري إضافة تحدي جديد...');

      // فحص عدم وجود التحدي مسبقاً
      final normalizedText = _normalizeQuestionText(challenge.challengeText);

      print('🔍 جاري فحص عدم تكرار التحدي...');
      final existingQuery =
          await _firestore
              .collection('challenges')
              .where(
                'challenge_hash',
                isEqualTo: _generateQuestionHash(challenge.challengeText),
              )
              .get();

      if (existingQuery.docs.isNotEmpty) {
        print('⚠️ التحدي موجود مسبقاً في قاعدة البيانات');
        return ChallengeAddResult.duplicate;
      }

      // فحص إضافي بالبحث في نص التحدي
      final allChallengesSnapshot =
          await _firestore.collection('challenges').get();
      for (final doc in allChallengesSnapshot.docs) {
        final data = doc.data();
        final existingChallengeText = data['challenge'] as String? ?? '';
        if (_normalizeQuestionText(existingChallengeText) == normalizedText) {
          print(
            '⚠️ تم العثور على تحدي مشابه: ${existingChallengeText.substring(0, 50)}...',
          );
          return ChallengeAddResult.duplicate;
        }
      }

      // إضافة التحدي إذا لم يكن موجوداً
      await _firestore.collection('challenges').add({
        'challenge': challenge.challengeText,
        'category': challenge.category,
        'difficulty': challenge.difficulty,
        'created_at': FieldValue.serverTimestamp(),
        'usage_count': 0,
        'source': 'manual_add',
        'challenge_hash': _generateQuestionHash(challenge.challengeText),
      });

      print('✅ تم إضافة التحدي بنجاح');
      return ChallengeAddResult.success;
    } catch (e) {
      print('❌ خطأ في إضافة التحدي: $e');
      return ChallengeAddResult.error;
    }
  }

  /// حذف تحدي معين
  Future<bool> deleteChallenge(String challengeId) async {
    try {
      print('🗑️ جاري حذف التحدي: $challengeId');

      // الحصول على بيانات التحدي قبل حذفه
      final challengeDoc =
          await _firestore.collection('challenges').doc(challengeId).get();
      if (!challengeDoc.exists) {
        print('❌ التحدي غير موجود');
        return false;
      }

      final challengeData = challengeDoc.data()!;
      final challengeText = challengeData['challenge'] as String;
      final challengeHash = _generateQuestionHash(challengeText);

      // إضافة challenge_hash إلى البيانات الأصلية إذا لم يكن موجوداً
      final originalDataWithHash = Map<String, dynamic>.from(challengeData);
      if (!originalDataWithHash.containsKey('challenge_hash')) {
        originalDataWithHash['challenge_hash'] = challengeHash;
      }

      // حذف التحدي من مجموعة التحديات
      await _firestore.collection('challenges').doc(challengeId).delete();

      // إضافة التحدي المحذوف إلى مجموعة التحديات المحذوفة مع جميع بياناته الأصلية
      await _firestore.collection('deleted_challenges').add({
        'challenge_id': challengeId,
        'challenge_text': challengeText,
        'challenge_hash': challengeHash,
        'original_data':
            originalDataWithHash, // حفظ جميع البيانات الأصلية للتحدي مع الهاش
        'deleted_at': FieldValue.serverTimestamp(),
        'deleted_by': 'admin',
      });

      print('✅ تم حذف التحدي بنجاح وإضافته لقائمة المحذوفات');
      return true;
    } catch (e) {
      print('❌ خطأ في حذف التحدي: $e');
      return false;
    }
  }

  /// تحديث تحدي معين
  Future<bool> updateChallenge(
    String challengeId,
    Challenge updatedChallenge,
  ) async {
    try {
      print('🔄 جاري تحديث التحدي: $challengeId');

      await _firestore.collection('challenges').doc(challengeId).update({
        'challenge': updatedChallenge.challengeText,
        'category': updatedChallenge.category,
        'difficulty': updatedChallenge.difficulty,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('✅ تم تحديث التحدي بنجاح');
      return true;
    } catch (e) {
      print('❌ خطأ في تحديث التحدي: $e');
      return false;
    }
  }

  /// البحث في التحديات
  Future<List<Map<String, dynamic>>> searchChallenges(String searchTerm) async {
    try {
      print('🔍 البحث عن: $searchTerm');

      final snapshot = await _firestore.collection('challenges').get();
      final searchTermLower = searchTerm.toLowerCase();

      final results =
          snapshot.docs
              .where((doc) {
                final data = doc.data();
                final challenge =
                    (data['challenge'] as String? ?? '').toLowerCase();
                final category =
                    (data['category'] as String? ?? '').toLowerCase();

                return challenge.contains(searchTermLower) ||
                    category.contains(searchTermLower);
              })
              .map((doc) {
                final data = doc.data();
                return {
                  'id': doc.id,
                  'challenge': data['challenge'] ?? '',
                  'category': data['category'] ?? 'تحديات عامة',
                  'difficulty': data['difficulty'] ?? 'متوسط',
                  'created_at': data['created_at'],
                  'usage_count': data['usage_count'] ?? 0,
                  'source': data['source'] ?? 'unknown',
                };
              })
              .toList();

      print('✅ تم العثور على ${results.length} نتيجة');
      return results;
    } catch (e) {
      print('❌ خطأ في البحث: $e');
      return [];
    }
  }

  /// الحصول على التحديات حسب الفئة مع تفاصيل إضافية
  Future<List<Map<String, dynamic>>> getChallengesByCategory(
    String categoryName,
  ) async {
    try {
      print('🎯 جاري تحميل تحديات فئة: $categoryName');

      final snapshot =
          await _firestore
              .collection('challenges')
              .where('category', isEqualTo: categoryName)
              .get();

      final challenges =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'challenge': data['challenge'] ?? '',
              'category': data['category'] ?? 'تحديات عامة',
              'difficulty': data['difficulty'] ?? 'متوسط',
              'created_at': data['created_at'],
              'usage_count': data['usage_count'] ?? 0,
              'source': data['source'] ?? 'unknown',
            };
          }).toList();

      // ترتيب التحديات حسب تاريخ الإنشاء (الأحدث أولاً)
      challenges.sort((a, b) {
        final aTime = a['created_at'] as Timestamp?;
        final bTime = b['created_at'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime);
      });

      print('✅ تم تحميل ${challenges.length} تحدي من فئة $categoryName');
      return challenges;
    } catch (e) {
      print('❌ خطأ في تحميل تحديات الفئة: $e');
      return [];
    }
  }

  /// الحصول على جميع التحديات
  Future<List<Map<String, dynamic>>> getAllChallenges() async {
    try {
      print('🎯 جاري تحميل جميع التحديات...');

      final snapshot =
          await _firestore
              .collection('challenges')
              .orderBy('created_at', descending: true)
              .get();

      final challenges =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'challenge': data['challenge'] ?? '',
              'category': data['category'] ?? 'تحديات عامة',
              'difficulty': data['difficulty'] ?? 'متوسط',
              'created_at': data['created_at'],
              'usage_count': data['usage_count'] ?? 0,
              'source': data['source'] ?? 'unknown',
            };
          }).toList();

      print('✅ تم تحميل ${challenges.length} تحدي');
      return challenges;
    } catch (e) {
      print('❌ خطأ في تحميل التحديات: $e');
      return [];
    }
  }

  /// تحديث عداد استخدام التحدي
  Future<void> incrementChallengeUsage(String challengeId) async {
    try {
      await _firestore.collection('challenges').doc(challengeId).update({
        'usage_count': FieldValue.increment(1),
        'last_used': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ خطأ في تحديث عداد الاستخدام: $e');
    }
  }

  /// الحصول على إحصائيات التحديات
  Future<Map<String, dynamic>> getChallengesStats() async {
    try {
      final snapshot = await _firestore.collection('challenges').get();

      int totalChallenges = snapshot.docs.length;
      int totalUsage = 0;
      final categoryStats = <String, int>{};
      final difficultyStats = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final usage = data['usage_count'] as int? ?? 0;
        final category = data['category'] as String? ?? 'غير محدد';
        final difficulty = data['difficulty'] as String? ?? 'متوسط';

        totalUsage += usage;
        categoryStats[category] = (categoryStats[category] ?? 0) + 1;
        difficultyStats[difficulty] = (difficultyStats[difficulty] ?? 0) + 1;
      }

      return {
        'total_challenges': totalChallenges,
        'total_usage': totalUsage,
        'categories': categoryStats,
        'difficulties': difficultyStats,
      };
    } catch (e) {
      print('❌ خطأ في الحصول على إحصائيات التحديات: $e');
      return {
        'total_challenges': 0,
        'total_usage': 0,
        'categories': {},
        'difficulties': {},
      };
    }
  }

  /// الحصول على قائمة التحديات المحذوفة
  Future<List<Map<String, dynamic>>> getDeletedChallenges() async {
    try {
      print('📋 جاري تحميل قائمة التحديات المحذوفة...');

      final snapshot =
          await _firestore
              .collection('deleted_challenges')
              .orderBy('deleted_at', descending: true)
              .get();

      final deletedChallenges =
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'challenge_text': data['challenge_text'] ?? '',
              'deleted_at': data['deleted_at'],
              'deleted_by': data['deleted_by'] ?? 'unknown',
              // إضافة البيانات الأصلية للتحقق من وجودها عند الاستعادة
              'has_original_data': data['original_data'] != null,
            };
          }).toList();

      print('✅ تم تحميل ${deletedChallenges.length} تحدي محذوف');
      return deletedChallenges;
    } catch (e) {
      print('❌ خطأ في تحميل التحديات المحذوفة: $e');
      return [];
    }
  }

  /// استعادة تحدي محذوف (إعادة إضافته إلى مجموعة التحديات العادية)
  Future<bool> restoreDeletedChallenge(String challengeText) async {
    try {
      print('🔄 جاري استعادة التحدي المحذوف...');
      print('🔍 نص التحدي المراد استعادته: $challengeText');

      // البحث عن التحدي في قائمة المحذوفات
      final deletedSnapshot =
          await _firestore
              .collection('deleted_challenges')
              .where('challenge_text', isEqualTo: challengeText)
              .get();

      if (deletedSnapshot.docs.isEmpty) {
        print('❌ التحدي غير موجود في قائمة المحذوفات');
        return false;
      }

      // الحصول على بيانات التحدي الأصلية
      final deletedDoc = deletedSnapshot.docs.first;
      final deletedData = deletedDoc.data();
      final originalData =
          deletedData['original_data'] as Map<String, dynamic>?;

      if (originalData == null) {
        print('❌ البيانات الأصلية للتحدي غير متوفرة');
        return false;
      }

      // فحص ما إذا كان التحدي موجود مسبقاً في مجموعة التحديات العادية
      // نبحث باستخدام نص التحدي مباشرة
      final existingSnapshot =
          await _firestore
              .collection('challenges')
              .where('challenge', isEqualTo: challengeText)
              .get();

      if (existingSnapshot.docs.isNotEmpty) {
        print('⚠️ التحدي موجود مسبقاً في مجموعة التحديات العادية');
        // حذف من قائمة المحذوفات فقط
        await deletedDoc.reference.delete();
        print('✅ تم حذف التحدي من قائمة المحذوفات');
        return true;
      }

      // إعادة إضافة التحدي إلى مجموعة التحديات العادية مع البيانات الأصلية
      final restoredData = Map<String, dynamic>.from(originalData);

      // إضافة معلومات الاستعادة
      restoredData['restored_at'] = FieldValue.serverTimestamp();
      restoredData['restored_from_deleted'] = true;

      // إزالة الحقول التي قد تكون مشكلة عند الإضافة
      restoredData.remove('id');

      // إضافة hash إذا لم يكن موجوداً
      if (!restoredData.containsKey('challenge_hash')) {
        restoredData['challenge_hash'] = _generateQuestionHash(challengeText);
      }

      print('📝 البيانات المستعادة: ${restoredData.keys}');

      await _firestore.collection('challenges').add(restoredData);

      // حذف التحدي من قائمة المحذوفات
      await deletedDoc.reference.delete();

      print('✅ تم استعادة التحدي بنجاح وإضافته إلى مجموعة التحديات العادية');
      return true;
    } catch (e) {
      print('❌ خطأ في استعادة التحدي: $e');
      return false;
    }
  }

  /// رفع التحديات المحلية إلى Firebase (للمشرفين)
  Future<bool> uploadLocalChallengesToFirebase() async {
    try {
      print('📤 جاري رفع التحديات المحلية إلى Firebase...');

      // تحميل التحديات المحلية
      final String response = await rootBundle.loadString(
        'assets/data/challenges.json',
      );
      final List<dynamic> jsonData = json.decode(response);

      // تحميل التحديات الموجودة في Firebase للمقارنة
      print('🔍 جاري فحص التحديات الموجودة في Firebase...');
      final existingSnapshot = await _firestore.collection('challenges').get();

      // تحميل التحديات المحذوفة من Firebase
      print('🗑️ جاري فحص التحديات المحذوفة...');
      final deletedSnapshot =
          await _firestore.collection('deleted_challenges').get();

      // إنشاء مجموعة من التحديات الموجودة للمقارنة السريعة
      final existingChallenges = <String>{};
      for (final doc in existingSnapshot.docs) {
        final data = doc.data();
        final challengeText = data['challenge'] as String? ?? '';
        if (challengeText.isNotEmpty) {
          // استخدام نص التحدي كمعرف فريد (بعد تنظيفه)
          existingChallenges.add(_normalizeChallengeText(challengeText));
        }
      }

      // إنشاء مجموعة من التحديات المحذوفة للتحقق منها
      final deletedChallenges = <String>{};
      for (final doc in deletedSnapshot.docs) {
        final data = doc.data();
        final challengeText = data['challenge'] as String? ?? '';
        if (challengeText.isNotEmpty) {
          deletedChallenges.add(_normalizeChallengeText(challengeText));
        }
      }

      print(
        '📊 تم العثور على ${existingChallenges.length} تحدي موجود في Firebase',
      );
      print('🗑️ تم العثور على ${deletedChallenges.length} تحدي محذوف');

      int successCount = 0;
      int duplicateCount = 0;
      int deletedCount = 0;
      int errorCount = 0;

      // معالجة التحديات من الملف المحلي
      for (int i = 0; i < jsonData.length; i++) {
        try {
          final challengeText = jsonData[i] as String? ?? '';
          if (challengeText.isEmpty) continue;

          final normalizedText = _normalizeChallengeText(challengeText);

          // فحص ما إذا كان التحدي محذوف مسبقاً
          if (deletedChallenges.contains(normalizedText)) {
            print(
              '🗑️ تم تخطي تحدي محذوف مسبقاً: ${challengeText.substring(0, 50)}...',
            );
            deletedCount++;
            continue;
          }

          // فحص ما إذا كان التحدي موجود مسبقاً
          if (existingChallenges.contains(normalizedText)) {
            print('⏭️ تم تخطي تحدي مكرر: ${challengeText.substring(0, 50)}...');
            duplicateCount++;
            continue;
          }

          // تحديد الفئة والصعوبة بناءً على محتوى التحدي
          final category = _categorizeChallengeText(challengeText);
          final difficulty = _determineDifficulty(challengeText);

          // رفع التحدي إذا لم يكن موجوداً أو محذوفاً
          await _firestore.collection('challenges').add({
            'challenge': challengeText,
            'category': category,
            'difficulty': difficulty,
            'created_at': FieldValue.serverTimestamp(),
            'usage_count': 0,
            'source': 'local_upload',
            'challenge_hash': _generateChallengeHash(challengeText),
          });

          // إضافة التحدي للمجموعة لتجنب التكرار في نفس العملية
          existingChallenges.add(normalizedText);
          successCount++;

          print('✅ تم رفع تحدي جديد: ${challengeText.substring(0, 50)}...');
        } catch (e) {
          print('❌ خطأ في رفع تحدي: $e');
          errorCount++;
        }
      }

      print('📊 نتائج الرفع:');
      print('   ✅ تحديات جديدة: $successCount');
      print('   ⏭️ تحديات مكررة: $duplicateCount');
      print('   🗑️ تحديات محذوفة مسبقاً: $deletedCount');
      print('   ❌ أخطاء: $errorCount');
      print('   📝 إجمالي التحديات المعالجة: ${jsonData.length}');

      return successCount > 0;
    } catch (e) {
      print('❌ خطأ في رفع التحديات: $e');
      return false;
    }
  }

  /// تطبيع نص التحدي للمقارنة (إزالة المسافات الزائدة وتوحيد الحالة)
  String _normalizeChallengeText(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // استبدال عدة مسافات بمسافة واحدة
        .toLowerCase(); // تحويل للأحرف الصغيرة للمقارنة
  }

  /// إنشاء hash للتحدي لضمان الفرادة
  String _generateChallengeHash(String challengeText) {
    return challengeText.hashCode.toString();
  }

  /// تصنيف التحدي تلقائياً بناءً على محتواه
  String _categorizeChallengeText(String challengeText) {
    final text = challengeText.toLowerCase();

    if (text.contains('رقص') ||
        text.contains('ارقص') ||
        text.contains('تحرك')) {
      return 'تحديات حركية';
    } else if (text.contains('غن') ||
        text.contains('اغن') ||
        text.contains('صوت') ||
        text.contains('قلد')) {
      return 'تحديات مضحكة';
    } else if (text.contains('ضغط') ||
        text.contains('تمارين') ||
        text.contains('امش') ||
        text.contains('قف')) {
      return 'تحديات حركية';
    } else if (text.contains('عد') ||
        text.contains('احسب') ||
        text.contains('الأبجدية')) {
      return 'تحديات فكرية';
    } else if (text.contains('ارسم') ||
        text.contains('تخيل') ||
        text.contains('اطبخ')) {
      return 'تحديات إبداعية';
    } else if (text.contains('مساج') ||
        text.contains('للجميع') ||
        text.contains('الآخرين')) {
      return 'تحديات جماعية';
    } else if (text.contains('30 ثانية') ||
        text.contains('سريع') ||
        text.contains('20 مرة')) {
      return 'تحديات سريعة';
    } else if (text.contains('صعب') ||
        text.contains('مغمض العينين') ||
        text.contains('بدون')) {
      return 'تحديات صعبة';
    } else {
      return 'تحديات عامة';
    }
  }

  /// تحديد صعوبة التحدي تلقائياً
  String _determineDifficulty(String challengeText) {
    final text = challengeText.toLowerCase();

    if (text.contains('مغمض العينين') ||
        text.contains('بدون') ||
        text.contains('صعب') ||
        text.contains('دقيقتين') ||
        text.contains('الأبجدية بالعكس')) {
      return 'صعب';
    } else if (text.contains('تمارين') ||
        text.contains('ضغط') ||
        text.contains('دقيقة') ||
        text.contains('20 مرة') ||
        text.contains('تقليد') ||
        text.contains('درامات')) {
      return 'متوسط';
    } else {
      return 'سهل';
    }
  }
}
