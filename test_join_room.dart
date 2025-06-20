import 'package:firebase_core/firebase_core.dart';

import 'lib/firebase_options.dart';
import 'lib/utils/join_room_test.dart';
import 'lib/utils/quick_join_test.dart';

/// سكريپت لاختبار وظائف الانضمام للغرف
/// تشغيل بالأمر: dart test_join_room.dart
void main(List<String> args) async {
  print('🎮 مرحباً بك في أداة اختبار الانضمام للغرف');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  try {
    // تهيئة Firebase
    print('🔧 تهيئة Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ تم تهيئة Firebase بنجاح');

    if (args.isEmpty) {
      print('\n📋 الأوامر المتاحة:');
      print('   dart test_join_room.dart test <room_code> <player_name>');
      print('   dart test_join_room.dart list');
      print('   dart test_join_room.dart create');
      print('   dart test_join_room.dart full');
      print('   dart test_join_room.dart diagnostic');
      print('   dart test_join_room.dart auto-clean');
      print('\n💡 أمثلة:');
      print('   dart test_join_room.dart test 123456 "أحمد"');
      print('   dart test_join_room.dart list');
      print('   dart test_join_room.dart create');
      print('   dart test_join_room.dart full');
      print('   dart test_join_room.dart diagnostic');
      print('   dart test_join_room.dart auto-clean');
      return;
    }

    final command = args[0].toLowerCase();

    switch (command) {
      case 'test':
        if (args.length < 3) {
          print(
            '❌ استخدام خاطئ. المطلوب: dart test_join_room.dart test <room_code> <player_name>',
          );
          return;
        }
        final roomCode = args[1];
        final playerName = args[2];
        await QuickJoinTest.quickTest(roomCode, playerName);
        break;

      case 'list':
        await QuickJoinTest.showAvailableRooms();
        break;

      case 'create':
        await QuickJoinTest.createTestRoomQuick();
        break;

      case 'full':
        await QuickJoinTest.fullTest();
        break;

      case 'diagnostic':
      case 'diag':
        print('🔧 تشغيل التشخيص السريع...');
        await JoinRoomTest.quickDiagnostic();
        break;

      case 'auto-clean':
      case 'clean':
        print('🤖 تشغيل اختبار التنظيف التلقائي...');
        await JoinRoomTest.testCleanupFunctions();
        break;

      default:
        print('❌ أمر غير معروف: $command');
        print(
          '📋 الأوامر المتاحة: test, list, create, full, diagnostic, auto-clean',
        );
    }
  } catch (e) {
    print('❌ خطأ في تشغيل الاختبار: $e');
  }

  print('\n👋 شكراً لاستخدام أداة الاختبار!');
}
