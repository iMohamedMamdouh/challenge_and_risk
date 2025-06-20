// import 'package:flutter/material.dart';

// import '../services/audio_service.dart';
// import 'local_settings_screen.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   final AudioService _audioService = AudioService();

//   @override
//   void initState() {
//     super.initState();
//     _initializeAudio();
//   }

//   Future<void> _initializeAudio() async {
//     await _audioService.initialize();
//     if (mounted) {
//       _audioService.playMainMenuMusic();
//     }
//   }

//   void _goToSettings() {
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (context) => const LocalSettingsScreen()),
//     );
//   }

//   void _toggleAudio() {
//     setState(() {
//       _audioService.toggleMusic();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.deepPurple.shade50,
//       appBar: AppBar(
//         title: const Text(
//           'التحدي والمخاطرة',
//           style: TextStyle(
//             fontSize: 24,
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: Colors.deepPurple,
//         centerTitle: true,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         actions: [
//           // Audio control button
//           Container(
//             margin: const EdgeInsets.only(left: 8),
//             child: IconButton(
//               onPressed: _toggleAudio,
//               icon: Icon(
//                 _audioService.isMusicEnabled
//                     ? Icons.volume_up
//                     : Icons.volume_off,
//                 color: Colors.white,
//                 size: 28,
//               ),
//               tooltip:
//                   _audioService.isMusicEnabled ? 'إيقاف الصوت' : 'تشغيل الصوت',
//             ),
//           ),
//         ],
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             const SizedBox(height: 20),

//             // Game title and description
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(15),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.3),
//                     spreadRadius: 2,
//                     blurRadius: 5,
//                     offset: const Offset(0, 3),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: Colors.deepPurple.shade100,
//                       borderRadius: BorderRadius.circular(50),
//                     ),
//                     child: const Icon(
//                       Icons.quiz,
//                       size: 50,
//                       color: Colors.deepPurple,
//                     ),
//                   ),
//                   const SizedBox(height: 15),
//                   const Text(
//                     'مرحباً بكم في لعبة التحدي والمخاطرة!',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.deepPurple,
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   const Text(
//                     'أجب على الأسئلة بشكل صحيح للحصول على النقاط، وإلا ستواجه تحدياً ممتعاً!',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(fontSize: 16, color: Colors.grey),
//                   ),
//                   const SizedBox(height: 15),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 30),

//             // Game features
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(15),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.3),
//                     spreadRadius: 2,
//                     blurRadius: 5,
//                     offset: const Offset(0, 3),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 children: [
//                   const Text(
//                     'مميزات اللعبة المحلية',
//                     style: TextStyle(
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.deepPurple,
//                     ),
//                   ),
//                   const SizedBox(height: 15),
//                   _buildFeatureRow(
//                     Icons.category,
//                     'اختيار فئات الأسئلة',
//                     'اختر من 9 فئات متنوعة',
//                   ),
//                   _buildFeatureRow(
//                     Icons.quiz,
//                     'تحديد عدد الأسئلة',
//                     'من 5 إلى 20 سؤال',
//                   ),
//                   _buildFeatureRow(
//                     Icons.group,
//                     'تعدد اللاعبين',
//                     'من 2 إلى 8 لاعبين',
//                   ),
//                   _buildFeatureRow(
//                     Icons.emoji_events,
//                     'تحديات ممتعة',
//                     'عند الإجابة الخاطئة',
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 30),

//             // Start button
//             Container(
//               height: 60,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     Colors.deepPurple.shade400,
//                     Colors.deepPurple.shade600,
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(15),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.deepPurple.withOpacity(0.3),
//                     spreadRadius: 2,
//                     blurRadius: 8,
//                     offset: const Offset(0, 4),
//                   ),
//                 ],
//               ),
//               child: Material(
//                 color: Colors.transparent,
//                 child: InkWell(
//                   onTap: _goToSettings,
//                   borderRadius: BorderRadius.circular(15),
//                   child: const Center(
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.settings, color: Colors.white, size: 28),
//                         SizedBox(width: 10),
//                         Text(
//                           'إعداد اللعبة والبدء',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 20),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildFeatureRow(IconData icon, String title, String description) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Row(
//         children: [
//           Container(
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: Colors.deepPurple.shade100,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(icon, color: Colors.deepPurple, size: 24),
//           ),
//           const SizedBox(width: 15),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.deepPurple,
//                   ),
//                 ),
//                 Text(
//                   description,
//                   style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
