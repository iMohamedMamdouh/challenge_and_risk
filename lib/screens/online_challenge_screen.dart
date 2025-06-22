import 'dart:math';

import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class OnlineChallengeScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final VoidCallback onChallengeComplete;

  const OnlineChallengeScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.onChallengeComplete,
  });

  @override
  State<OnlineChallengeScreen> createState() => _OnlineChallengeScreenState();
}

class _OnlineChallengeScreenState extends State<OnlineChallengeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final FirebaseService _firebaseService = FirebaseService();
  String _challenge = '';
  bool _isLoading = true;
  bool _isCompleting = false;

  final List<String> _challenges = [
    "ارقص لمدة 30 ثانية",
    "قلد صوت حيوان",
    "احك نكتة مضحكة",
    "اصنع وجه مضحك",
    "غن أغنية بدون موسيقى",
    "تحدث بلهجة مختلفة لدقيقة",
    "اعمل 10 تمارين ضغط",
    "احك قصة في دقيقة واحدة",
    "قلد شخصية مشهورة",
    "اذكر 5 أشياء تبدأ بحرف معين",
    "امشي كالروبوت",
    "قل الأبجدية بالعكس",
    "احك موقف محرج حدث معك",
    "اصنع قافية شعرية",
    "قلد صوت أحد الحضور",
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _loadChallenge();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadChallenge() async {
    // محاكاة تحميل التحدي
    await Future.delayed(const Duration(seconds: 1));

    final random = Random();
    final selectedChallenge = _challenges[random.nextInt(_challenges.length)];

    setState(() {
      _challenge = selectedChallenge;
      _isLoading = false;
    });

    _animationController.forward();
  }

  void _completeChallenge() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);

    try {
      print('🎯 بدء إكمال التحدي...');

      // إزالة حالة التحدي من Firebase
      final success = await _firebaseService.completeChallenge(widget.roomCode);

      if (success) {
        print('✅ تم إكمال التحدي بنجاح');

        // عرض رسالة نجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    'تم إكمال التحدي بنجاح!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // العودة لشاشة الأسئلة
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          widget.onChallengeComplete();
        }
      } else {
        throw Exception('فشل في إكمال التحدي');
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
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: Text(
          'تحدي ${widget.playerName}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body:
          _isLoading
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 20),
                    Text(
                      'جاري تحديد التحدي...',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Challenge icon
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              spreadRadius: 10,
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_gymnastics,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Player name
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.playerName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'عليك تنفيذ التحدي التالي:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Challenge text
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 3,
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.emoji_emotions,
                              size: 50,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              _challenge,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'نفذ التحدي أمام الجميع ثم اضغط "تم التنفيذ" للمتابعة',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Complete button
                    ElevatedButton(
                      onPressed: _isCompleting ? null : _completeChallenge,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isCompleting ? Colors.grey : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: _isCompleting ? 2 : 5,
                      ),
                      child:
                          _isCompleting
                              ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'جاري الإنهاء...',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                              : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 24),
                                  SizedBox(width: 10),
                                  Text(
                                    'تم التنفيذ!',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
    );
  }
}
