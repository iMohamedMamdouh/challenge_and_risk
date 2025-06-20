import 'package:flutter/material.dart';

import 'game_mode_screen.dart';

class OnlineResultScreen extends StatefulWidget {
  final String roomCode;
  final List<Map<String, dynamic>> players;
  final int totalQuestions;

  const OnlineResultScreen({
    super.key,
    required this.roomCode,
    required this.players,
    required this.totalQuestions,
  });

  @override
  State<OnlineResultScreen> createState() => _OnlineResultScreenState();
}

class _OnlineResultScreenState extends State<OnlineResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _confettiController.repeat();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _playAgain() {
    // TODO: إضافة وظيفة اللعب مرة أخرى
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('اللعب مرة أخرى'),
            content: const Text('هذه الميزة ستكون متاحة قريباً مع Firebase'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('موافق'),
              ),
            ],
          ),
    );
  }

  void _exitToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const GameModeScreen()),
      (route) => false,
    );
  }

  List<Color> _getPodiumColors() {
    return [
      Colors.amber, // الأول - ذهبي
      Colors.grey, // الثاني - فضي
      Colors.orange, // الثالث - برونزي
    ];
  }

  List<IconData> _getPodiumIcons() {
    return [
      Icons.emoji_events, // كأس
      Icons.military_tech, // ميدالية
      Icons.workspace_premium, // شارة
    ];
  }

  @override
  Widget build(BuildContext context) {
    final winner = widget.players.isNotEmpty ? widget.players.first : null;

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text(
          'نتائج اللعبة',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Winner announcement
              if (winner != null) ...[
                const SizedBox(height: 20),
                RotationTransition(
                  turns: _confettiController,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.amber.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          spreadRadius: 5,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.emoji_events,
                          size: 60,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '🎉 الفائز 🎉',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          winner['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${winner['score']} نقطة من ${widget.totalQuestions}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // Results table
              Expanded(
                child: Container(
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
                      const Row(
                        children: [
                          Icon(
                            Icons.leaderboard,
                            color: Colors.deepPurple,
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'ترتيب اللاعبين',
                            style: TextStyle(
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
                          itemCount: widget.players.length,
                          itemBuilder: (context, index) {
                            final player = widget.players[index];
                            final position = index + 1;
                            final colors = _getPodiumColors();
                            final icons = _getPodiumIcons();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color:
                                    position <= 3
                                        ? colors[position - 1].withOpacity(0.1)
                                        : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      position <= 3
                                          ? colors[position - 1]
                                          : Colors.grey.shade300,
                                  width: position == 1 ? 3 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Position
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          position <= 3
                                              ? colors[position - 1]
                                              : Colors.grey,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Center(
                                      child:
                                          position <= 3
                                              ? Icon(
                                                icons[position - 1],
                                                color: Colors.white,
                                                size: 20,
                                              )
                                              : Text(
                                                '$position',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),

                                  // Player name
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          player['name'] ?? '',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight:
                                                position == 1
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                        if (position == 1) ...[
                                          const Text(
                                            '🏆 البطل',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Score
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          position <= 3
                                              ? colors[position - 1]
                                              : Colors.grey,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Text(
                                      '${player['score']}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Game statistics
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.quiz, color: Colors.blue, size: 24),
                        const SizedBox(height: 5),
                        Text(
                          '${widget.totalQuestions}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Text(
                          'سؤال',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.people, color: Colors.blue, size: 24),
                        const SizedBox(height: 5),
                        Text(
                          '${widget.players.length}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Text(
                          'لاعب',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(Icons.vpn_key, color: Colors.blue, size: 24),
                        const SizedBox(height: 5),
                        Text(
                          widget.roomCode,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const Text(
                          'الغرفة',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _playAgain,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text(
                            'لعب مرة أخرى',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _exitToHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home),
                          SizedBox(width: 8),
                          Text(
                            'الرئيسية',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
