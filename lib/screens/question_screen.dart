import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/player.dart';
import '../models/question.dart';
import '../services/audio_service.dart';
import '../widgets/question_card.dart';
import 'challenge_screen.dart';
import 'result_screen.dart';

class QuestionScreen extends StatefulWidget {
  final List<Player> players;
  final int? questionsCount;
  final List<String>? selectedCategories;
  final int? timerDuration; // المدة الزمنية لكل سؤال

  const QuestionScreen({
    super.key,
    required this.players,
    this.questionsCount,
    this.selectedCategories,
    this.timerDuration,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  final AudioService _audioService = AudioService();
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int _currentPlayerIndex = 0;
  int? _selectedAnswer;
  bool _isLoading = true;
  late final int _totalQuestions; // عدد الأسئلة لكل لعبة
  final Random _random = Random(); // لاختيار اللاعب التالي عشوائياً

  // نظام الدوران الجديد
  List<int> _availablePlayerIndices = []; // اللاعبين المتاحين في الجولة الحالية
  int? _lastPlayerIndex; // لتجنب تكرار نفس اللاعب مرتين متتاليتين

  // نظام المؤقت
  Timer? _questionTimer;
  int _remainingTime = 10; // 10 ثواني لكل سؤال
  bool _isTimerActive = false;

  // متغير للتحكم في دورة الحياة
  bool _isDisposed = false;

  // دالة آمنة لـ setState
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _totalQuestions =
        widget.questionsCount ?? 10; // استخدام العدد المُمرر أو 10 كافتراضي

    // تهيئة النظام الأولية
    _currentPlayerIndex = 0; // بدء باللاعب الأول
    _lastPlayerIndex = null; // لا يوجد لاعب سابق في البداية

    _initializeAudio();
    _loadQuestions();
    _initializeRound(); // تهيئة الجولة الأولى
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
    // إيقاف موسيقى القائمة الرئيسية عند بدء الأسئلة
    await _audioService.stopMusic();
  }

  Future<void> _loadQuestions() async {
    if (!mounted) return;

    try {
      final String response = await rootBundle.loadString(
        'assets/data/questions.json',
      );
      final List<dynamic> data = json.decode(response);
      List<Question> allQuestions =
          data.map((json) => Question.fromJson(json)).toList();

      // فلترة الأسئلة حسب الفئات المختارة
      if (widget.selectedCategories != null &&
          !widget.selectedCategories!.contains('جميع الفئات')) {
        allQuestions =
            allQuestions.where((question) {
              return widget.selectedCategories!.contains(question.category);
            }).toList();
      }

      // التأكد من وجود أسئلة كافية
      if (allQuestions.length < _totalQuestions) {
        // إذا لم توجد أسئلة كافية، استخدم كل الأسئلة المتاحة
        print('تحذير: عدد الأسئلة المتاحة أقل من المطلوب');
      }

      // اختيار أسئلة عشوائية
      final random = Random();
      allQuestions.shuffle(random);

      if (mounted) {
        _safeSetState(() {
          _questions = allQuestions.take(_totalQuestions).toList();
          _isLoading = false;
        });

        // بدء المؤقت بعد تحميل الأسئلة فقط إذا كان المؤقت مفعلاً
        if (mounted &&
            !_isDisposed &&
            widget.timerDuration != null &&
            widget.timerDuration! > 0) {
          _startQuestionTimer();
        }
      }
    } catch (e) {
      print('Error loading questions: $e');
      if (mounted) {
        _safeSetState(() {
          _isLoading = false;
        });
      }
    }
  }

  // بدء مؤقت السؤال
  void _startQuestionTimer() {
    if (!mounted || _isDisposed) return;

    _stopQuestionTimer(); // إيقاف أي مؤقت سابق

    // استخدام المدة المُمررة من الإعدادات أو 10 ثواني كافتراضي
    final duration = widget.timerDuration ?? 10;

    if (mounted && !_isDisposed) {
      _safeSetState(() {
        _remainingTime = duration;
        _isTimerActive = true;
      });
    }

    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isDisposed) {
        timer.cancel();
        return;
      }

      if (_remainingTime > 0) {
        _safeSetState(() {
          _remainingTime--;
        });
      } else {
        // انتهى الوقت - اعتبار الإجابة خاطئة
        timer.cancel(); // إيقاف المؤقت قبل استدعاء _handleTimeUp
        _handleTimeUp();
      }
    });
  }

  // إيقاف مؤقت السؤال
  void _stopQuestionTimer() {
    if (_questionTimer != null) {
      _questionTimer!.cancel();
      _questionTimer = null;
    }
    if (!_isDisposed && mounted) {
      _safeSetState(() {
        _isTimerActive = false;
      });
    }
  }

  // التعامل مع انتهاء الوقت
  void _handleTimeUp() {
    if (!mounted || _isDisposed) return;

    _stopQuestionTimer();

    // تشغيل صوت الإجابة الخاطئة
    _audioService.playWrongAnswer();

    // إظهار التحدي كما لو كانت إجابة خاطئة
    _showChallenge();
  }

  void _selectAnswer(int selectedIndex) {
    if (!mounted || _isDisposed) return;
    _safeSetState(() {
      _selectedAnswer = selectedIndex;
    });
  }

  void _submitAnswer() {
    if (_selectedAnswer == null || !mounted || _isDisposed) return;

    // إيقاف المؤقت عند الإجابة
    _stopQuestionTimer();

    final currentQuestion = _questions[_currentQuestionIndex];
    final currentPlayer = widget.players[_currentPlayerIndex];
    final isCorrect = currentQuestion.isCorrectAnswer(_selectedAnswer!);

    if (isCorrect) {
      // إجابة صحيحة - إضافة نقطة وتشغيل صوت النجاح
      _audioService.playCorrectAnswer();
      currentPlayer.addPoint();
      _showCorrectAnswer();
    } else {
      // إجابة خاطئة - تشغيل صوت الخطأ وإظهار التحدي
      _audioService.playWrongAnswer();
      _showChallenge();
    }
  }

  void _showCorrectAnswer() {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.green.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 30),
                SizedBox(width: 10),
                Text('إجابة صحيحة!', style: TextStyle(color: Colors.green)),
              ],
            ),
            content: Text(
              'أحسنت ${widget.players[_currentPlayerIndex].name}! لقد حصلت على نقطة.',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).pop();
                    _nextQuestion();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('التالي'),
              ),
            ],
          ),
    );
  }

  void _showChallenge() {
    if (!mounted || _isDisposed) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChallengeScreen(
              playerName: widget.players[_currentPlayerIndex].name,
              onChallengeCompleted: () {
                if (mounted && !_isDisposed) {
                  Navigator.pop(context);
                  _nextTurn(); // الانتقال للاعب التالي مع نفس السؤال عند الإجابة الخاطئة
                }
              },
            ),
      ),
    );
  }

  // تهيئة جولة جديدة
  void _initializeRound() {
    if (_isDisposed) return;

    _availablePlayerIndices = List.generate(
      widget.players.length,
      (index) => index,
    );

    // في السؤال الأول فقط، نختار اللاعب الأول مباشرة
    if (_currentQuestionIndex == 0) {
      _currentPlayerIndex = 0;
      _lastPlayerIndex = null;
      _availablePlayerIndices.remove(0); // إزالة اللاعب الأول من المتاحين
      print(
        'السؤال الأول - اللاعب: ${widget.players[_currentPlayerIndex].name}',
      );
    } else {
      // في باقي الأسئلة، اختيار عشوائي
      _selectRandomPlayer();
    }
  }

  // اختيار لاعب عشوائي من المتاحين
  void _selectRandomPlayer() {
    if (_isDisposed) return;

    if (_availablePlayerIndices.isEmpty) {
      // إذا انتهت الجولة، ابدأ جولة جديدة
      _initializeRound();
      return;
    }

    // إنشاء قائمة اللاعبين المتاحين (مع استبعاد اللاعب السابق إذا أمكن)
    List<int> eligiblePlayers = List.from(_availablePlayerIndices);

    // إذا كان هناك أكثر من لاعب متاح ولاعب سابق، استبعد اللاعب السابق
    if (eligiblePlayers.length > 1 && _lastPlayerIndex != null) {
      eligiblePlayers.remove(_lastPlayerIndex);
    }

    // إذا لم يعد هناك لاعبين مؤهلين، استخدم جميع اللاعبين المتاحين
    if (eligiblePlayers.isEmpty) {
      eligiblePlayers = List.from(_availablePlayerIndices);
    }

    // اختيار لاعب عشوائي من المؤهلين
    final randomIndex = _random.nextInt(eligiblePlayers.length);
    final selectedPlayer = eligiblePlayers[randomIndex];

    // تحديث اللاعب الحالي مباشرة بدون حفظ السابق هنا
    _currentPlayerIndex = selectedPlayer;

    // إزالة اللاعب المختار من قائمة المتاحين
    _availablePlayerIndices.remove(selectedPlayer);

    print('تم اختيار اللاعب: ${widget.players[_currentPlayerIndex].name}');
    print(
      'اللاعب السابق: ${_lastPlayerIndex != null ? widget.players[_lastPlayerIndex!].name : "لا يوجد"}',
    );
    print(
      'اللاعبين المتاحين: ${_availablePlayerIndices.map((i) => widget.players[i].name).toList()}',
    );
  }

  void _nextTurn() {
    if (!mounted || _isDisposed) return;

    _safeSetState(() {
      // حفظ اللاعب الحالي كلاعب سابق قبل الانتقال
      final previousPlayer = _currentPlayerIndex;
      _lastPlayerIndex = _currentPlayerIndex;

      print('=== إجابة خاطئة - الانتقال للاعب التالي ===');
      print('اللاعب الذي أجاب خطأ: ${widget.players[previousPlayer].name}');

      _selectedAnswer = null; // مسح الإجابة المختارة للاعب التالي
      _selectRandomPlayer(); // اختيار اللاعب التالي من النظام الجديد

      print('اللاعب الجديد: ${widget.players[_currentPlayerIndex].name}');
      print('==================================');
    });

    // بدء المؤقت للاعب الجديد مع نفس السؤال إذا كان المؤقت مفعلاً
    if (mounted &&
        !_isDisposed &&
        widget.timerDuration != null &&
        widget.timerDuration! > 0) {
      _startQuestionTimer();
    }
  }

  void _nextQuestion() {
    if (!mounted || _isDisposed) return;

    _safeSetState(() {
      // حفظ اللاعب الحالي كلاعب سابق قبل الانتقال للسؤال التالي
      final previousPlayer = _currentPlayerIndex;
      _lastPlayerIndex = _currentPlayerIndex;

      print('=== إجابة صحيحة - الانتقال للسؤال التالي ===');
      print('اللاعب الذي أجاب صحيح: ${widget.players[previousPlayer].name}');

      _selectedAnswer = null; // مسح الإجابة المختارة

      // الانتقال للسؤال التالي
      _currentQuestionIndex++;

      // إذا انتهت الأسئلة، اعرض النتائج
      if (_currentQuestionIndex >= _questions.length) {
        // تأجيل الانتقال للنتائج إلى ما بعد انتهاء setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isDisposed) {
            _showResults();
          }
        });
        return;
      }

      print('السؤال الجديد رقم: ${_currentQuestionIndex + 1}');

      // اختيار اللاعب التالي للسؤال الجديد
      _selectRandomPlayer();

      print(
        'اللاعب للسؤال الجديد: ${widget.players[_currentPlayerIndex].name}',
      );
      print('==========================================');
    });

    // بدء المؤقت للسؤال الجديد إذا كان المؤقت مفعلاً
    if (mounted &&
        !_isDisposed &&
        widget.timerDuration != null &&
        widget.timerDuration! > 0) {
      _startQuestionTimer();
    }
  }

  void _showResults() {
    if (!mounted || _isDisposed) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => ResultScreen(
              players: widget.players,
              questionsCount: widget.questionsCount,
              selectedCategories: widget.selectedCategories,
              timerDuration: widget.timerDuration,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('خطأ'), backgroundColor: Colors.red),
        body: const Center(
          child: Text(
            'لم يتم العثور على أسئلة',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    // فحص إضافي للتأكد من عدم تجاوز فهرس الأسئلة
    if (_currentQuestionIndex >= _questions.length) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.deepPurple),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final currentPlayer = widget.players[_currentPlayerIndex];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // إيقاف المؤقت أولاً
          _stopQuestionTimer();

          // ثم العودة
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
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
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _stopQuestionTimer();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
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
                  Text(
                    'دور ${currentPlayer.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                itemCount: widget.players.length,
                itemBuilder: (context, index) {
                  final player = widget.players[index];
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
                          color: (isCurrentPlayer
                                  ? Colors.green
                                  : Colors.purple)
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

            // Timer display
            if (_isTimerActive &&
                widget.timerDuration != null &&
                widget.timerDuration! > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _remainingTime / (widget.timerDuration ?? 10),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _remainingTime <= 3
                          ? Colors.red
                          : _remainingTime <= 5
                          ? Colors.orange
                          : Colors.green,
                    ),
                    minHeight: 12,
                  ),
                ),
              ),

            // Question Card
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: QuestionCard(
                question: currentQuestion,
                selectedAnswer: _selectedAnswer,
                onAnswerSelected: _selectAnswer,
              ),
            ),

            // Submit button
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedAnswer != null ? _submitAnswer : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _selectedAnswer != null
                          ? Colors.deepPurple
                          : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: _selectedAnswer != null ? 8 : 2,
                  shadowColor: Colors.deepPurple.withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedAnswer != null
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedAnswer != null
                          ? 'تأكيد الإجابة'
                          : 'اختر إجابة أولاً',
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
      ),
    );
  }

  @override
  void dispose() {
    // تعيين العلامة أولاً لمنع أي setState مستقبلي
    _isDisposed = true;

    // إيقاف المؤقت أولاً
    _stopQuestionTimer();

    // التأكد من إلغاء أي مؤقت قد يكون مازال يعمل
    _questionTimer?.cancel();
    _questionTimer = null;

    super.dispose();
  }
}
