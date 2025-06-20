import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../services/firebase_service.dart';

class JoinRoomTest {
  static final FirebaseService _firebaseService = FirebaseService();

  /// اختبار شامل لوظيفة الانضمام إلى الغرفة
  static Future<Map<String, dynamic>> testJoinRoom(
    String roomCode,
    String playerName,
  ) async {
    final Map<String, dynamic> result = {
      'success': false,
      'error': null,
      'details': {},
      'steps': [],
    };

    try {
      // خطوة 1: التحقق من تهيئة Firebase
      result['steps'].add('🔧 فحص تهيئة Firebase...');
      print('🔧 فحص تهيئة Firebase...');

      if (Firebase.apps.isEmpty) {
        result['error'] = 'Firebase غير مهيأ';
        result['steps'].add('❌ Firebase غير مهيأ');
        return result;
      }

      result['steps'].add('✅ Firebase مهيأ بنجاح');
      result['details']['firebase_initialized'] = true;

      // خطوة 2: التحقق من صحة البيانات المدخلة
      result['steps'].add('📝 فحص البيانات المدخلة...');
      print('📝 فحص البيانات المدخلة...');

      if (roomCode.trim().isEmpty) {
        result['error'] = 'كود الغرفة فارغ';
        result['steps'].add('❌ كود الغرفة فارغ');
        return result;
      }

      if (roomCode.trim().length != 6) {
        result['error'] = 'كود الغرفة يجب أن يكون 6 أرقام';
        result['steps'].add('❌ كود الغرفة طوله غير صحيح: ${roomCode.length}');
        return result;
      }

      if (playerName.trim().isEmpty) {
        result['error'] = 'اسم اللاعب فارغ';
        result['steps'].add('❌ اسم اللاعب فارغ');
        return result;
      }

      result['steps'].add('✅ البيانات المدخلة صحيحة');
      result['details']['input_valid'] = true;
      result['details']['room_code'] = roomCode.trim();
      result['details']['player_name'] = playerName.trim();

      // خطوة 3: التحقق من الاتصال بـ Firestore
      result['steps'].add('🔗 فحص الاتصال بـ Firestore...');
      print('🔗 فحص الاتصال بـ Firestore...');

      final firestore = FirebaseFirestore.instance;
      try {
        await firestore.enableNetwork();
        result['steps'].add('✅ تم الاتصال بـ Firestore');
        result['details']['firestore_connected'] = true;
      } catch (e) {
        result['error'] = 'فشل الاتصال بـ Firestore: $e';
        result['steps'].add('❌ فشل الاتصال بـ Firestore: $e');
        return result;
      }

      // خطوة 4: البحث عن الغرفة
      result['steps'].add('🔍 البحث عن الغرفة...');
      print('🔍 البحث عن الغرفة $roomCode...');

      final roomRef = firestore.collection('game_rooms').doc(roomCode);
      DocumentSnapshot roomDoc;

      try {
        roomDoc = await roomRef.get().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('انتهت مهلة البحث عن الغرفة');
          },
        );
      } catch (e) {
        result['error'] = 'فشل في البحث عن الغرفة: $e';
        result['steps'].add('❌ فشل في البحث عن الغرفة: $e');
        return result;
      }

      if (!roomDoc.exists) {
        result['error'] = 'الغرفة غير موجودة';
        result['steps'].add('❌ الغرفة غير موجودة');
        result['details']['room_exists'] = false;
        return result;
      }

      result['steps'].add('✅ تم العثور على الغرفة');
      result['details']['room_exists'] = true;

      // خطوة 5: فحص بيانات الغرفة
      result['steps'].add('📊 فحص بيانات الغرفة...');
      print('📊 فحص بيانات الغرفة...');

      final roomData = roomDoc.data() as Map<String, dynamic>;
      result['details']['room_data'] = {
        'hostId': roomData['hostId'],
        'maxPlayers': roomData['maxPlayers'],
        'state': roomData['state'],
        'playersCount': (roomData['players'] as List).length,
      };

      // التحقق من حالة الغرفة
      final gameState = roomData['state'] as int;
      if (gameState != 0) {
        // 0 = waiting, 1 = inProgress, 2 = finished
        String stateText = gameState == 1 ? 'قيد التشغيل' : 'منتهية';
        result['error'] = 'الغرفة $stateText ولا يمكن الانضمام إليها';
        result['steps'].add('❌ حالة الغرفة: $stateText');
        return result;
      }

      result['steps'].add('✅ الغرفة في حالة انتظار');

      // التحقق من امتلاء الغرفة
      final maxPlayers = roomData['maxPlayers'] as int;
      final currentPlayers = (roomData['players'] as List).length;

      if (currentPlayers >= maxPlayers) {
        result['error'] = 'الغرفة ممتلئة ($currentPlayers/$maxPlayers)';
        result['steps'].add('❌ الغرفة ممتلئة ($currentPlayers/$maxPlayers)');
        return result;
      }

      result['steps'].add(
        '✅ يمكن الانضمام للغرفة ($currentPlayers/$maxPlayers)',
      );

      // خطوة 6: محاولة الانضمام
      result['steps'].add('🚪 محاولة الانضمام للغرفة...');
      print('🚪 محاولة الانضمام للغرفة...');

      try {
        final room = await _firebaseService.joinRoom(roomCode, playerName);

        if (room != null) {
          result['success'] = true;
          result['steps'].add('🎉 تم الانضمام للغرفة بنجاح!');
          result['details']['joined_successfully'] = true;
          result['details']['final_room_data'] = {
            'id': room.id,
            'playersCount': room.players.length,
            'maxPlayers': room.maxPlayers,
            'hostId': room.hostId,
          };
        } else {
          result['error'] = 'فشل الانضمام للغرفة (سبب غير معروف)';
          result['steps'].add('❌ فشل الانضمام للغرفة');
        }
      } catch (e) {
        result['error'] = 'خطأ أثناء الانضمام: $e';
        result['steps'].add('❌ خطأ أثناء الانضمام: $e');

        // تحليل نوع الخطأ
        if (e.toString().contains('permission-denied')) {
          result['steps'].add('🔒 مشكلة في أذونات Firestore');
          result['steps'].add('💡 تحقق من قواعد Firebase في Console');
        } else if (e.toString().contains('network')) {
          result['steps'].add('🌐 مشكلة في الشبكة');
        }
      }

      return result;
    } catch (e) {
      result['error'] = 'خطأ عام: $e';
      result['steps'].add('❌ خطأ عام: $e');
      return result;
    }
  }

  /// فحص جميع الغرف الموجودة
  static Future<Map<String, dynamic>> listAvailableRooms() async {
    final Map<String, dynamic> result = {
      'success': false,
      'rooms': [],
      'error': null,
    };

    try {
      print('🔍 البحث عن الغرف المتاحة...');

      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore
          .collection('game_rooms')
          .where('state', isEqualTo: 0) // waiting state
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
            final data = doc.data();
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

  /// اختبار إنشاء غرفة تجريبية للاختبار
  static Future<String?> createTestRoom() async {
    try {
      print('🧪 إنشاء غرفة تجريبية للاختبار...');

      final room = await _firebaseService.createRoom(
        'مختبر',
        4,
        questionsCount: 5,
      );

      if (room != null) {
        print('✅ تم إنشاء غرفة تجريبية: ${room.id}');
        return room.id;
      } else {
        print('❌ فشل في إنشاء غرفة تجريبية');
        return null;
      }
    } catch (e) {
      print('❌ خطأ في إنشاء غرفة تجريبية: $e');
      return null;
    }
  }

  /// حذف غرفة تجريبية
  static Future<bool> deleteTestRoom(String roomCode) async {
    try {
      print('🗑️ حذف غرفة تجريبية: $roomCode');

      final firestore = FirebaseFirestore.instance;
      await firestore.collection('game_rooms').doc(roomCode).delete();

      print('✅ تم حذف الغرفة التجريبية');
      return true;
    } catch (e) {
      print('❌ فشل في حذف الغرفة التجريبية: $e');
      return false;
    }
  }

  /// اختبار وظائف التنظيف الجديدة
  static Future<void> testCleanupFunctions() async {
    try {
      print('🧪 بدء اختبار وظائف التنظيف...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // اختبار التنظيف التلقائي الجديد
      final autoCleanDeleted = await _firebaseService.autoCleanEmptyRooms();
      print('📊 عدد الغرف المحذوفة بالتنظيف التلقائي: $autoCleanDeleted');

      // اختبار حذف الغرف الفارغة
      final emptyDeleted = await _firebaseService.deleteEmptyRooms();
      print('📊 عدد الغرف الفارغة المحذوفة: $emptyDeleted');

      // اختبار حذف الغرف القديمة
      final oldDeleted = await _firebaseService.deleteOldFinishedRooms();
      print('📊 عدد الغرف القديمة المحذوفة: $oldDeleted');

      // اختبار التنظيف الشامل
      final cleanupResult = await _firebaseService.cleanupRooms();
      print('📊 نتائج التنظيف الشامل:');
      print('   - غرف فارغة: ${cleanupResult['emptyRooms']}');
      print('   - غرف قديمة: ${cleanupResult['oldRooms']}');
      print('   - المجموع: ${cleanupResult['total']}');

      // اختبار عرض الغرف المتاحة
      final availableRooms = await _firebaseService.getAvailableRooms();
      if (availableRooms['success'] == true) {
        final rooms = availableRooms['rooms'] as List;
        print('📊 عدد الغرف المتاحة: ${rooms.length}');
        for (int i = 0; i < rooms.length; i++) {
          final room = rooms[i] as Map<String, dynamic>;
          print(
            '   ${i + 1}. غرفة ${room['id']} - ${room['playersCount']}/${room['maxPlayers']} لاعبين - المنشئ: ${room['hostName']}',
          );
        }
      } else {
        print('❌ فشل في عرض الغرف المتاحة: ${availableRooms['error']}');
      }

      // اختبار إنشاء وحذف غرفة تلقائياً
      print('🧪 اختبار إنشاء غرفة للحذف التلقائي...');
      final testRoom = await _firebaseService.createRoom(
        'اختبار_حذف_تلقائي',
        2,
        questionsCount: 3,
      );

      if (testRoom != null) {
        print('✅ تم إنشاء غرفة اختبار: ${testRoom.id}');

        // مغادرة الغرفة لتصبح فارغة
        await _firebaseService.leaveRoom(testRoom.id);
        print('🚪 تم مغادرة الغرفة - يجب أن تُحذف تلقائياً');

        // انتظار قليل ثم فحص إذا تم الحذف
        await Future.delayed(const Duration(seconds: 2));

        final autoCleanResult = await _firebaseService.autoCleanEmptyRooms();
        print('🗑️ عدد الغرف المحذوفة تلقائياً: $autoCleanResult');
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🏁 انتهى اختبار وظائف التنظيف');
    } catch (e) {
      print('❌ خطأ في اختبار وظائف التنظيف: $e');
    }
  }

  /// اختبار سريع لتشخيص مشاكل النظام
  static Future<Map<String, dynamic>> quickDiagnostic() async {
    print('🔧 بدء التشخيص السريع...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final List<String> errors = [];
    bool firebaseOk = false;
    bool firestoreOk = false;
    int roomsAvailable = 0;
    bool testRoomCreated = false;

    try {
      // 1. فحص Firebase
      print('🔥 فحص اتصال Firebase...');
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        firebaseOk = true;
        print('✅ Firebase متصل');
      } catch (e) {
        firebaseOk = false;
        errors.add('فشل في الاتصال بـ Firebase: $e');
        print('❌ Firebase: $e');
      }

      // 2. فحص Firestore
      print('📊 فحص اتصال Firestore...');
      try {
        await FirebaseFirestore.instance
            .collection('test')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));
        firestoreOk = true;
        print('✅ Firestore متصل');
      } catch (e) {
        firestoreOk = false;
        errors.add('فشل في الاتصال بـ Firestore: $e');
        print('❌ Firestore: $e');
      }

      // 3. فحص الغرف المتاحة
      if (firestoreOk) {
        print('🏠 فحص الغرف المتاحة...');
        try {
          final result = await _firebaseService.getAvailableRooms();
          if (result['success']) {
            final rooms = result['rooms'] as List;
            roomsAvailable = rooms.length;
            print('✅ تم العثور على $roomsAvailable غرفة متاحة');
          } else {
            errors.add('فشل في جلب الغرف المتاحة: ${result['error']}');
            print('❌ لا يمكن جلب الغرف المتاحة: ${result['error']}');
          }
        } catch (e) {
          errors.add('خطأ في فحص الغرف المتاحة: $e');
          print('❌ خطأ في فحص الغرف: $e');
        }
      }

      // 4. فحص إنشاء غرفة تجريبية
      if (firestoreOk) {
        print('🧪 فحص إنشاء غرفة تجريبية...');
        try {
          final testRoom = await _firebaseService.createRoom(
            'تشخيص_تلقائي',
            2,
            questionsCount: 5,
          );

          if (testRoom != null) {
            testRoomCreated = true;
            print('✅ تم إنشاء غرفة تجريبية: ${testRoom.id}');

            // ملاحظة: الغرفة ستحذف تلقائياً عند عدم وجود لاعبين
            print('ℹ️ الغرفة التجريبية ستحذف تلقائياً');
          } else {
            testRoomCreated = false;
            errors.add('فشل في إنشاء غرفة تجريبية');
            print('❌ فشل في إنشاء غرفة تجريبية');
          }
        } catch (e) {
          testRoomCreated = false;
          errors.add('خطأ في إنشاء غرفة تجريبية: $e');
          print('❌ خطأ في إنشاء غرفة: $e');
        }
      }

      // طباعة النتائج النهائية
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (errors.isEmpty) {
        print('🎉 التشخيص مكتمل - النظام يعمل بشكل طبيعي!');
      } else {
        print('⚠️ التشخيص مكتمل - تم العثور على ${errors.length} مشكلة');
        for (int i = 0; i < errors.length; i++) {
          print('   ${i + 1}. ${errors[i]}');
        }
      }

      return {
        'success': errors.isEmpty,
        'errors': errors,
        'firebase_ok': firebaseOk,
        'firestore_ok': firestoreOk,
        'rooms_available': roomsAvailable,
        'test_room_created': testRoomCreated,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      final error = 'فشل في التشخيص: $e';
      errors.add(error);
      print('❌ $error');

      return {
        'success': false,
        'errors': errors,
        'firebase_ok': firebaseOk,
        'firestore_ok': firestoreOk,
        'rooms_available': roomsAvailable,
        'test_room_created': testRoomCreated,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
