import '../utils/join_room_test.dart';

/// أداة سريعة لاختبار وظائف الانضمام للغرف
class QuickJoinTest {
  /// اختبار سريع للانضمام للغرفة
  static Future<void> quickTest(String roomCode, String playerName) async {
    print('🎮 بدء الاختبار السريع للانضمام للغرفة...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final result = await JoinRoomTest.testJoinRoom(roomCode, playerName);

    print('\n📊 نتائج الاختبار:');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (result['success'] == true) {
      print('✅ نجح الاختبار!');
      final details = result['details'] as Map<String, dynamic>;
      if (details['final_room_data'] != null) {
        final roomData = details['final_room_data'] as Map<String, dynamic>;
        print('🎉 تم الانضمام للغرفة بنجاح!');
        print('   📍 رقم الغرفة: ${roomData['id']}');
        print(
          '   👥 عدد اللاعبين: ${roomData['playersCount']}/${roomData['maxPlayers']}',
        );
        print('   👑 منشئ الغرفة: ${roomData['hostId']}');
      }
    } else {
      print('❌ فشل الاختبار');
      if (result['error'] != null) {
        print('🔴 السبب: ${result['error']}');
      }
    }

    print('\n📝 تفاصيل الخطوات:');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    final steps = result['steps'] as List<dynamic>;
    for (int i = 0; i < steps.length; i++) {
      print('${i + 1}. ${steps[i]}');
    }

    print('\n🔍 معلومات إضافية:');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    final details = result['details'] as Map<String, dynamic>;
    details.forEach((key, value) {
      if (key != 'final_room_data') {
        print('   $key: $value');
      }
    });

    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🏁 انتهى الاختبار');
  }

  /// عرض جميع الغرف المتاحة
  static Future<void> showAvailableRooms() async {
    print('🔍 البحث عن الغرف المتاحة...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final result = await JoinRoomTest.listAvailableRooms();

    if (result['success'] == true) {
      final rooms = result['rooms'] as List<dynamic>;
      if (rooms.isNotEmpty) {
        print('✅ تم العثور على ${rooms.length} غرفة متاحة:');
        print('');
        for (int i = 0; i < rooms.length; i++) {
          final room = rooms[i] as Map<String, dynamic>;
          print('${i + 1}. غرفة ${room['id']}');
          print(
            '   👥 اللاعبين: ${room['playersCount']}/${room['maxPlayers']}',
          );
          print('   👑 المضيف: ${room['hostId']}');
          print('   ⏰ تاريخ الإنشاء: ${room['createdAt']}');
          print('');
        }
      } else {
        print('🔍 لا توجد غرف متاحة حالياً');
      }
    } else {
      print('❌ فشل في البحث عن الغرف');
      if (result['error'] != null) {
        print('🔴 السبب: ${result['error']}');
      }
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// إنشاء غرفة تجريبية
  static Future<String?> createTestRoomQuick() async {
    print('🧪 إنشاء غرفة تجريبية...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final roomCode = await JoinRoomTest.createTestRoom();

    if (roomCode != null) {
      print('✅ تم إنشاء غرفة تجريبية بنجاح!');
      print('🔑 كود الغرفة: $roomCode');
      print('📋 انسخ هذا الكود للاختبار');
    } else {
      print('❌ فشل في إنشاء غرفة تجريبية');
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return roomCode;
  }

  /// اختبار شامل (إنشاء غرفة ثم الانضمام إليها)
  static Future<void> fullTest() async {
    print('🎯 بدء الاختبار الشامل...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // إنشاء غرفة تجريبية
    final roomCode = await createTestRoomQuick();

    if (roomCode == null) {
      print('❌ توقف الاختبار: فشل في إنشاء غرفة تجريبية');
      return;
    }

    // انتظار قصير للتأكد من حفظ الغرفة
    await Future.delayed(const Duration(seconds: 2));

    // اختبار الانضمام للغرفة
    print('\n🚪 اختبار الانضمام للغرفة التجريبية...');
    await quickTest(roomCode, 'لاعب تجريبي');

    // حذف الغرفة التجريبية
    print('\n🗑️ حذف الغرفة التجريبية...');
    final deleted = await JoinRoomTest.deleteTestRoom(roomCode);
    if (deleted) {
      print('✅ تم حذف الغرفة التجريبية');
    } else {
      print('⚠️ فشل في حذف الغرفة التجريبية (قد تحتاج حذف يدوي)');
    }

    print('\n🏁 انتهى الاختبار الشامل');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
