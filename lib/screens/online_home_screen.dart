import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firebase_service.dart';
import 'online_lobby_screen.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _createRoom() async {
    setState(() => _isCreatingRoom = true);

    if (!_formKey.currentState!.validate()) {
      setState(() => _isCreatingRoom = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🚀 بدء إنشاء الغرفة...');
      print('اسم اللاعب: ${_nameController.text.trim()}');

      // استخدام عدد لاعبين افتراضي (6)
      const maxPlayers = 6;
      print('عدد اللاعبين الأقصى: $maxPlayers');

      final room = await _firebaseService.createRoom(
        _nameController.text.trim(),
        maxPlayers,
      );

      print('نتيجة إنشاء الغرفة: $room');

      if (room != null && mounted) {
        print('✅ تم إنشاء الغرفة بنجاح! كود الغرفة: ${room.id}');

        // إظهار رسالة نجاح مع كود الغرفة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الغرفة بنجاح! كود الغرفة: ${room.id}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => OnlineLobbyScreen(
                  roomCode: room.id,
                  playerName: _nameController.text.trim(),
                  isHost: true,
                ),
          ),
        );
      } else if (mounted) {
        print('❌ فشل في إنشاء الغرفة');
        _showErrorDialog(
          'فشل في إنشاء الغرفة. تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
        );
      }
    } catch (e) {
      print('❌ خطأ أثناء إنشاء الغرفة: $e');
      if (mounted) {
        _showErrorDialog(
          'حدث خطأ أثناء إنشاء الغرفة: $e\n\nتحقق من:\n• الاتصال بالإنترنت\n• إعدادات Firebase',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCreatingRoom = false;
        });
      }
    }
  }

  void _joinRoom() async {
    setState(() => _isCreatingRoom = false);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final room = await _firebaseService.joinRoom(
        _roomCodeController.text.trim().toUpperCase(),
        _nameController.text.trim(),
      );

      if (room != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => OnlineLobbyScreen(
                  roomCode: room.id,
                  playerName: _nameController.text.trim(),
                  isHost: false,
                ),
          ),
        );
      } else if (mounted) {
        _showErrorDialog('غرفة غير موجودة أو ممتلئة');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('حدث خطأ أثناء الانضمام للغرفة: $e');
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
                              'أدخل اسمك أولاً، ثم اضغط على إنشاء غرفة لإنشاء كود جديد',
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
                                  Icon(Icons.add),
                                  SizedBox(width: 8),
                                  Text(
                                    'إنشاء غرفة',
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
                              '• لإنشاء غرفة جديدة: أدخل اسمك فقط واضغط "إنشاء غرفة"\n'
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
