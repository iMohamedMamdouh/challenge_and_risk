import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/game_room.dart';
import '../models/question.dart';
import '../services/audio_service.dart';
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
  final AudioService _audioService = AudioService();
  GameRoom? _currentRoom;
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int _currentPlayerIndex = 0;
  bool _isAnswering = false;
  bool _isGameFinished = false;
  int? _selectedAnswerIndex;

  // متغيرات جديدة لعرض الإجابة الصحيحة
  bool _showingCorrectAnswer = false;
  int? _correctAnswerIndex;

  // متغيرات جديدة للتحدي والمؤثرات الصوتية
  bool _isChallengeActive = false;
  String _currentChallenge = '';

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _listenToGameUpdates();
    _firebaseService.startPeriodicCleanup(
      widget.roomCode,
    ); // التنظيف الدوري (إزالة اللاعبين المنقطعين معطلة)
  }

  @override
  void dispose() {
    // تم إزالة إيقاف مراقبة عدم النشاط
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

            // إشعار حالة التحدي
            if (hasChallengeActive && mounted && !_isCurrentPlayerTurn()) {
              _showChallengeWaitingMessage();
            }

            // التحقق من وجود تحدي نشط للاعب الحالي
            if (hasChallengeActive &&
                mounted &&
                _isCurrentPlayerTurn() &&
                !_isChallengeActive) {
              _showChallenge();
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
      _currentPlayerIndex = 0;
    }
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

      print('✅ تم إرسال الإجابة - النتيجة: ${isCorrect ? "صحيحة" : "خاطئة"}');

      if (isCorrect) {
        // إجابة صحيحة - معالجة النقاط في Firebase
        print('🎯 إجابة صحيحة - تحديث النقاط...');

        // تشغيل صوت الإجابة الصحيحة
        await _audioService.playSound('correct_answer.mp3');

        final processSuccess = await _firebaseService.processAnswer(
          widget.roomCode,
          true,
        );

        if (processSuccess) {
          // عرض الإجابة الصحيحة للجميع لمدة 3 ثوانٍ
          await _showCorrectAnswerToAll(currentQuestion.correctAnswerIndex);

          // إشعار بالإجابة الصحيحة
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'إجابة صحيحة! +1 نقطة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          throw Exception('فشل في معالجة الإجابة الصحيحة');
        }
      } else {
        // إجابة خاطئة - عرض الإجابة الصحيحة ثم انتقال للتحدي
        print('❌ إجابة خاطئة - عرض الإجابة الصحيحة...');

        // تشغيل صوت الإجابة الخاطئة
        await _audioService.playSound('wrong_answer.mp3');

        // عرض الإجابة الصحيحة أولاً
        await _showCorrectAnswerToAll(currentQuestion.correctAnswerIndex);

        // معالجة الإجابة الخاطئة في Firebase
        final processSuccess = await _firebaseService.processAnswer(
          widget.roomCode,
          false,
        );

        if (processSuccess) {
          // تعيين حالة التحدي
          await _firebaseService.setChallenge(
            widget.roomCode,
            'challenge_required',
          );

          // عرض التحدي للاعب الحالي
          if (mounted) {
            _showChallenge();
          }

          // إشعار بالإجابة الخاطئة
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'إجابة خاطئة! يجب تنفيذ تحدي',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          throw Exception('فشل في معالجة الإجابة الخاطئة');
        }
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

      // إزالة حالة التحدي والانتقال للاعب التالي
      await _firebaseService.completeChallengeAndSwitchTurn(widget.roomCode);

      // العودة لشاشة الأسئلة
      if (mounted) {
        Navigator.pop(context);
        // لا نحتاج لاستدعاء _handleNextTurn لأن Firebase سيتولى تحديث الدور
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

  // معالجة انتهاء اللعبة
  void _handleGameFinished(GameRoom room) {
    if (_isGameFinished) return; // تجنب الاستدعاء المتكرر

    setState(() {
      _isGameFinished = true;
    });

    // انتهاء عادي - الذهاب لشاشة النتائج
    _navigateToResults();
  }

  Widget _buildPlayerCard(OnlinePlayer player, bool isCurrentPlayer) {
    final bool isOnline = player.isOnline;

    return Container(
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
                  isOnline ? Colors.white : Colors.white.withValues(alpha: 0.7),
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

  // بناء بطاقة السؤال
  Widget _buildQuestionCard(Question question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 3,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // عنوان السؤال
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.shade200),
            ),
            child: Text(
              question.questionText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple.shade800,
                height: 1.4,
              ),
            ),
          ),

          // عرض الاختيارات - فقط للاعب النشط أو عند عرض الإجابة الصحيحة
          if (_isCurrentPlayerTurn() || _showingCorrectAnswer) ...[
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
                  border: Border.all(color: Colors.deepPurple.shade200),
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
                  border: Border.all(color: Colors.green.shade200),
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
            ...question.options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = _selectedAnswerIndex == index;
              final isCorrectAnswer =
                  _showingCorrectAnswer && _correctAnswerIndex == index;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  elevation: isSelected || isCorrectAnswer ? 6 : 2,
                  borderRadius: BorderRadius.circular(12),
                  shadowColor:
                      isCorrectAnswer
                          ? Colors.green.withOpacity(0.4)
                          : isSelected
                          ? Colors.deepPurple.withOpacity(0.4)
                          : Colors.grey.withOpacity(0.2),
                  child: InkWell(
                    onTap:
                        !_isAnswering &&
                                _isCurrentPlayerTurn() &&
                                !_showingCorrectAnswer
                            ? () => _selectAnswer(index)
                            : null,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
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
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  isCorrectAnswer || isSelected
                                      ? Colors.white
                                      : Colors.deepPurple.shade600,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: (isCorrectAnswer || isSelected
                                          ? Colors.white
                                          : Colors.deepPurple)
                                      .withOpacity(0.3),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                String.fromCharCode(65 + index), // A, B, C, D
                                style: TextStyle(
                                  color:
                                      isCorrectAnswer || isSelected
                                          ? (isCorrectAnswer
                                              ? Colors.green.shade700
                                              : Colors.deepPurple.shade700)
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
                                    isCorrectAnswer || isSelected
                                        ? Colors.white
                                        : Colors.deepPurple.shade700,
                              ),
                            ),
                          ),
                          if (isCorrectAnswer) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.deepPurple.shade600,
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
          ] else ...[
            // رسالة للاعبين الآخرين
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.orange.shade200, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
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
                      border: Border.all(color: Colors.orange.shade300),
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
          'السؤال ${_currentQuestionIndex + 1} من ${_questions.length}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurple,
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
      body: ListView(
        padding: const EdgeInsets.all(10),
        physics: const BouncingScrollPhysics(),
        children: [
          // Current player indicator
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade600,
                  Colors.deepPurple.shade800,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.3),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      _isCurrentPlayerTurn() ? 'دورك' : 'دور اللاعب',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: _isCurrentPlayerTurn() ? 24 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (!_isCurrentPlayerTurn()) ...[
                      const SizedBox(height: 4),
                      Text(
                        _getCurrentPlayerName(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Players scores
          Container(
            height: 100,
            margin: const EdgeInsets.only(bottom: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _currentRoom?.players.length ?? 0,
              itemBuilder: (context, index) {
                final player = _currentRoom!.players[index];
                final isCurrentPlayer = index == _currentPlayerIndex;

                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors:
                          isCurrentPlayer
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [
                                Colors.deepPurple.shade500,
                                Colors.purple.shade500,
                              ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isCurrentPlayer ? Colors.green : Colors.purple)
                            .withOpacity(0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Player avatar
                      Container(
                        width: 25,
                        height: 25,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          isCurrentPlayer ? Icons.star : Icons.person,
                          color:
                              isCurrentPlayer
                                  ? Colors.amber
                                  : Colors.grey.shade700,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Player name
                      Flexible(
                        child: Text(
                          player.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Player score
                      Text(
                        '${player.score}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'نقطة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Question Card
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: _buildQuestionCard(currentQuestion),
          ),

          // Submit button
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _selectedAnswerIndex != null &&
                          _isCurrentPlayerTurn() &&
                          !_isAnswering
                      ? _confirmAnswer
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _selectedAnswerIndex != null &&
                            _isCurrentPlayerTurn() &&
                            !_isAnswering
                        ? Colors.deepPurple
                        : Colors.grey.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation:
                    _selectedAnswerIndex != null &&
                            _isCurrentPlayerTurn() &&
                            !_isAnswering
                        ? 8
                        : 2,
                shadowColor: Colors.deepPurple.withOpacity(0.3),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _selectedAnswerIndex != null &&
                            _isCurrentPlayerTurn() &&
                            !_isAnswering
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isAnswering
                        ? 'جاري الإرسال...'
                        : _selectedAnswerIndex != null && _isCurrentPlayerTurn()
                        ? 'تأكيد الإجابة'
                        : _isCurrentPlayerTurn()
                        ? 'اختر إجابة أولاً'
                        : 'انتظار دورك',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // إضافة مساحة إضافية في النهاية
          const SizedBox(height: 20),
        ],
      ),
    );
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

  // التحقق من كون اللاعب الحالي هو المضيف
  bool _isCurrentPlayerHost() {
    if (_currentRoom == null) return false;
    return _currentRoom!.players.any(
      (player) => player.name == widget.playerName && player.isHost,
    );
  }

  // عرض الإجابة الصحيحة للجميع لمدة 3 ثوانٍ
  Future<void> _showCorrectAnswerToAll(int correctIndex) async {
    if (!mounted) return;

    setState(() {
      _showingCorrectAnswer = true;
      _correctAnswerIndex = correctIndex;
    });

    // عرض الإجابة الصحيحة لمدة 3 ثوانٍ
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _showingCorrectAnswer = false;
        _correctAnswerIndex = null;
      });
    }
  }

  void _navigateToResults() {
    // تشغيل موسيقى النتائج
    _audioService.playMusic('results_music.mp3');

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

  // تهيئة المؤثرات الصوتية
  Future<void> _initializeAudio() async {
    await _audioService.initialize();
    // إيقاف موسيقى القائمة الرئيسية عند بدء الأسئلة
    await _audioService.stopMusic();
  }

  // عرض التحدي للاعب
  void _showChallenge() async {
    if (!mounted) return;

    try {
      // تحميل التحدي من ملف JSON
      final String response = await rootBundle.loadString(
        'assets/data/challenges.json',
      );
      final List<dynamic> data = json.decode(response);
      final List<String> challenges = List<String>.from(data);

      final random = Random();
      final selectedChallenge = challenges[random.nextInt(challenges.length)];

      setState(() {
        _isChallengeActive = true;
        _currentChallenge = selectedChallenge;
      });

      // عرض حوار التحدي
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildChallengeDialog(),
      );
    } catch (e) {
      print('Error loading challenge: $e');
      // تحدي افتراضي في حالة الخطأ
      setState(() {
        _isChallengeActive = true;
        _currentChallenge = 'قم بالرقص لمدة 30 ثانية!';
      });

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildChallengeDialog(),
      );
    }
  }

  // بناء حوار التحدي
  Widget _buildChallengeDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Wrong answer notification
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.close_rounded, color: Colors.red, size: 50),
                  const SizedBox(height: 10),
                  Text(
                    'أوه لا، ${widget.playerName}!',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'إجابة خاطئة!',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Challenge container
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade300, Colors.orange.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.4),
                    spreadRadius: 3,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.white, size: 40),
                  const SizedBox(height: 15),
                  const Text(
                    'تحديك هو:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _currentChallenge,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Completion button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _completeChallenge();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'تم إنجاز التحدي!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Fun message
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.yellow.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.yellow.shade300, width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.orange, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لا تقلق! التحديات تجعل اللعبة أكثر متعة! 🎉',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // إكمال التحدي
  void _completeChallenge() async {
    try {
      print('✅ إكمال التحدي...');

      // إزالة حالة التحدي والانتقال للاعب التالي
      await _firebaseService.completeChallengeAndSwitchTurn(widget.roomCode);

      setState(() {
        _isChallengeActive = false;
        _currentChallenge = '';
      });

      // إشعار بإكمال التحدي
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'تم إكمال التحدي! انتظار اللاعب التالي...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
}
