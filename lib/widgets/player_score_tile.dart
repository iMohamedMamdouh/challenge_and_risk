import 'package:flutter/material.dart';

class PlayerScoreTile extends StatelessWidget {
  final String playerName;
  final int score;
  final bool isActive;

  const PlayerScoreTile({
    super.key,
    required this.playerName,
    required this.score,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? Colors.deepPurple.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? Colors.deepPurple : Colors.grey.shade300,
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Player avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? Colors.deepPurple : Colors.grey.shade400,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isActive ? Icons.star : Icons.person,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),

          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.deepPurple : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'النقاط: $score',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isActive
                            ? Colors.deepPurple.shade700
                            : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Score badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isActive ? Colors.deepPurple : Colors.grey.shade500,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
