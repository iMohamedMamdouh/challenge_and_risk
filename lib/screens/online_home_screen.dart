import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_room.dart'; // Added import for GameRoom
import '../services/firebase_service.dart';
import 'online_lobby_screen.dart';
import 'room_settings_screen.dart';

class OnlineHomeScreen extends StatefulWidget {
  const OnlineHomeScreen({super.key});

  @override
  State<OnlineHomeScreen> createState() => _OnlineHomeScreenState();
}

class _OnlineHomeScreenState extends State<OnlineHomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _firebaseService = FirebaseService();
  bool _isLoading = false;
  bool _isCreatingRoom = false; // لتحديد نوع العملية
  Map<String, dynamic>? _lastRoomData; // بيانات الغرفة الأخيرة

  @override
  void initState() {
    super.initState();
    // تشغيل التنظيف التلقائي عند فتح الشاشة
    _performAutoCleanup();
    // فحص وجود غرفة سابقة
    _checkForLastRoom();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  // تشغيل التنظيف التلقائي في الخلفية
  void _performAutoCleanup() async {
    try {
      print('🤖 تشغيل التنظيف التلقائي في الخلفية...');
      await _firebaseService.autoCleanEmptyRooms();
    } catch (e) {
      print('⚠️ فشل في التنظيف التلقائي: $e');
    }
  }

  // فحص وجود غرفة سابقة
  void _checkForLastRoom() async {
    try {
      final lastRoom = await _firebaseService.getLastRoomData();
      if (lastRoom != null) {
        print('✅ تم العثور على غرفة سابقة: ${lastRoom['roomCode']}');
        setState(() {
          _lastRoomData = lastRoom;
        });
      } else {
        print('❌ لا توجد غرفة سابقة');
      }
    } catch (e) {
      print('⚠️ خطأ في فحص الغرفة السابقة: $e');
    }
  }

  // العودة للغرفة الأخيرة
  void _rejoinLastRoom() async {
    if (_lastRoomData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final roomCode = _lastRoomData!['roomCode'] as String;
      final playerName = _lastRoomData!['playerName'] as String;

      print('🔄 محاولة العودة للغرفة: $roomCode باسم: $playerName');

      // محاولة الانضمام للغرفة مرة أخرى
      final room = await _firebaseService.rejoinRoom(roomCode, playerName);

      if (room != null) {
        print('✅ تم الانضمام للغرفة بنجاح');

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OnlineLobbyScreen(
                    roomCode: roomCode,
                    playerName: playerName,
                    isHost: _lastRoomData!['isHost'] as bool,
                    timerDuration:
                        (_lastRoomData!['room'] as GameRoom).timerDuration ??
                        10,
                  ),
            ),
          );
        }
      } else {
        print('❌ فشل في الانضمام للغرفة');
        // حذف بيانات الغرفة الأخيرة إذا لم تعد موجودة
        await _firebaseService.clearLastRoomData();
        setState(() {
          _lastRoomData = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الغرفة غير موجودة أو انتهت صلاحيتها'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('⚠️ خطأ في العودة للغرفة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء العودة للغرفة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _createRoom() async {
    setState(() => _isCreatingRoom = true);

    if (!_formKey.currentState!.validate()) {
      setState(() => _isCreatingRoom = false);
      return;
    }

    // الانتقال إلى صفحة إعدادات الغرفة بدلاً من إنشاء الغرفة مباشرة
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                RoomSettingsScreen(playerName: _nameController.text.trim()),
      ),
    );

    setState(() => _isCreatingRoom = false);
  }

  void _joinRoom() async {
    setState(() => _isCreatingRoom = false);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('🎮 بدء محاولة الانضمام للغرفة...');
      print('📝 البيانات المدخلة:');
      print('   - كود الغرفة: ${_roomCodeController.text.trim()}');
      print('   - اسم اللاعب: ${_nameController.text.trim()}');

      final room = await _firebaseService.joinRoomWithAutoClean(
        _roomCodeController.text.trim().toUpperCase(),
        _nameController.text.trim(),
      );

      if (room != null && mounted) {
        print('🎉 نجح الانضمام - الانتقال لصفحة الانتظار...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => OnlineLobbyScreen(
                  roomCode: room.id,
                  playerName: _nameController.text.trim(),
                  isHost: false,
                  timerDuration: room.timerDuration ?? 10,
                ),
          ),
        );
      } else if (mounted) {
        print('⚠️ فشل الانضمام - السبب غير محدد');

        // معالجة أخطاء أكثر تفصيلاً
        String errorMessage = 'لم يتم العثور على الغرفة';

        // محاولة فهم السبب بتشغيل فحص سريع
        try {
          final availableRooms = await _firebaseService.getAvailableRooms();
          if (availableRooms['success'] == true) {
            final rooms = availableRooms['rooms'] as List;
            final roomExists = rooms.any(
              (r) => r['id'] == _roomCodeController.text.trim().toUpperCase(),
            );

            if (roomExists) {
              errorMessage =
                  'الغرفة موجودة لكنها قد تكون ممتلئة أو في حالة لعب';
            } else if (rooms.isEmpty) {
              errorMessage =
                  'لا توجد غرف متاحة حالياً. تأكد من الكود أو أنشئ غرفة جديدة';
            } else {
              errorMessage =
                  'كود الغرفة غير صحيح. الغرف المتاحة: ${rooms.length}';
            }
          }
        } catch (e) {
          print('خطأ في الفحص التفصيلي: $e');
        }

        _showDetailedErrorDialog(
          'فشل الانضمام للغرفة',
          errorMessage,
          _roomCodeController.text.trim().toUpperCase(),
        );
      }
    } catch (e) {
      if (mounted) {
        print('❌ خطأ في محاولة الانضمام: $e');

        String errorTitle = 'حدث خطأ أثناء الانضمام';
        String errorMessage = 'خطأ غير معروف';

        // تحليل نوع الخطأ
        if (e.toString().contains('permission-denied')) {
          errorTitle = 'مشكلة في الأذونات';
          errorMessage =
              'هناك مشكلة في إعدادات Firebase. يرجى المحاولة لاحقاً أو التواصل مع المطور.';
        } else if (e.toString().contains('network')) {
          errorTitle = 'مشكلة في الاتصال';
          errorMessage = 'تحقق من اتصالك بالإنترنت وحاول مرة أخرى.';
        } else if (e.toString().contains('timeout') ||
            e.toString().contains('انتهت مهلة')) {
          errorTitle = 'انتهت مهلة الاتصال';
          errorMessage = 'الاتصال بطيء جداً. تحقق من الإنترنت وحاول مرة أخرى.';
        } else if (e.toString().contains('بيانات الغرفة تالفة')) {
          errorTitle = 'مشكلة في بيانات الغرفة';
          errorMessage = 'الغرفة تحتوي على بيانات تالفة. جرب غرفة أخرى.';
        } else {
          errorMessage = 'حدث خطأ غير متوقع: ${e.toString()}';
        }

        _showDetailedErrorDialog(errorTitle, errorMessage, null);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('خطأ'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('موافق'),
              ),
            ],
          ),
    );
  }

  void _showDetailedErrorDialog(
    String title,
    String message,
    String? roomCode,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(child: Text(title)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (roomCode != null) ...[
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'الكود المدخل:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          roomCode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 15),
                const Text(
                  'اقتراحات:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                const Text(
                  '• تأكد من صحة كود الغرفة\n'
                  '• اضغط على "الغرف المتاحة" لرؤية الغرف الموجودة\n'
                  '• جرب إنشاء غرفة جديدة\n'
                  '• تحقق من اتصال الإنترنت',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('موافق'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showAvailableRooms();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('عرض الغرف المتاحة'),
              ),
            ],
          ),
    );
  }

  void _showAvailableRooms() async {
    setState(() => _isLoading = true);

    try {
      // تشغيل التنظيف التلقائي للغرف الفارغة أولاً
      await _firebaseService.autoCleanEmptyRooms();

      // عرض الغرف المتاحة
      final result = await _firebaseService.getAvailableRooms();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _AvailableRoomsDialog(result: result),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text(
          'اللعب الأونلاين',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // Online gaming info
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.wifi, size: 50, color: Colors.green),
                            SizedBox(height: 10),
                            Text(
                              'اللعب الأونلاين',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'أنشئ غرفة جديدة أو انضم لغرفة موجودة باستخدام الكود',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // زر العودة للغرفة - يظهر فقط إذا كان هناك غرفة سابقة
                      if (_lastRoomData != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple.shade400,
                                Colors.purple.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.3),
                                spreadRadius: 3,
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'غرفة سابقة متاحة',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 15,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'الغرفة: ${_lastRoomData!['roomCode']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'اللاعب: ${_lastRoomData!['playerName']}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (_lastRoomData!['isHost'] == true)
                                      const Text(
                                        '(منشئ الغرفة)',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 15),
                              ElevatedButton(
                                onPressed: _isLoading ? null : _rejoinLastRoom,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.purple.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 30,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 2,
                                ),
                                child:
                                    _isLoading
                                        ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.purple,
                                                ),
                                          ),
                                        )
                                        : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_arrow),
                                            SizedBox(width: 8),
                                            Text(
                                              'العودة للغرفة',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],

                      // Player name input
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'اسم اللاعب',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: _nameController,
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                labelText: 'أدخل اسمك',
                                prefixIcon: Icon(
                                  Icons.person,
                                  color: Colors.deepPurple.shade300,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'يرجى إدخال اسمك';
                                }
                                if (value.trim().length < 2) {
                                  return 'الاسم يجب أن يكون أكثر من حرف واحد';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Create room section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.add_circle, color: Colors.green),
                                SizedBox(width: 10),
                                Text(
                                  'إنشاء غرفة جديدة',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            const Text(
                              'أدخل اسمك أولاً، ثم اضغط على إعدادات الغرفة لتخصيص اللعبة',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _createRoom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.settings),
                                  SizedBox(width: 8),
                                  Text(
                                    'إعداد الغرفة',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Join room section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.meeting_room, color: Colors.blue),
                                SizedBox(width: 10),
                                Text(
                                  'الانضمام لغرفة',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: _roomCodeController,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: InputDecoration(
                                labelText: 'كود الغرفة',
                                hintText: '123456',
                                helperText: 'مطلوب للانضمام لغرفة موجودة',
                                prefixIcon: Icon(
                                  Icons.vpn_key,
                                  color: Colors.deepPurple.shade300,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                // التحقق من كود الغرفة فقط عند الانضمام
                                if (!_isCreatingRoom) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'يرجى إدخال كود الغرفة';
                                  }
                                  if (value.trim().length != 6) {
                                    return 'كود الغرفة يجب أن يكون 6 أرقام';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: _joinRoom,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.login),
                                  SizedBox(width: 8),
                                  Text(
                                    'انضمام للغرفة',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 15),

                            // أزرار إضافية - إزالة زر التنظيف وزر الفحص السريع
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _showAvailableRooms,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.list, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'عرض الغرف المتاحة',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'كيفية اللعب الأونلاين:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            Text(
                              '• لإنشاء غرفة جديدة: أدخل اسمك واضغط "إعدادات الغرفة" لتخصيص اللعبة\n'
                              '• للانضمام لغرفة موجودة: أدخل اسمك وكود الغرفة\n'
                              '• شارك كود الغرفة مع أصدقائك بعد إنشائها\n'
                              '• انتظر حتى ينضم جميع اللاعبين وابدأ اللعب!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}

// نافذة عرض الغرف المتاحة
class _AvailableRoomsDialog extends StatelessWidget {
  final Map<String, dynamic> result;

  const _AvailableRoomsDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    final rooms = result['rooms'] as List<dynamic>;
    final isSuccess = result['success'] as bool;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.list, color: Colors.blue),
          SizedBox(width: 10),
          Text('الغرف المتاحة'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child:
            isSuccess
                ? rooms.isNotEmpty
                    ? Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            'تم العثور على ${rooms.length} غرفة متاحة:',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: rooms.length,
                            itemBuilder: (context, index) {
                              final room = rooms[index] as Map<String, dynamic>;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.meeting_room,
                                      color: Colors.blue.shade600,
                                    ),
                                  ),
                                  title: Text(
                                    'غرفة ${room['id']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'اللاعبين: ${room['playersCount']}/${room['maxPlayers']}',
                                      ),
                                      Text(
                                        'المنشئ: ${room['hostName'] ?? 'غير معروف'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing:
                                  // زر نسخ الكود فقط
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: room['id'].toString(),
                                        ),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('تم نسخ كود الغرفة'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    tooltip: 'نسخ الكود',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    )
                    : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'لا توجد غرف متاحة حالياً',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'يمكنك إنشاء غرفة جديدة',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'خطأ: ${result['error']}',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
        if (isSuccess && rooms.isNotEmpty)
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // يمكن إضافة تحديث للقائمة هنا
            },
            child: const Text('تحديث'),
          ),
      ],
    );
  }
}
