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

  const QuestionScreen({
    super.key,
    required this.players,
    this.questionsCount,
    this.selectedCategories,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int _currentPlayerIndex = 0;
  int? _selectedAnswer;
  bool _isLoading = true;
  final bool _showResult = false;
  late final int _totalQuestions; // عدد الأسئلة لكل لعبة
  final AudioService _audioService = AudioService();
  final Random _random = Random(); // لاختيار اللاعب التالي عشوائياً

  // نظام الدوران الجديد
  List<int> _availablePlayerIndices = []; // اللاعبين المتاحين في الجولة الحالية
  int _currentRound = 1; // رقم الجولة الحالية

  @override
  void initState() {
    super.initState();
    _totalQuestions =
        widget.questionsCount ?? 10; // استخدام العدد المُمرر أو 10 كافتراضي
    _loadQuestions();
    _initializeAudio();
    _initializeRound(); // تهيئة الجولة الأولى
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
  }

  Future<void> _loadQuestions() async {
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

      setState(() {
        _questions = allQuestions.take(_totalQuestions).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading questions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectAnswer(int selectedIndex) {
    setState(() {
      _selectedAnswer = selectedIndex;
    });
  }

  void _submitAnswer() {
    if (_selectedAnswer == null) return;

    final currentQuestion = _questions[_currentQuestionIndex];
    final currentPlayer = widget.players[_currentPlayerIndex];
    final isCorrect = currentQuestion.isCorrectAnswer(_selectedAnswer!);

    if (isCorrect) {
      // إجابة صحيحة - إضافة نقطة وتشغيل صوت النجاح
      currentPlayer.addPoint();
      _audioService.playCorrectAnswer();
      _showCorrectAnswer();
    } else {
      // إجابة خاطئة - تشغيل صوت الخطأ وإظهار التحدي
      _audioService.playWrongAnswer();
      _showChallenge();
    }
  }

  void _showCorrectAnswer() {
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
                  Navigator.of(context).pop();
                  _nextQuestion();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChallengeScreen(
              playerName: widget.players[_currentPlayerIndex].name,
              onChallengeCompleted: () {
                Navigator.pop(context);
                _nextTurn(); // الانتقال للاعب التالي مع نفس السؤال عند الإجابة الخاطئة
              },
            ),
      ),
    );
  }

  // تهيئة جولة جديدة
  void _initializeRound() {
    _availablePlayerIndices = List.generate(
      widget.players.length,
      (index) => index,
    );
    _selectRandomPlayer();
  }

  // اختيار لاعب عشوائي من المتاحين
  void _selectRandomPlayer() {
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

  void _nextTurn() {
    setState(() {
      _selectedAnswer = null; // مسح الإجابة المختارة للاعب التالي
      _selectRandomPlayer(); // اختيار اللاعب التالي من النظام الجديد
    });
  }

  void _nextQuestion() {
    setState(() {
      _selectedAnswer = null; // مسح الإجابة المختارة

      // الانتقال للسؤال التالي
      _currentQuestionIndex++;

      // إذا انتهت الأسئلة، اعرض النتائج
      if (_currentQuestionIndex >= _questions.length) {
        // تأجيل الانتقال للنتائج إلى ما بعد انتهاء setState
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showResults();
        });
        return;
      }

      // اختيار اللاعب التالي للسؤال الجديد
      _selectRandomPlayer();
    });
  }

  void _showResults() {
    // تشغيل موسيقى النتائج
    _audioService.playResultsMusic();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(players: widget.players),
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
    );
  }
}
