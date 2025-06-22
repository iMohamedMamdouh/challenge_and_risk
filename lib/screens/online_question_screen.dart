import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_room.dart';
import '../models/question.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart'; // Added import for HomeScreen
import 'online_challenge_screen.dart';
import 'online_result_screen.dart';

class OnlineQuestionScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final int? timerDuration;

  const OnlineQuestionScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    this.timerDuration,
  });

  @override
  State<OnlineQuestionScreen> createState() => _OnlineQuestionScreenState();
}

class _OnlineQuestionScreenState extends State<OnlineQuestionScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  GameRoom? _currentRoom;
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int _currentPlayerIndex = 0;
  bool _isAnswering = false;
  bool _isGameFinished = false;
  int? _selectedAnswerIndex;
  final Random _random = Random();

  // نظام الدوران المحسن
  List<int> _availablePlayerIndices = [];
  int? _lastPlayerIndex; // لتجنب تكرار نفس اللاعب مرتين متتاليتين

  // متغيرات جديدة لعرض الإجابة الصحيحة
  bool _showingCorrectAnswer = false;
  int? _correctAnswerIndex;

  @override
  void initState() {
    super.initState();
    _listenToGameUpdates();
    // بدء مراقبة عدم النشاط في شاشة الأسئلة أيضاً
    _firebaseService.startInactivityMonitoring(widget.roomCode);
    _firebaseService.startPeriodicCleanup(
      widget.roomCode,
    ); // التنظيف الدوري (إزالة اللاعبين المنقطعين معطلة)
    // تحديث حالة اللاعب الحالي كمتصل
    _firebaseService.updatePlayerStatus(widget.roomCode, true);
  }

  @override
  void dispose() {
    // تحديث حالة اللاعب كغير متصل عند مغادرة الصفحة
    _firebaseService.updatePlayerStatus(widget.roomCode, false);

    // إيقاف مراقبة عدم النشاط والتنظيف الدوري
    _firebaseService.stopInactivityMonitoring();
    _firebaseService.stopPeriodicCleanup();

    super.dispose();
  }

  void _listenToGameUpdates() {
    _firebaseService
        .listenToRoom(widget.roomCode)
        .listen((room) {
          if (room != null && mounted) {
            // التحقق من حالة انتهاء اللعبة بفائز واحد
            if (room.state == GameState.finished) {
              _handleGameFinished(room);
              return;
            }

            final bool questionChanged =
                _currentQuestionIndex != room.currentQuestionIndex;
            final bool playerChanged =
                _currentPlayerIndex != room.currentPlayerIndex;

            // التحقق من وجود تحدي نشط
            final bool hasChallengeActive = room.currentChallenge != null;

            setState(() {
              _currentRoom = room;
              if (_questions.isEmpty) {
                _questions = room.questions;
              }

              // تحديث فوري للتغييرات
              if (questionChanged) {
                _currentQuestionIndex = room.currentQuestionIndex;
                _selectedAnswerIndex = null; // مسح الإجابة عند السؤال الجديد
                _isAnswering = false;
              }

              if (playerChanged) {
                _currentPlayerIndex = room.currentPlayerIndex;
              }
            });

            // تهيئة النظام إذا لم يتم تهيئته
            if (_availablePlayerIndices.isEmpty && room.players.isNotEmpty) {
              _initializeRound();
            }

            // إشعار عند تغيير الدور
            if (playerChanged && mounted) {
              _showTurnNotification();
            }

            // إشعار حالة التحدي
            if (hasChallengeActive && mounted && !_isCurrentPlayerTurn()) {
              _showChallengeWaitingMessage();
            }
          }
        })
        .onError((error) {
          print('خطأ في تحميل بيانات اللعبة: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطأ في تحميل بيانات اللعبة: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
  }

  void _showTurnNotification() {
    if (_isCurrentPlayerTurn()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.play_arrow, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'حان دورك! اختر إجابتك',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // عرض رسالة انتظار التحدي
  void _showChallengeWaitingMessage() {
    final currentPlayerName = _getCurrentPlayerName();
    if (currentPlayerName.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.sports_gymnastics, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$currentPlayerName ينفذ التحدي... انتظار انتهائه',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // تهيئة جولة جديدة مع منع التكرار
  void _initializeRound() {
    if (_currentRoom != null && _currentRoom!.players.isNotEmpty) {
      _availablePlayerIndices = List.generate(
        _currentRoom!.players.length,
        (index) => index,
      );

      // في السؤال الأول، ابدأ باللاعب الأول
      if (_currentQuestionIndex == 0) {
        _currentPlayerIndex = 0;
        _lastPlayerIndex = null;
        _availablePlayerIndices.remove(0);
      } else {
        // لا نغير الدور محلياً، فقط نستمع لتحديثات Firebase
        _availablePlayerIndices.remove(_currentPlayerIndex);
      }
    }
  }

  // اختيار لاعب عشوائي مع منع التكرار (فقط للمضيف)
  void _selectRandomPlayer() {
    // فقط المضيف يمكنه تغيير الأدوار لتجنب التضارب
    if (_currentRoom == null ||
        _currentRoom!.players.isEmpty ||
        !_isCurrentPlayerHost()) {
      return;
    }

    if (_availablePlayerIndices.isEmpty) {
      // بدء جولة جديدة
      _currentPlayerIndex = 0;
      _lastPlayerIndex = null;
      _availablePlayerIndices = List.generate(
        _currentRoom!.players.length,
        (index) => index,
      );
    }

    // إنشاء قائمة اللاعبين المؤهلين (استبعاد اللاعب السابق إذا أمكن)
    List<int> eligiblePlayers = List.from(_availablePlayerIndices);

    if (eligiblePlayers.length > 1 && _lastPlayerIndex != null) {
      eligiblePlayers.remove(_lastPlayerIndex);
    }

    // إذا لم يبق لاعبين مؤهلين، استخدم جميع المتاحين
    if (eligiblePlayers.isEmpty) {
      eligiblePlayers = List.from(_availablePlayerIndices);
    }

    // اختيار عشوائي
    final randomIndex = _random.nextInt(eligiblePlayers.length);
    final selectedPlayer = eligiblePlayers[randomIndex];

    _lastPlayerIndex = _currentPlayerIndex;
    _currentPlayerIndex = selectedPlayer;
    _availablePlayerIndices.remove(selectedPlayer);

    // تحديث Firebase مع الدور الجديد (فقط للمضيف)
    _updateCurrentPlayerInFirebase();
  }

  // تحديث الدور في Firebase (فقط للمضيف)
  Future<void> _updateCurrentPlayerInFirebase() async {
    try {
      // فقط المضيف يمكنه تحديث الأدوار
      if (_isCurrentPlayerHost()) {
        await _firebaseService.updateCurrentPlayer(
          widget.roomCode,
          _currentPlayerIndex,
        );
      }
    } catch (e) {
      print('خطأ في تحديث الدور: $e');
    }
  }

  // التحقق من كون اللاعب الحالي هو المضيف
  bool _isCurrentPlayerHost() {
    if (_currentRoom == null) return false;
    return _currentRoom!.players.any(
      (player) => player.name == widget.playerName && player.isHost,
    );
  }

  // تحديد الإجابة بدون إرسالها فوراً
  void _selectAnswer(int index) {
    if (!_isAnswering && _isCurrentPlayerTurn()) {
      setState(() {
        _selectedAnswerIndex = index;
      });
    }
  }

  // تأكيد الإجابة وإرسالها
  void _confirmAnswer() async {
    if (_selectedAnswerIndex == null ||
        _isAnswering ||
        !_isCurrentPlayerTurn()) {
      return;
    }

    setState(() => _isAnswering = true);

    try {
      // إرسال الإجابة إلى Firebase أولاً
      print('📤 إرسال الإجابة للخادم...');
      final success = await _firebaseService.submitAnswer(
        widget.roomCode,
        _selectedAnswerIndex!,
      );

      if (!success) {
        throw Exception('فشل في إرسال الإجابة');
      }

      final currentQuestion = _questions[_currentQuestionIndex];
      final isCorrect =
          _selectedAnswerIndex == currentQuestion.correctAnswerIndex;
      final currentPlayer = _currentRoom!.players[_currentPlayerIndex];

      print('✅ تم إرسال الإجابة - النتيجة: ${isCorrect ? "صحيحة" : "خاطئة"}');

      if (isCorrect) {
        // إجابة صحيحة - معالجة النقاط في Firebase
        print('🎯 إجابة صحيحة - تحديث النقاط...');

        final processSuccess = await _firebaseService.processAnswer(
          widget.roomCode,
          true,
        );

        if (processSuccess) {
          // عرض الإجابة الصحيحة للجميع لمدة 3 ثوانٍ
          await _showCorrectAnswerToAll(currentQuestion.correctAnswerIndex);

          _showResultDialog(true, () {
            // انتقال للسؤال التالي أو اللاعب التالي
            _handleNextTurn();
          });
        } else {
          throw Exception('فشل في معالجة الإجابة الصحيحة');
        }
      } else {
        // إجابة خاطئة - عرض الإجابة الصحيحة ثم انتقال للتحدي
        print('❌ إجابة خاطئة - عرض الإجابة الصحيحة...');

        // عرض الإجابة الصحيحة أولاً
        await _showCorrectAnswerToAll(currentQuestion.correctAnswerIndex);

        // معالجة الإجابة الخاطئة في Firebase
        await _firebaseService.processAnswer(widget.roomCode, false);

        // تعيين حالة التحدي
        await _firebaseService.setChallenge(
          widget.roomCode,
          'challenge_required',
        );

        _showChallengeDialog();
      }
    } catch (e) {
      print('❌ خطأ في معالجة الإجابة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnswering = false);
      }
    }
  }

  void _showResultDialog(bool isCorrect, VoidCallback onNext) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                isCorrect ? Colors.green.shade50 : Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Text(
                  isCorrect ? 'إجابة صحيحة!' : 'إجابة خاطئة!',
                  style: TextStyle(
                    color: isCorrect ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              isCorrect
                  ? 'أحسنت! لقد حصلت على نقطة'
                  : 'للأسف، الإجابة غير صحيحة',
              style: TextStyle(
                fontSize: 16,
                color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onNext();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCorrect ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('متابعة'),
              ),
            ],
          ),
    );
  }

  // عرض حوار التحدي
  void _showChallengeDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(Icons.sports_gymnastics, color: Colors.red, size: 30),
                const SizedBox(width: 10),
                const Text(
                  'تحدي مطلوب!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'الإجابة خاطئة! عليك تنفيذ تحدي قبل المتابعة.',
              style: TextStyle(fontSize: 16, color: Colors.red),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToChallenge();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('بدء التحدي'),
              ),
            ],
          ),
    );
  }

  // الانتقال لشاشة التحدي
  void _navigateToChallenge() {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => OnlineChallengeScreen(
              roomCode: widget.roomCode,
              playerName: widget.playerName,
              onChallengeComplete: _onChallengeComplete,
            ),
      ),
    );
  }

  // إكمال التحدي
  void _onChallengeComplete() async {
    try {
      print('✅ إكمال التحدي...');

      // إزالة حالة التحدي من Firebase
      await _firebaseService.completeChallenge(widget.roomCode);

      // العودة لشاشة الأسئلة
      if (mounted) {
        Navigator.pop(context);
        _handleNextTurn();
      }
    } catch (e) {
      print('❌ خطأ في إكمال التحدي: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إكمال التحدي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // معالجة الانتقال للدور التالي
  void _handleNextTurn() {
    if (!_isCurrentPlayerHost()) {
      // إذا لم يكن المضيف، فقط انتظر التحديثات من Firebase
      print('⏳ انتظار تحديث الدور من المضيف...');
      return;
    }

    // فقط المضيف يمكنه تغيير الأدوار والأسئلة
    print('👑 المضيف يقوم بتحديث الدور...');

    setState(() {
      _selectedAnswerIndex = null;

      // تحقق من انتهاء السؤال الحالي
      if (_currentQuestionIndex + 1 >= _questions.length) {
        _isGameFinished = true;
        _navigateToResults();
        return;
      }

      // الانتقال للسؤال التالي
      _currentQuestionIndex++;
      _selectRandomPlayer();
    });
  }

  void _nextQuestion() {
    // فقط المضيف يمكنه تغيير الأسئلة
    if (!_isCurrentPlayerHost()) return;

    setState(() {
      _selectedAnswerIndex = null;
      _currentQuestionIndex++;

      if (_currentQuestionIndex >= _questions.length) {
        _isGameFinished = true;
        _navigateToResults();
        return;
      }

      _lastPlayerIndex = _currentPlayerIndex;
      _selectRandomPlayer();
    });
  }

  // مغادرة الغرفة
  Future<void> _leaveRoom() async {
    try {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('مغادرة الغرفة'),
              content: const Text('هل أنت متأكد من أنك تريد مغادرة الغرفة؟'),
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
                  child: const Text('مغادرة'),
                ),
              ],
            ),
      );

      if (shouldLeave == true) {
        // عرض مؤشر التحميل
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(child: CircularProgressIndicator()),
        );

        // مغادرة الغرفة نهائياً
        final success = await _firebaseService.permanentLeaveRoom(
          widget.roomCode,
        );

        if (mounted) {
          Navigator.of(context).pop(); // إغلاق مؤشر التحميل

          if (success) {
            // العودة إلى الصفحة الرئيسية (صفحة اختيار نوع اللعب)
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('حدث خطأ أثناء مغادرة الغرفة'),
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
          Navigator.of(context).pop(); // إغلاق مؤشر التحميل إذا كان مفتوحاً
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToResults() {
    final sortedPlayersData =
        _currentRoom!.players
            .map(
              (player) => {
                'id': player.id,
                'name': player.name,
                'score': player.score,
                'isHost': player.isHost,
                'isOnline': player.isOnline,
              },
            )
            .toList();

    sortedPlayersData.sort(
      (a, b) => (b['score'] as int).compareTo(a['score'] as int),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => OnlineResultScreen(
              roomCode: widget.roomCode,
              players: sortedPlayersData,
              totalQuestions: _questions.length,
            ),
      ),
    );
  }

  // الحصول على اسم اللاعب الحالي
  String _getCurrentPlayerName() {
    if (_currentRoom == null ||
        _currentPlayerIndex < 0 ||
        _currentPlayerIndex >= _currentRoom!.players.length) {
      return '';
    }
    return _currentRoom!.players[_currentPlayerIndex].name;
  }

  bool _isCurrentPlayerTurn() {
    return _getCurrentPlayerName() == widget.playerName;
  }

  // دالة طرد اللاعب (للمضيف فقط)
  Future<void> _showKickPlayerDialog(OnlinePlayer player) async {
    try {
      // تأكيد الطرد
      final shouldKick = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade600, size: 28),
                  const SizedBox(width: 10),
                  const Text('طرد اللاعب'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'هل أنت متأكد من أنك تريد طرد "${player.name}" من اللعبة؟',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'سيتم إخراج اللاعب من اللعبة نهائياً',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                content: Text('تم طرد "${player.name}" من اللعبة'),
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

  // دالة لبناء عنصر إرشادات
  Widget _buildInstructionItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade600, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  Widget _buildPlayerCard(OnlinePlayer player, bool isCurrentPlayer) {
    final bool isOnline = player.isOnline;
    final bool canKick =
        _isCurrentPlayerHost() &&
        !player.isHost &&
        player.name != widget.playerName;

    return GestureDetector(
      onLongPress: canKick ? () => _showKickPlayerDialog(player) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors:
                isCurrentPlayer
                    ? [Colors.green.shade400, Colors.green.shade600]
                    : isOnline
                    ? [Colors.deepPurple.shade300, Colors.deepPurple.shade500]
                    : [Colors.grey.shade400, Colors.grey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isCurrentPlayer
                    ? Colors.green.shade300
                    : isOnline
                    ? Colors.deepPurple.shade300
                    : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isCurrentPlayer
                      ? Colors.green
                      : isOnline
                      ? Colors.deepPurple
                      : Colors.grey)
                  .withValues(alpha: 0.3),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isCurrentPlayer ? Icons.play_arrow : Icons.person,
                    color:
                        isCurrentPlayer
                            ? Colors.green.shade700
                            : isOnline
                            ? Colors.deepPurple.shade700
                            : Colors.grey.shade700,
                    size: 14,
                  ),
                ),
                // مؤشر حالة الاتصال
                if (!isOnline)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Flexible(
              child: Text(
                player.name,
                style: TextStyle(
                  color:
                      isOnline
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${player.score}',
              style: TextStyle(
                color:
                    isOnline
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'نقطة',
              style: TextStyle(
                color:
                    isOnline
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.6),
                fontSize: 7,
              ),
            ),
            // مؤشر حالة الاتصال النصي
            if (!isOnline)
              Text(
                'غير متصل',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 6,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Color _getButtonColor(int index) {
    if (_selectedAnswerIndex == index) {
      return Colors.deepPurple.shade600;
    }
    return Colors.white;
  }

  Color _getTextColor(int index) {
    if (_selectedAnswerIndex == index) {
      return Colors.white;
    }
    return Colors.deepPurple.shade700;
  }

  Color _getBorderColor(int index) {
    if (_selectedAnswerIndex == index) {
      return Colors.deepPurple.shade600;
    }
    return Colors.deepPurple.shade300;
  }

  // معالجة انتهاء اللعبة
  void _handleGameFinished(GameRoom room) {
    if (_isGameFinished) return; // تجنب الاستدعاء المتكرر

    setState(() {
      _isGameFinished = true;
    });

    // إذا انتهت اللعبة بسبب بقاء لاعب واحد فقط
    if (room.players.length == 1) {
      final winner = room.players.first;
      _showSinglePlayerWinDialog(winner);
    } else {
      // انتهاء عادي - الذهاب لشاشة النتائج
      _navigateToResults();
    }
  }

  // عرض حوار الفوز للاعب الوحيد المتبقي
  void _showSinglePlayerWinDialog(OnlinePlayer winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Colors.amber.shade600,
                  size: 30,
                ),
                const SizedBox(width: 10),
                const Text(
                  'تهانينا! 🎉',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade100, Colors.amber.shade200],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.star, color: Colors.amber.shade600, size: 60),
                      const SizedBox(height: 10),
                      Text(
                        winner.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'أنت الفائز!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'النقاط: ${winner.score}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'غادر جميع اللاعبين الآخرين من الغرفة',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // العودة إلى الصفحة الرئيسية (صفحة اختيار نوع اللعب)
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home),
                    SizedBox(width: 8),
                    Text(
                      'العودة للقائمة الرئيسية',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildActionButton() {
    // التحقق من وجود تحدي نشط
    if (_currentRoom?.currentChallenge != null) {
      final currentPlayerName = _getCurrentPlayerName();
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_gymnastics, color: Colors.orange, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isCurrentPlayerTurn()
                    ? 'عليك تنفيذ التحدي للمتابعة'
                    : '$currentPlayerName ينفذ التحدي...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // إذا كان يجيب
    if (_isAnswering) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'جاري المعالجة...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    // الزر العادي
    return ElevatedButton(
      onPressed:
          (_selectedAnswerIndex != null && _isCurrentPlayerTurn())
              ? _confirmAnswer
              : null,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            (_selectedAnswerIndex != null && _isCurrentPlayerTurn())
                ? Colors.deepPurple
                : Colors.grey.shade400,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation:
            (_selectedAnswerIndex != null && _isCurrentPlayerTurn()) ? 8 : 2,
        shadowColor: Colors.deepPurple.withValues(alpha: 0.3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedAnswerIndex != null ? Icons.send : Icons.touch_app,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _selectedAnswerIndex != null
                ? 'تأكيد الإجابة'
                : _isCurrentPlayerTurn()
                ? 'اختر إجابة أولاً'
                : 'انتظار دورك',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGameFinished) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Check if room data is loaded
    if (_currentRoom == null) {
      return Scaffold(
        backgroundColor: Colors.deepPurple.shade50,
        appBar: AppBar(
          title: Text(
            'غرفة ${widget.roomCode}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.deepPurple,
          centerTitle: true,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              onPressed: _leaveRoom,
              icon: const Icon(Icons.exit_to_app, color: Colors.white),
              tooltip: 'مغادرة الغرفة',
            ),
          ],
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.deepPurple),
              SizedBox(height: 16),
              Text(
                'جاري تحميل بيانات الغرفة...',
                style: TextStyle(fontSize: 16, color: Colors.deepPurple),
              ),
            ],
          ),
        ),
      );
    }

    final currentQuestion =
        _currentQuestionIndex < _questions.length
            ? _questions[_currentQuestionIndex]
            : null;

    if (currentQuestion == null) {
      return const Scaffold(body: Center(child: Text('جاري تحميل الأسئلة...')));
    }

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: Text(
          'غرفة ${widget.roomCode}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // أيقونة الإرشادات للمشرف
          if (_isCurrentPlayerHost())
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade600,
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            const Text('إرشادات المشرف'),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'كمشرف للغرفة، يمكنك:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 15),
                            _buildInstructionItem(
                              Icons.touch_app,
                              'اضغط مطولاً على أي لاعب لطرده من اللعبة',
                            ),
                            const SizedBox(height: 12),
                            _buildInstructionItem(
                              Icons.wifi_off,
                              'اللاعبون غير المتصلين يظهرون باللون الرمادي',
                            ),
                            const SizedBox(height: 12),
                            _buildInstructionItem(
                              Icons.circle,
                              'النقطة الحمراء تعني عدم الاتصال',
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('فهمت'),
                          ),
                        ],
                      ),
                );
              },
              icon: const Icon(Icons.help_outline, color: Colors.white),
              tooltip: 'إرشادات المشرف',
            ),
          IconButton(
            onPressed: _leaveRoom,
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            tooltip: 'مغادرة الغرفة',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // المحتوى القابل للتمرير
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // شريط التقدم والمعلومات
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.2),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'السؤال ${_currentQuestionIndex + 1}/${_questions.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _isCurrentPlayerTurn()
                                          ? Colors.green.shade100
                                          : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        _isCurrentPlayerTurn()
                                            ? Colors.green.shade300
                                            : Colors.orange.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isCurrentPlayerTurn()
                                          ? Icons.play_arrow
                                          : Icons.hourglass_empty,
                                      color:
                                          _isCurrentPlayerTurn()
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isCurrentPlayerTurn()
                                          ? 'دورك'
                                          : 'دور ${_getCurrentPlayerName()}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _isCurrentPlayerTurn()
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value:
                                (_currentQuestionIndex + 1) / _questions.length,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple,
                            ),
                            minHeight: 6,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // قائمة اللاعبين الأفقية
                    Container(
                      height: 100,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children:
                            _currentRoom!.players.asMap().entries.map((entry) {
                              final index = entry.key;
                              final player = entry.value;
                              final isCurrentPlayer =
                                  index == _currentPlayerIndex;
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: _buildPlayerCard(
                                    player,
                                    isCurrentPlayer,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),

                    // نص إرشادي للمشرف
                    if (_isCurrentPlayerHost() &&
                        _currentRoom!.players.any((p) => !p.isOnline))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'اضغط مطولاً على أي لاعب غير متصل لطرده',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // السؤال
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple.shade50,
                            Colors.deepPurple.shade100,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.deepPurple.shade200),
                      ),
                      child: Text(
                        currentQuestion.questionText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade800,
                          height: 1.4,
                        ),
                      ),
                    ),

                    // خيارات الإجابة - تظهر فقط للاعب النشط أو عند عرض الإجابة الصحيحة
                    if (_isCurrentPlayerTurn() || _showingCorrectAnswer) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.2),
                              spreadRadius: 3,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // عنوان القسم
                            if (!_showingCorrectAnswer)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.deepPurple.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      color: Colors.deepPurple.shade600,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'اختر إجابتك:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.deepPurple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_showingCorrectAnswer)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade600,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'الإجابة الصحيحة:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),

                            // خيارات الإجابة
                            ...currentQuestion.options.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final option = entry.value;
                              final isSelected = _selectedAnswerIndex == index;
                              final isCorrectAnswer =
                                  _showingCorrectAnswer &&
                                  _correctAnswerIndex == index;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  elevation:
                                      isSelected || isCorrectAnswer ? 6 : 2,
                                  borderRadius: BorderRadius.circular(12),
                                  shadowColor:
                                      isCorrectAnswer
                                          ? Colors.green.withValues(alpha: 0.4)
                                          : isSelected
                                          ? Colors.deepPurple.withValues(
                                            alpha: 0.4,
                                          )
                                          : Colors.grey.withValues(alpha: 0.2),
                                  child: InkWell(
                                    onTap:
                                        !_isAnswering &&
                                                _isCurrentPlayerTurn() &&
                                                !_showingCorrectAnswer
                                            ? () => _selectAnswer(index)
                                            : null,
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color:
                                            isCorrectAnswer
                                                ? Colors.green.shade500
                                                : isSelected
                                                ? Colors.deepPurple.shade600
                                                : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              isCorrectAnswer
                                                  ? Colors.green.shade300
                                                  : isSelected
                                                  ? Colors.deepPurple.shade600
                                                  : Colors.deepPurple.shade300,
                                          width: 2,
                                        ),
                                        gradient:
                                            isCorrectAnswer
                                                ? LinearGradient(
                                                  colors: [
                                                    Colors.green.shade400,
                                                    Colors.green.shade600,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                                : isSelected
                                                ? LinearGradient(
                                                  colors: [
                                                    Colors.deepPurple.shade500,
                                                    Colors.deepPurple.shade700,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                                : null,
                                      ),
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color:
                                                  isCorrectAnswer || isSelected
                                                      ? Colors.white
                                                      : Colors
                                                          .deepPurple
                                                          .shade600,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (isCorrectAnswer ||
                                                              isSelected
                                                          ? Colors.white
                                                          : Colors.deepPurple)
                                                      .withValues(alpha: 0.3),
                                                  spreadRadius: 1,
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Text(
                                                String.fromCharCode(
                                                  65 + index,
                                                ), // A, B, C, D
                                                style: TextStyle(
                                                  color:
                                                      isCorrectAnswer ||
                                                              isSelected
                                                          ? (isCorrectAnswer
                                                              ? Colors
                                                                  .green
                                                                  .shade700
                                                              : Colors
                                                                  .deepPurple
                                                                  .shade700)
                                                          : Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    isCorrectAnswer ||
                                                            isSelected
                                                        ? Colors.white
                                                        : Colors
                                                            .deepPurple
                                                            .shade700,
                                              ),
                                            ),
                                          ),
                                          if (isCorrectAnswer) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Colors.green.shade600,
                                                size: 18,
                                              ),
                                            ),
                                          ] else if (isSelected) ...[
                                            const SizedBox(width: 12),
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Icon(
                                                Icons.check,
                                                color:
                                                    Colors.deepPurple.shade600,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ] else ...[
                      // رسالة للاعبين الآخرين
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.1),
                              spreadRadius: 3,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.hourglass_empty,
                              size: 48,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'انتظار ${_getCurrentPlayerName()}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'يقوم بالإجابة على السؤال...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.orange.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.orange.shade600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'في الانتظار...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 80), // مساحة للزر السفلي
                  ],
                ),
              ),
            ),

            // زر التأكيد الثابت في الأسفل - يظهر فقط للاعب النشط
            if (_isCurrentPlayerTurn() && !_showingCorrectAnswer)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.3),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _buildActionButton(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // عرض الإجابة الصحيحة للجميع
  Future<void> _showCorrectAnswerToAll(int correctIndex) async {
    if (mounted) {
      setState(() {
        _showingCorrectAnswer = true;
        _correctAnswerIndex = correctIndex;
      });

      // عرض لمدة 3 ثوانٍ
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        setState(() {
          _showingCorrectAnswer = false;
          _correctAnswerIndex = null;
        });
      }
    }
  }
}
