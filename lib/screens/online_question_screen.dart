import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_room.dart';
import '../models/question.dart';
import '../services/firebase_service.dart';
import 'online_challenge_screen.dart';
import 'online_result_screen.dart';

class OnlineQuestionScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const OnlineQuestionScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
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

  // نظام الدوران الجديد
  List<int> _availablePlayerIndices = []; // اللاعبين المتاحين في الجولة الحالية
  int _currentRound = 1; // رقم الجولة الحالية

  @override
  void initState() {
    super.initState();
    _listenToGameUpdates();
  }

  void _listenToGameUpdates() {
    _firebaseService
        .listenToRoom(widget.roomCode)
        .listen((room) {
          if (room != null && mounted) {
            setState(() {
              _currentRoom = room;
              if (_questions.isEmpty) {
                _questions = room.questions;
              }
              _currentQuestionIndex = room.currentQuestionIndex;
              _currentPlayerIndex = room.currentPlayerIndex;
            });

            // إذا لم يتم تهيئة النظام العشوائي بعد، قم بتهيئته
            if (_availablePlayerIndices.isEmpty && room.players.isNotEmpty) {
              _initializeRound();
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

  // تهيئة جولة جديدة
  void _initializeRound() {
    if (_currentRoom != null && _currentRoom!.players.isNotEmpty) {
      _availablePlayerIndices = List.generate(
        _currentRoom!.players.length,
        (index) => index,
      );
      _selectRandomPlayer();
    }
  }

  // اختيار لاعب عشوائي من المتاحين
  void _selectRandomPlayer() {
    if (_currentRoom == null || _currentRoom!.players.isEmpty) return;

    if (_availablePlayerIndices.isEmpty) {
      // إذا انتهت الجولة، ابدأ جولة جديدة
      _currentRound++;
      _initializeRound();
      return;
    }

    // اختيار لاعب عشوائي من المتاحين
    final randomIndex = _random.nextInt(_availablePlayerIndices.length);
    _currentPlayerIndex = _availablePlayerIndices[randomIndex];

    // إزالة اللاعب من قائمة المتاحين
    _availablePlayerIndices.removeAt(randomIndex);
  }

  void _answerQuestion(int selectedAnswer) async {
    if (_isAnswering) return;

    setState(() => _isAnswering = true);

    try {
      // TODO: إرسال الإجابة إلى Firebase
      // await FirebaseService().submitAnswer(
      //   widget.roomCode,
      //   _currentQuestionIndex,
      //   selectedAnswer,
      // );

      // محاكاة معالجة الإجابة
      await Future.delayed(const Duration(seconds: 1));

      final currentQuestion = _questions[_currentQuestionIndex];
      final isCorrect = selectedAnswer == currentQuestion.correctAnswerIndex;
      final currentPlayer = _currentRoom!.players[_currentPlayerIndex];

      if (isCorrect) {
        // إجابة صحيحة - إضافة نقطة
        setState(() {
          // Update the player's score using copyWith
          final updatedPlayers =
              _currentRoom!.players.map((player) {
                if (player.id == currentPlayer.id) {
                  return player.copyWith(score: player.score + 1);
                }
                return player;
              }).toList();

          _currentRoom = _currentRoom!.copyWith(players: updatedPlayers);
        });

        _showResultDialog(true, () {
          _nextTurn();
        });
      } else {
        // إجابة خاطئة - انتقال لشاشة التحدي
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => OnlineChallengeScreen(
                    roomCode: widget.roomCode,
                    playerName: currentPlayer.name,
                    onChallengeComplete: () {
                      Navigator.pop(context);
                      _nextTurn();
                    },
                  ),
            ),
          );
        }
      }
    } catch (e) {
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
                ),
                child: const Text('متابعة'),
              ),
            ],
          ),
    );
  }

  void _nextTurn() {
    setState(() {
      // مسح الإجابة المختارة للاعب التالي
      _selectedAnswerIndex = null;

      // اختيار اللاعب التالي من النظام الجديد
      _selectRandomPlayer();

      // التحقق من انتهاء الأسئلة
      if (_currentQuestionIndex >= _questions.length - 1) {
        _isGameFinished = true;
        _navigateToResults();
        return;
      }

      // الانتقال للسؤال التالي بعد كل 3 أدوار
      if (_random.nextBool()) {
        _currentQuestionIndex++;
        if (_currentQuestionIndex >= _questions.length) {
          _isGameFinished = true;
          _navigateToResults();
          return;
        }
      }
    });
  }

  void _navigateToResults() {
    // ترتيب اللاعبين حسب النقاط
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

  String _getCurrentPlayerName() {
    if (_currentRoom != null &&
        _currentPlayerIndex < _currentRoom!.players.length) {
      return _currentRoom!.players[_currentPlayerIndex].name;
    }
    return '';
  }

  bool _isCurrentPlayerTurn() {
    return _getCurrentPlayerName() == widget.playerName;
  }

  Widget _buildPlayerCard(OnlinePlayer player, bool isCurrentPlayer) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isCurrentPlayer
                  ? [Colors.green.shade400, Colors.green.shade600]
                  : [Colors.deepPurple.shade300, Colors.deepPurple.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isCurrentPlayer
                  ? Colors.green.shade300
                  : Colors.deepPurple.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isCurrentPlayer ? Colors.green : Colors.deepPurple)
                .withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isCurrentPlayer ? Icons.play_arrow : Icons.person,
              color:
                  isCurrentPlayer
                      ? Colors.green.shade700
                      : Colors.deepPurple.shade700,
              size: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            player.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${player.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'نقطة',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 9),
          ),
        ],
      ),
    );
  }

  void _selectAnswer(int index) {
    if (!_isAnswering && _isCurrentPlayerTurn()) {
      setState(() {
        _selectedAnswerIndex = index;
      });
      _answerQuestion(index);
    }
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // شريط التقدم
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
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
                            _isCurrentPlayerTurn() ? 'دورك' : 'انتظار',
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
                  value: (_currentQuestionIndex + 1) / _questions.length,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.deepPurple,
                  ),
                  minHeight: 6,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // قائمة اللاعبين الأفقية
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _currentRoom!.players.length,
              itemBuilder: (context, index) {
                final player = _currentRoom!.players[index];
                final isCurrentPlayer = index == _currentPlayerIndex;
                return _buildPlayerCard(player, isCurrentPlayer);
              },
            ),
          ),

          const SizedBox(height: 16),

          // تنبيه الدور (إذا لم يكن دور اللاعب الحالي)
          if (!_isCurrentPlayerTurn()) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade100, Colors.orange.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.hourglass_empty,
                      color: Colors.orange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'انتظار دور اللاعب',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _getCurrentPlayerName(),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // السؤال فوق المربع الأبيض
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

          // خيارات الإجابة في مربع أبيض
          Container(
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
                // خيارات الإجابة
                ...currentQuestion.options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final isSelected = _selectedAnswerIndex == index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      elevation: isSelected ? 6 : 2,
                      borderRadius: BorderRadius.circular(12),
                      shadowColor:
                          isSelected
                              ? Colors.deepPurple.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.2),
                      child: InkWell(
                        onTap:
                            !_isAnswering && _isCurrentPlayerTurn()
                                ? () => _selectAnswer(index)
                                : null,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getButtonColor(index),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getBorderColor(index),
                              width: 2,
                            ),
                            gradient:
                                isSelected
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
                                      isSelected
                                          ? Colors.white
                                          : Colors.deepPurple.shade600,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isSelected
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
                                    String.fromCharCode(
                                      65 + index,
                                    ), // A, B, C, D
                                    style: TextStyle(
                                      color:
                                          isSelected
                                              ? Colors.deepPurple.shade700
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
                                    color: _getTextColor(index),
                                  ),
                                ),
                              ),
                              if (isSelected && !_isAnswering) ...[
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
                              if (_isAnswering && isSelected) ...[
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.deepPurple.shade600,
                                      ),
                                    ),
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

                // مؤشر التحميل
                if (_isAnswering) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.deepPurple.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.deepPurple.shade600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'جاري معالجة الإجابة...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.deepPurple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
