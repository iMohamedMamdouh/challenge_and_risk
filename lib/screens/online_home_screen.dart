import 'package:flutter/material.dart';

import '../models/game_room.dart';
import '../models/question.dart';
import '../services/firebase_service.dart';
import '../widgets/screens/online_home/available_rooms_widget.dart';
import '../widgets/screens/online_home/room_form_widget.dart';
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
  bool _isCreatingRoom = true;
  Map<String, dynamic>? _lastRoomData;
  bool _showAvailableRooms = false;
  List<GameRoom> _availableRooms = [];
  bool _isLoadingRooms = false;

  @override
  void initState() {
    super.initState();
    _performAutoCleanup();
    _checkForLastRoom();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _performAutoCleanup() async {
    try {
      print('🤖 تشغيل التنظيف التلقائي في الخلفية...');
      await _firebaseService.autoCleanEmptyRooms();
    } catch (e) {
      print('⚠️ فشل في التنظيف التلقائي: $e');
    }
  }

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

  void _rejoinLastRoom() async {
    if (_lastRoomData == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final roomCode = _lastRoomData!['roomCode'] as String;
      final playerName = _lastRoomData!['playerName'] as String;

      print('🔄 محاولة العودة للغرفة: $roomCode باسم: $playerName');

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
    setState(() => _isLoading = true);

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                RoomSettingsScreen(playerName: _nameController.text.trim()),
      ),
    );

    setState(() => _isLoading = false);
  }

  void _joinRoom() async {
    setState(() => _isLoading = true);

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

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

        String errorMessage = 'لم يتم العثور على الغرفة';

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

  void _toggleMode() {
    setState(() {
      _isCreatingRoom = !_isCreatingRoom;
      _roomCodeController.clear();
    });
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
                  _loadAvailableRooms();
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

  void _loadAvailableRooms() async {
    setState(() {
      _isLoadingRooms = true;
      _showAvailableRooms = true;
    });

    try {
      await _firebaseService.autoCleanEmptyRooms();
      final result = await _firebaseService.getAvailableRooms();

      print('📥 نتيجة استدعاء getAvailableRooms:');
      print('   نجح: ${result['success']}');
      print('   عدد الغرف: ${(result['rooms'] as List).length}');

      if (mounted && result['success'] == true) {
        final roomsData = result['rooms'] as List<dynamic>;

        // طباعة تفاصيل كل غرفة مُستقبلة
        for (int i = 0; i < roomsData.length; i++) {
          final roomData = roomsData[i] as Map<String, dynamic>;
          print('🏠 غرفة ${i + 1} (${roomData['id']}):');
          print('   👥 اللاعبين الخام: ${roomData['players']}');
          print('   ❓ الأسئلة الخام: ${roomData['questions']}');
          print('   🎯 الحد الأقصى: ${roomData['maxPlayers']}');
          print('   📊 نوع اللاعبين: ${roomData['players'].runtimeType}');
          print('   📊 نوع الأسئلة: ${roomData['questions'].runtimeType}');
          print(
            '   📏 طول قائمة اللاعبين: ${(roomData['players'] as List).length}',
          );
          print(
            '   📏 طول قائمة الأسئلة: ${(roomData['questions'] as List).length}',
          );
        }

        setState(() {
          _availableRooms =
              roomsData.map((roomData) {
                final data = roomData as Map<String, dynamic>;

                print('🔧 معالجة غرفة: ${data['id']}');

                // تحويل بيانات اللاعبين
                final playersData = data['players'] as List<dynamic>? ?? [];
                print('   👥 بيانات اللاعبين الواردة: $playersData');
                print('   👥 عدد اللاعبين الواردة: ${playersData.length}');

                final players =
                    playersData.map((playerData) {
                      print('   👤 معالجة لاعب: $playerData');
                      final playerMap = playerData as Map<String, dynamic>;
                      return OnlinePlayer(
                        id: playerMap['id'] ?? '',
                        name: playerMap['name'] ?? '',
                        score: playerMap['score'] ?? 0,
                        isHost: playerMap['isHost'] ?? false,
                        isOnline: playerMap['isOnline'] ?? true,
                      );
                    }).toList();

                print('   ✅ تم إنشاء ${players.length} لاعب');

                // تحويل بيانات الأسئلة
                final questionsData = data['questions'] as List<dynamic>? ?? [];
                print(
                  '   ❓ بيانات الأسئلة الواردة: ${questionsData.length} سؤال',
                );

                final questions =
                    questionsData.map((questionData) {
                      print('   ❓ معالجة سؤال: $questionData');
                      final questionMap = questionData as Map<String, dynamic>;
                      return Question.fromJson(questionMap);
                    }).toList();

                print('   ✅ تم إنشاء ${questions.length} سؤال');

                final gameRoom = GameRoom(
                  id: data['id'] ?? '',
                  hostId: data['hostId'] ?? '',
                  players: players,
                  maxPlayers: data['maxPlayers'] ?? 4,
                  state: GameState.values[data['state'] ?? 0],
                  questions: questions,
                  currentQuestionIndex: data['currentQuestionIndex'] ?? 0,
                  currentPlayerIndex: data['currentPlayerIndex'] ?? 0,
                  createdAt: DateTime.now(),
                  timerDuration: data['timerDuration'],
                );

                print('   🏁 تم إنشاء GameRoom بنجاح:');
                print(
                  '      👥 عدد اللاعبين النهائي: ${gameRoom.players.length}',
                );
                print(
                  '      ❓ عدد الأسئلة النهائي: ${gameRoom.questions.length}',
                );
                print('      🎯 الحد الأقصى: ${gameRoom.maxPlayers}');

                return gameRoom;
              }).toList();
        });

        print('🎉 تم تحديث الحالة النهائية:');
        print('   📊 عدد الغرف في _availableRooms: ${_availableRooms.length}');
        for (int i = 0; i < _availableRooms.length; i++) {
          final room = _availableRooms[i];
          print('   🏠 غرفة ${i + 1}: ${room.id}');
          print('      👥 لاعبين: ${room.players.length}/${room.maxPlayers}');
          print('      ❓ أسئلة: ${room.questions.length}');
        }
      }
    } catch (e) {
      print('❌ خطأ في تحميل الغرف: $e');
      print('🔍 تفاصيل الخطأ: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الغرف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRooms = false);
      }
    }
  }

  void _refreshAvailableRooms() {
    _loadAvailableRooms();
  }

  void _joinRoomFromList(String roomCode) async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال اسم اللاعب أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final room = await _firebaseService.joinRoomWithAutoClean(
        roomCode.toUpperCase(),
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
                  timerDuration: room.timerDuration ?? 10,
                ),
          ),
        );
      } else if (mounted) {
        _showDetailedErrorDialog(
          'فشل الانضمام للغرفة',
          'لم يتم العثور على الغرفة أو قد تكون ممتلئة',
          roomCode,
        );
      }
    } catch (e) {
      if (mounted) {
        _showDetailedErrorDialog(
          'خطأ في الانضمام',
          'حدث خطأ أثناء الانضمام للغرفة: $e',
          roomCode,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _hideAvailableRooms() {
    setState(() {
      _showAvailableRooms = false;
      _availableRooms.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'اللعب الأونلاين',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple.shade600,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 4,
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.deepPurple),
                    SizedBox(height: 16),
                    Text(
                      'جاري التحميل...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // زر العودة للغرفة
                    if (_lastRoomData != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.orange.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              spreadRadius: 3,
                              blurRadius: 15,
                              offset: const Offset(0, 8),
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
                                  size: 28,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'غرفة سابقة متاحة',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'الغرفة: ${_lastRoomData!['roomCode']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'اللاعب: ${_lastRoomData!['playerName']}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (_lastRoomData!['isHost'] == true)
                                    const Text(
                                      '(منشئ الغرفة)',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _rejoinLastRoom,
                                icon:
                                    _isLoading
                                        ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.orange.shade600,
                                                ),
                                          ),
                                        )
                                        : const Icon(Icons.play_arrow),
                                label: const Text(
                                  'العودة للغرفة',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.orange.shade600,
                                  elevation: 6,
                                  shadowColor: Colors.orange.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],

                    // استخدام RoomFormWidget
                    RoomFormWidget(
                      formKey: _formKey,
                      nameController: _nameController,
                      roomCodeController: _roomCodeController,
                      isLoading: _isLoading,
                      isCreatingRoom: _isCreatingRoom,
                      onCreateRoom: _createRoom,
                      onJoinRoom: _joinRoom,
                      onToggleMode: _toggleMode,
                      onShowAvailableRooms: () {
                        if (_showAvailableRooms) {
                          _hideAvailableRooms();
                        } else {
                          _loadAvailableRooms();
                        }
                      },
                      showAvailableRooms: _showAvailableRooms,
                      isLoadingRooms: _isLoadingRooms,
                    ),

                    // عرض الغرف المتاحة
                    if (_showAvailableRooms) ...[
                      const SizedBox(height: 20),
                      AvailableRoomsWidget(
                        availableRooms: _availableRooms,
                        isLoading: _isLoadingRooms,
                        onJoinRoom: _joinRoomFromList,
                        onRefresh: _refreshAvailableRooms,
                      ),
                    ],

                    const SizedBox(height: 30),

                    // معلومات إضافية
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade50, Colors.cyan.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'كيفية اللعب الأونلاين:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoItem(
                            '• لإنشاء غرفة جديدة: أدخل اسمك واضغط "إنشاء غرفة جديدة"',
                            Icons.add_circle_outline,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoItem(
                            '• للانضمام لغرفة موجودة: أدخل اسمك وكود الغرفة',
                            Icons.login,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoItem(
                            '• شارك كود الغرفة مع أصدقائك بعد إنشائها',
                            Icons.share,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoItem(
                            '• انتظر حتى ينضم جميع اللاعبين وابدأ اللعب!',
                            Icons.play_arrow,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoItem(String text, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.blue.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
