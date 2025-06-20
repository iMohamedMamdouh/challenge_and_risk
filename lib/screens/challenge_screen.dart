import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChallengeScreen extends StatefulWidget {
  final String playerName;
  final String correctAnswer;
  final VoidCallback onChallengeCompleted;

  const ChallengeScreen({
    super.key,
    required this.playerName,
    required this.correctAnswer,
    required this.onChallengeCompleted,
  });

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen>
    with TickerProviderStateMixin {
  String _challenge = '';
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadChallenge();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  Future<void> _loadChallenge() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/challenges.json',
      );
      final List<dynamic> data = json.decode(response);
      final List<String> challenges = List<String>.from(data);

      final random = Random();
      final selectedChallenge = challenges[random.nextInt(challenges.length)];

      setState(() {
        _challenge = selectedChallenge;
        _isLoading = false;
      });

      // Start animations
      _animationController.forward();
    } catch (e) {
      print('Error loading challenges: $e');
      setState(() {
        _challenge = 'قم بالرقص لمدة 30 ثانية!'; // تحدي افتراضي
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text(
          'تحدي!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: Colors.red),
              )
              : AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          const SizedBox(height: 20),

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
                                const Icon(
                                  Icons.close_rounded,
                                  color: Colors.red,
                                  size: 50,
                                ),
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
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.red,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'الإجابة الصحيحة: ${widget.correctAnswer}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Challenge container
                          Container(
                            padding: const EdgeInsets.all(25),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade300,
                                  Colors.orange.shade500,
                                ],
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
                                const Icon(
                                  Icons.emoji_events,
                                  color: Colors.white,
                                  size: 40,
                                ),
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
                                    _challenge,
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

                          const SizedBox(height: 40),

                          // Completion button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: widget.onChallengeCompleted,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
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

                          const SizedBox(height: 20),

                          // Fun message
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.yellow.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.yellow.shade300,
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.lightbulb,
                                  color: Colors.orange,
                                  size: 24,
                                ),
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

                          // إضافة مساحة إضافية في النهاية
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
