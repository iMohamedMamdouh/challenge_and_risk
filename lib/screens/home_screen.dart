import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/audio_service.dart';
import 'question_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<TextEditingController> _controllers = [];
  int _playerCount = 2;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final AudioService _audioService = AudioService();

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeAudio();
  }

  void _initializeControllers() {
    _controllers.clear();
    for (int i = 0; i < _playerCount; i++) {
      _controllers.add(TextEditingController());
    }
  }

  Future<void> _initializeAudio() async {
    await _audioService.initialize();
    if (mounted) {
      _audioService.playMainMenuMusic();
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updatePlayerCount(int count) {
    setState(() {
      _playerCount = count;
      _initializeControllers();
    });
  }

  void _startGame() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Create players from controllers
      final players =
          _controllers
              .map(
                (controller) => Player(
                  id:
                      DateTime.now().millisecondsSinceEpoch.toString() +
                      _controllers.indexOf(controller).toString(),
                  name: controller.text.trim(),
                ),
              )
              .toList();

      // Stop menu music before navigating
      _audioService.stopMusic();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuestionScreen(players: players),
        ),
      );
    }
  }

  void _toggleAudio() {
    setState(() {
      _audioService.toggleMusic();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text(
          'التحدي والمخاطرة',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
        actions: [
          // Audio control button
          Container(
            margin: const EdgeInsets.only(left: 8),
            child: IconButton(
              onPressed: _toggleAudio,
              icon: Icon(
                _audioService.isMusicEnabled
                    ? Icons.volume_up
                    : Icons.volume_off,
                color: Colors.white,
                size: 28,
              ),
              tooltip:
                  _audioService.isMusicEnabled ? 'إيقاف الصوت' : 'تشغيل الصوت',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Game title and description
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade100,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.quiz,
                        size: 50,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'مرحباً بكم في لعبة التحدي والمخاطرة!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'أجب على الأسئلة بشكل صحيح للحصول على النقاط، وإلا ستواجه تحدياً ممتعاً!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Player count selection
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
                      'عدد اللاعبين',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children:
                          [2, 3, 4, 5, 6].map((count) {
                            return GestureDetector(
                              onTap: () => _updatePlayerCount(count),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color:
                                      _playerCount == count
                                          ? Colors.deepPurple
                                          : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(25),
                                  border: Border.all(
                                    color: Colors.deepPurple,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color:
                                          _playerCount == count
                                              ? Colors.white
                                              : Colors.deepPurple,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Player names input
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
                      'أدخل أسماء اللاعبين',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(_playerCount, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: TextFormField(
                          controller: _controllers[index],
                          textAlign: TextAlign.right,
                          decoration: InputDecoration(
                            labelText: 'اللاعب ${index + 1}',
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
                              return 'يرجى إدخال اسم اللاعب';
                            }
                            return null;
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Start game button
              ElevatedButton(
                onPressed: _isLoading ? null : _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                ),
                child:
                    _isLoading
                        ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'جاري التحضير...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                        : const Text(
                          'ابدأ اللعبة',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
