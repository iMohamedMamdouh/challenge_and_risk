import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  // Audio players
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _soundPlayer = AudioPlayer();

  // Settings
  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  bool _isInitialized = false;

  // Music state tracking
  String? _currentlyPlayingMusic;
  bool _isMusicPlaying = false;

  // Getters
  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSoundEnabled => _isSoundEnabled;
  bool get isMusicPlaying => _isMusicPlaying;
  String? get currentlyPlayingMusic => _currentlyPlayingMusic;

  // Initialize audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadSettings();

    // Set music player to loop
    _musicPlayer.setReleaseMode(ReleaseMode.loop);

    // Listen to player state changes
    _musicPlayer.onPlayerStateChanged.listen((PlayerState state) {
      bool wasPlaying = _isMusicPlaying;
      _isMusicPlaying = state == PlayerState.playing;

      // إشعار الواجهة عند تغيير الحالة
      if (wasPlaying != _isMusicPlaying) {
        notifyListeners();
      }
    });

    _isInitialized = true;

    // تشغيل الموسيقى فقط إذا كانت مُفعلة في الإعدادات المحفوظة
    if (_isMusicEnabled) {
      await playMainMenuMusic();
    }

    // إشعار الواجهة بالحالة الأولية
    notifyListeners();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMusicEnabled = prefs.getBool('music_enabled') ?? true;
      _isSoundEnabled = prefs.getBool('sound_enabled') ?? true;
    } catch (e) {
      print('Error loading audio settings: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('music_enabled', _isMusicEnabled);
      await prefs.setBool('sound_enabled', _isSoundEnabled);
    } catch (e) {
      print('Error saving audio settings: $e');
    }
  }

  // Toggle music on/off
  Future<void> toggleMusic() async {
    try {
      _isMusicEnabled = !_isMusicEnabled;

      if (!_isMusicEnabled) {
        await stopMusic();
      } else {
        // عند تشغيل الموسيقى مرة أخرى، إعادة تشغيل موسيقى القائمة الرئيسية
        await playMainMenuMusic();
      }

      await _saveSettings();
      notifyListeners();
    } catch (e) {
      print('Error toggling music: $e');
      // في حالة الخطأ، استرجاع الحالة السابقة
      _isMusicEnabled = !_isMusicEnabled;
      notifyListeners();
    }
  }

  // Toggle sound effects on/off
  Future<void> toggleSound() async {
    _isSoundEnabled = !_isSoundEnabled;
    await _saveSettings();
  }

  // Play background music
  Future<void> playMusic(String musicFile) async {
    if (!_isMusicEnabled) return;

    try {
      // إذا كانت نفس الموسيقى تعمل بالفعل والتشغيل لا يزال نشطاً، لا تعيد تشغيلها
      if (_currentlyPlayingMusic == musicFile && _isMusicPlaying) {
        print('الموسيقى $musicFile تعمل بالفعل - تخطي إعادة التشغيل');
        return;
      }

      print('بدء تشغيل الموسيقى: $musicFile');

      // إيقاف أي موسيقى تعمل حالياً
      await _musicPlayer.stop();

      await _musicPlayer.setVolume(0.50);

      // تشغيل الموسيقى الجديدة مباشرة
      await _musicPlayer.play(AssetSource('audio/music/$musicFile'));
      _currentlyPlayingMusic = musicFile;
      _isMusicPlaying = true;
      notifyListeners();

      print('تم تشغيل الموسيقى بنجاح: $musicFile');
    } catch (e) {
      print('Error playing music: $e');
      _currentlyPlayingMusic = null;
      _isMusicPlaying = false;
      notifyListeners();
    }
  }

  // Stop background music
  Future<void> stopMusic() async {
    try {
      print('إيقاف الموسيقى...');
      await _musicPlayer.stop();
      _currentlyPlayingMusic = null;
      _isMusicPlaying = false;
      notifyListeners();
      print('تم إيقاف الموسيقى بنجاح');
    } catch (e) {
      print('Error stopping music: $e');
      // حتى في حالة الخطأ، نظف الحالة
      _currentlyPlayingMusic = null;
      _isMusicPlaying = false;
      notifyListeners();
    }
  }

  // Pause background music
  Future<void> pauseMusic() async {
    try {
      await _musicPlayer.pause();
      _isMusicPlaying = false;
      notifyListeners();
      print('تم إيقاف الموسيقى مؤقتاً');
    } catch (e) {
      print('Error pausing music: $e');
    }
  }

  // Resume background music
  Future<void> resumeMusic() async {
    if (!_isMusicEnabled) return;

    try {
      await _musicPlayer.resume();
      _isMusicPlaying = true;
      notifyListeners();
      print('تم استئناف الموسيقى');
    } catch (e) {
      print('Error resuming music: $e');
    }
  }

  // Check if specific music is currently playing
  bool isPlayingMusic(String musicFile) {
    return _currentlyPlayingMusic == musicFile && _isMusicPlaying;
  }

  // Play sound effect
  Future<void> playSound(String soundFile, {double volume = 1.0}) async {
    if (!_isSoundEnabled) return;

    try {
      await _soundPlayer.stop();
      // تعيين مستوى الصوت المطلوب
      await _soundPlayer.setVolume(volume);
      await _soundPlayer.play(AssetSource('audio/sounds/$soundFile'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Specific sound methods
  Future<void> playCorrectAnswer() async {
    // مستوى صوت طبيعي للإجابة الصحيحة
    await playSound('correct_answer.mp3', volume: 0.8);
  }

  Future<void> playWrongAnswer() async {
    // مستوى صوت عالي جداً للإجابة الخاطئة لجذب الانتباه
    await playSound('wrong_answer.mp3', volume: 1.0);
  }

  Future<void> playMainMenuMusic() async {
    await playMusic('main_menu_music.mp3');
  }

  Future<void> playResultsMusic() async {
    await playMusic('results_music.mp3');
  }

  // تأكد من استمرار تشغيل موسيقى القائمة الرئيسية
  Future<void> ensureMainMenuMusicPlaying() async {
    // تشغيل الموسيقى فقط إذا كانت مُفعلة وليست تعمل بالفعل
    if (_isMusicEnabled && !isPlayingMusic('main_menu_music.mp3')) {
      await playMainMenuMusic();
    }
  }

  // إعادة تشغيل موسيقى القائمة الرئيسية بالقوة
  Future<void> forceRestartMainMenuMusic() async {
    if (_isMusicEnabled) {
      await stopMusic();
      await playMainMenuMusic();
    }
  }

  // إيقاف كامل للصوت عند الخروج من التطبيق
  Future<void> stopAllAudio() async {
    try {
      await _musicPlayer.stop();
      await _soundPlayer.stop();
      _isMusicPlaying = false;
      _currentlyPlayingMusic = null;
      notifyListeners();
      print('تم إيقاف جميع الأصوات');
    } catch (e) {
      print('Error stopping all audio: $e');
    }
  }

  // Dispose resources
  @override
  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _soundPlayer.dispose();
    super.dispose();
  }
}
