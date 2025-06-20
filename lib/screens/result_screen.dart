import 'package:flutter/material.dart';

import '../models/player.dart';
import '../widgets/player_score_tile.dart';
import 'game_mode_screen.dart';

class ResultScreen extends StatefulWidget {
  final List<Player> players;

  const ResultScreen({super.key, required this.players});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  List<Player> _sortedPlayers = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _sortPlayers();
    _animationController.forward();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );
  }

  void _sortPlayers() {
    _sortedPlayers = List.from(widget.players);
    _sortedPlayers.sort((a, b) => b.score.compareTo(a.score));
  }

  // دالة للحصول على الفائزين (في حالة التعادل)
  List<Player> _getWinners() {
    if (_sortedPlayers.isEmpty) return [];

    final highestScore = _sortedPlayers[0].score;
    return _sortedPlayers
        .where((player) => player.score == highestScore)
        .toList();
  }

  // فحص ما إذا كان هناك تعادل
  bool _hasTie() {
    final winners = _getWinners();
    return winners.length > 1;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _playAgain() {
    // إعادة تعيين نقاط اللاعبين
    for (var player in widget.players) {
      player.resetScore();
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const GameModeScreen()),
      (route) => false,
    );
  }

  Widget _buildWinnerPodium() {
    if (_sortedPlayers.isEmpty) return const SizedBox.shrink();

    final winners = _getWinners();
    final hasTie = _hasTie();

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              hasTie
                  ? [Colors.purple.shade300, Colors.purple.shade600]
                  : [Colors.amber.shade300, Colors.amber.shade600],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (hasTie ? Colors.purple : Colors.amber).withOpacity(0.4),
            spreadRadius: 3,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            hasTie ? Icons.people : Icons.emoji_events,
            color: Colors.white,
            size: 50,
          ),
          const SizedBox(height: 10),
          Text(
            hasTie ? '🤝 تعادل! 🤝' : '🎉 الفائز 🎉',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                if (hasTie) ...[
                  const Text(
                    'الفائزون:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...winners.map(
                    (winner) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        winner.name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${winners[0].score} نقطة لكل منهم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade600,
                    ),
                  ),
                ] else ...[
                  Text(
                    _sortedPlayers[0].name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_sortedPlayers[0].score} نقطة',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRankings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Text(
              'الترتيب النهائي:',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
          ...List.generate(_sortedPlayers.length, (index) {
            return AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                final delay = index * 0.1;
                final animationValue = Curves.easeOut.transform(
                  (_animationController.value - delay).clamp(0.0, 1.0),
                );

                return Transform.translate(
                  offset: Offset(0, 50 * (1 - animationValue)),
                  child: Opacity(
                    opacity: animationValue,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: PlayerScoreTile(
                        playerName: _sortedPlayers[index].name,
                        score: _sortedPlayers[index].score,
                        isActive: index == 0, // Winner is active
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGameStats() {
    final totalQuestions = 10; // عدد الأسئلة الإجمالي
    final totalPoints = _sortedPlayers.fold(
      0,
      (sum, player) => sum + player.score,
    );
    final averageScore = totalPoints / _sortedPlayers.length;
    final winners = _getWinners();
    final hasTie = _hasTie();

    return Container(
      margin: const EdgeInsets.all(20),
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
            'إحصائيات اللعبة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('إجمالي الأسئلة', '$totalQuestions', Icons.quiz),
              _buildStatItem('إجمالي النقاط', '$totalPoints', Icons.star),
              _buildStatItem(
                'المتوسط',
                averageScore.toStringAsFixed(1),
                Icons.trending_up,
              ),
            ],
          ),
          if (hasTie) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, color: Colors.purple.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'تعادل بين ${winners.length} لاعبين',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade600,
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 30),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50,
      appBar: AppBar(
        title: const Text(
          'النتائج النهائية',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Winner podium
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildWinnerPodium(),
                  ),

                  // Game stats
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildGameStats(),
                  ),

                  // Player rankings
                  _buildPlayerRankings(),

                  const SizedBox(height: 30),

                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _playAgain,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 5,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'لعب مرة أخرى',
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
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GameModeScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: const BorderSide(
                                color: Colors.deepPurple,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.home, size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'العودة للرئيسية',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

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
