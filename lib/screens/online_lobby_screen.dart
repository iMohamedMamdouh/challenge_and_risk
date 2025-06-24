import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_room.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart'; // Added import for HomeScreen
import 'online_question_screen.dart';
import 'room_settings_screen.dart';

class OnlineLobbyScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;
  final int timerDuration;

  const OnlineLobbyScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    required this.timerDuration,
  });

  @override
  State<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends State<OnlineLobbyScreen>
    with WidgetsBindingObserver {
  final FirebaseService _firebaseService = FirebaseService();
  GameRoom? _currentRoom;
  StreamSubscription<GameRoom?>? _roomSubscription;
  bool _isLoading = false;
  bool _isManuallyLeaving = false; // لتتبع ما إذا كان المستخدم يغادر بشكل يدوي

  @override
  void initState() {
    super.initState();
    // إضافة مراقب حالة التطبيق
    WidgetsBinding.instance.addObserver(this);

    _setupRoomListener();
    // تم إزالة مراقبة حالة الاتصال
    _firebaseService.startPeriodicCleanup(
      widget.roomCode,
    ); // التنظيف الدوري (إزالة اللاعبين المنقطعين معطلة)
    // تم إزالة تحديث حالة اللاعب
  }

  @override
  void dispose() {
    // إزالة مراقب حالة التطبيق
    WidgetsBinding.instance.removeObserver(this);

    // تم إزالة تحديث حالة اللاعب

    // تم إزالة إيقاف مراقبة عدم النشاط
    _firebaseService.stopPeriodicCleanup();

    _roomSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // تم إزالة مراقبة حالة الاتصال
        print('📱 التطبيق عاد للمقدمة');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // تم إزالة مراقبة حالة الاتصال
        print('📴 التطبيق ذهب للخلفية');
        break;
      case AppLifecycleState.detached:
        // تم إزالة مراقبة حالة الاتصال
        print('🔴 التطبيق تم إغلاقه');
        break;
      case AppLifecycleState.hidden:
        // تم إزالة مراقبة حالة الاتصال
        print('👁️ التطبيق مخفي');
        break;
    }
  }

  void _setupRoomListener() {
    _roomSubscription = _firebaseService
        .listenToRoom(widget.roomCode)
        .listen(
          (room) {
            if (mounted) {
              // إذا لم تعد الغرفة موجودة ولم يكن المستخدم يغادر يدوياً
              if (room == null && !_isManuallyLeaving) {
                print('🏠 الغرفة تم حذفها تلقائياً - العودة للشاشة الرئيسية');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم حذف الغرفة - جميع اللاعبين غادروا'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
                return;
              }

              // إذا كان المستخدم يغادر يدوياً ولم تعد الغرفة موجودة، لا نفعل شيئاً
              if (room == null && _isManuallyLeaving) {
                print(
                  '👤 الغرفة محذوفة والمستخدم يغادر يدوياً - لا إجراء مطلوب',
                );
                return;
              }

              setState(() {
                _currentRoom = room;
              });

              // التحقق من أن الغرفة لا تزال تحتوي على لاعبين (فقط إذا لم يكن المستخدم يغادر يدوياً)
              if (room != null && room.players.isEmpty && !_isManuallyLeaving) {
                print('👥 الغرفة فارغة تلقائياً - العودة للشاشة الرئيسية');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('جميع اللاعبين غادروا الغرفة'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
                Navigator.of(context).popUntil((route) => route.isFirst);
                return;
              }

              // إذا بدأت اللعبة، انتقل لشاشة الأسئلة
              if (room != null && room.state == GameState.inProgress) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => OnlineQuestionScreen(
                          roomCode: widget.roomCode,
                          playerName: widget.playerName,
                          timerDuration: widget.timerDuration,
                        ),
                  ),
                );
              }
            }
          },
          onError: (error) {
            if (mounted) {
              print('❌ خطأ في مراقبة الغرفة: $error');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطأ في الاتصال: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ كود الغرفة!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareRoomCode() {
    // TODO: إضافة مشاركة الكود عبر وسائل التواصل
    _copyRoomCode();
  }

  void _startGame() async {
    if (!widget.isHost || (_currentRoom?.players.length ?? 0) < 2) return;

    setState(() => _isLoading = true);

    try {
      final success = await _firebaseService.startGame(widget.roomCode);

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في بدء اللعبة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في بدء اللعبة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _leaveRoom() async {
    // العلم تم تعيينه مسبقاً في الكود الذي يستدعي هذه الدالة
    try {
      print('🚪 بدء مغادرة الغرفة من واجهة المستخدم...');
      await _firebaseService.permanentLeaveRoom(widget.roomCode);
      print('✅ تم ترك الغرفة بنجاح');
    } catch (e) {
      print('⚠️ خطأ أثناء مغادرة الغرفة: $e');
      // عرض رسالة خطأ للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء مغادرة الغرفة: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // العودة للصفحة الرئيسية (صفحة اختيار نوع اللعب)
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  void _goBackToSettings() async {
    // العلم تم تعيينه مسبقاً في PopScope أو عند الاستدعاء المباشر
    try {
      print('🔙 العودة للإعدادات - مغادرة الغرفة أولاً...');
      await _firebaseService.permanentLeaveRoom(widget.roomCode);
      print('✅ تم ترك الغرفة بنجاح');
    } catch (e) {
      print('⚠️ خطأ أثناء مغادرة الغرفة: $e');
      // عرض رسالة خطأ للمستخدم
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء مغادرة الغرفة: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      // الانتقال للإعدادات حتى لو حدث خطأ
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => RoomSettingsScreen(playerName: widget.playerName),
          ),
        );
      }
    }
  }

  // دالة طرد اللاعب (للمضيف فقط)
  Future<void> _kickPlayer(OnlinePlayer player) async {
    try {
      // تأكيد الطرد
      final shouldKick = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('طرد اللاعب'),
              content: Text(
                'هل أنت متأكد من أنك تريد طرد "${player.name}" من الغرفة؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('طرد'),
                ),
              ],
            ),
      );

      if (shouldKick == true) {
        // عرض مؤشر التحميل
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        // تنفيذ الطرد
        final success = await _firebaseService.kickPlayer(
          widget.roomCode,
          player.id,
        );

        if (mounted) {
          Navigator.of(context).pop(); // إغلاق مؤشر التحميل

          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم طرد "${player.name}" من الغرفة'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('فشل في طرد اللاعب'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // التأكد من إغلاق أي حوار مفتوح
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في طرد اللاعب: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final players = _currentRoom?.players ?? [];
    final maxPlayers = _currentRoom?.maxPlayers ?? 4;
    final canStart = widget.isHost && players.length >= 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // تنفيذ مغادرة الغرفة أولاً ثم السماح بالعودة
          if (widget.isHost) {
            _isManuallyLeaving = true; // تعيين العلم قبل مغادرة الغرفة
            _goBackToSettings();
          } else {
            // للاعبين العاديين: مغادرة الغرفة والعودة للصفحة السابقة
            _isManuallyLeaving = true; // تعيين العلم قبل مغادرة الغرفة
            try {
              print('🚪 مغادرة الغرفة عبر زر الرجوع...');
              await _firebaseService.permanentLeaveRoom(widget.roomCode);
              print('✅ تم ترك الغرفة بنجاح');
            } catch (e) {
              print('⚠️ خطأ أثناء مغادرة الغرفة: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('حدث خطأ أثناء مغادرة الغرفة: $e'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } finally {
              // العودة للصفحة السابقة
              if (mounted) {
                Navigator.pop(context);
              }
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.deepPurple.shade50,
        appBar: AppBar(
          title: Text(
            'غرفة ${widget.roomCode}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.deepPurple,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _isManuallyLeaving = true; // تعيين العلم قبل مغادرة الغرفة
              if (widget.isHost) {
                _goBackToSettings();
              } else {
                _leaveRoom();
              }
            },
            tooltip: widget.isHost ? 'العودة للإعدادات' : 'مغادرة الغرفة',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: _shareRoomCode,
              tooltip: 'مشاركة كود الغرفة',
            ),
          ],
        ),
        body:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Colors.deepPurple),
                )
                : SafeArea(
                  child: Column(
                    children: [
                      // Room code display - ثابت في الأعلى
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple.shade400,
                              Colors.deepPurple.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurple.withOpacity(0.3),
                              spreadRadius: 3,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.vpn_key,
                              color: Colors.white,
                              size: 30,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'كود الغرفة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.roomCode,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  IconButton(
                                    onPressed: _copyRoomCode,
                                    icon: const Icon(
                                      Icons.copy,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    tooltip: 'نسخ الكود',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'شارك هذا الكود مع أصدقائك',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Players section - يأخذ المساحة المتبقية
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
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
                              Row(
                                children: [
                                  const Icon(
                                    Icons.people,
                                    color: Colors.deepPurple,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'اللاعبون (${players.length}/$maxPlayers)',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: maxPlayers,
                                  itemBuilder: (context, index) {
                                    if (index < players.length) {
                                      final player = players[index];
                                      return _buildPlayerCard(player, false);
                                    } else {
                                      return _buildEmptySlot(index + 1);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Game controls - ثابت في الأسفل
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            if (widget.isHost) ...[
                              ElevatedButton(
                                onPressed: canStart ? _startGame : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: canStart ? 5 : 0,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      canStart
                                          ? Icons.play_arrow
                                          : players.length < 2
                                          ? Icons.hourglass_empty
                                          : Icons.wifi_off,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      canStart
                                          ? 'ابدأ اللعبة'
                                          : players.length < 2
                                          ? 'انتظار المزيد من اللاعبين...'
                                          : 'يوجد لاعبون غير متصلين',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.hourglass_empty,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'انتظار منشئ الغرفة لبدء اللعبة...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 15),

                            // Leave room button
                            OutlinedButton(
                              onPressed: () {
                                _isManuallyLeaving =
                                    true; // تعيين العلم قبل مغادرة الغرفة
                                _leaveRoom();
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(
                                  color: Colors.red,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.exit_to_app),
                                  SizedBox(width: 8),
                                  Text(
                                    'مغادرة الغرفة',
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
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildPlayerCard(OnlinePlayer player, bool canKick) {
    final bool isHost = player.isHost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.blue.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.person, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHost) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.amber.shade400,
                              Colors.amber.shade600,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Text(
                          'منشئ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.4),
                            spreadRadius: 1,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'متصل الآن',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // زر الطرد للمضيف فقط
          if (canKick) ...[
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _kickPlayer(player),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_remove,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'طرد',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptySlot(int slotNumber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(22.5),
            ),
            child: Icon(
              Icons.person_add_outlined,
              color: Colors.grey.shade500,
              size: 22,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'انتظار لاعب...',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'مكان فارغ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
