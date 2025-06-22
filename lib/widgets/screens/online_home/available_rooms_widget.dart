import 'package:flutter/material.dart';

import '../../../models/game_room.dart';

class AvailableRoomsWidget extends StatelessWidget {
  final List<GameRoom> availableRooms;
  final bool isLoading;
  final Function(String roomCode) onJoinRoom;
  final VoidCallback onRefresh;

  const AvailableRoomsWidget({
    super.key,
    required this.availableRooms,
    required this.isLoading,
    required this.onJoinRoom,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            spreadRadius: 3,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس القسم
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.public,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الغرف المتاحة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      'انضم لإحدى الغرف الموجودة',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // زر التحديث
              IconButton(
                onPressed: isLoading ? null : onRefresh,
                icon:
                    isLoading
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.blue.shade600,
                            ),
                          ),
                        )
                        : Icon(Icons.refresh, color: Colors.blue.shade600),
                tooltip: 'تحديث القائمة',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // قائمة الغرف أو رسالة فارغة
          if (isLoading)
            _buildLoadingIndicator()
          else if (availableRooms.isEmpty)
            _buildEmptyState()
          else
            _buildRoomsList(),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'جاري البحث عن الغرف...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 100,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'لا توجد غرف متاحة حالياً',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'قم بإنشاء غرفة جديدة أو حاول لاحقاً',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomsList() {
    return Column(
      children: availableRooms.map((room) => _buildRoomCard(room)).toList(),
    );
  }

  Widget _buildRoomCard(GameRoom room) {
    final playersCount = room.players.length;
    final maxPlayers = room.maxPlayers;
    final isNearlyFull = playersCount >= maxPlayers - 1;

    // debugging: طباعة تفاصيل الغرفة عند بناء البطاقة
    print('🎯 بناء بطاقة الغرفة ${room.id}:');
    print('   👥 عدد اللاعبين: $playersCount');
    print('   🎯 الحد الأقصى: $maxPlayers');
    print('   ❓ عدد الأسئلة: ${room.questions.length}');
    print('   ⏱️ مدة السؤال: ${room.timerDuration}');
    print('   📝 اللاعبين: ${room.players.map((p) => p.name).toList()}');
    print(
      '   📚 الأسئلة: ${room.questions.isNotEmpty ? room.questions.first.questionText : 'لا أسئلة'}',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNearlyFull ? Colors.orange.shade300 : Colors.blue.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // معلومات الغرفة
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // كود الغرفة ومؤشر الحالة
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade600,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        room.id,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isNearlyFull)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'تقريباً ممتلئة',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // عدد اللاعبين
                Row(
                  children: [
                    Icon(Icons.people, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '$playersCount/$maxPlayers لاعبين',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // عدد الأسئلة
                Row(
                  children: [
                    Icon(Icons.quiz, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${room.questions.length} أسئلة',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (room.timerDuration != null) ...[
                      Icon(Icons.timer, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        '${room.timerDuration}ث',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // زر الانضمام
          ElevatedButton.icon(
            onPressed: () => onJoinRoom(room.id),
            icon: const Icon(Icons.login, size: 16),
            label: const Text(
              'انضمام',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isNearlyFull ? Colors.orange.shade600 : Colors.green.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
}
