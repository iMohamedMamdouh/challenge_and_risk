import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioService {
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
      _isMusicPlaying = state == PlayerState.playing;
    });

    _isInitialized = true;
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
    _isMusicEnabled = !_isMusicEnabled;

    if (!_isMusicEnabled) {
      await stopMusic();
    } else {
      // عند تشغيل الموسيقى مرة أخرى، إعادة تشغيل موسيقى القائمة الرئيسية بالقوة
      await forceRestartMainMenuMusic();
    }

    await _saveSettings();
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
      // إذا كانت نفس الموسيقى تعمل بالفعل، لا تعيد تشغيلها
      if (_currentlyPlayingMusic == musicFile && _isMusicPlaying) {
        return;
      }

      // إيقاف أي موسيقى تعمل حالياً
      await _musicPlayer.stop();

      // انتظار قصير للتأكد من إيقاف الموسيقى
      await Future.delayed(const Duration(milliseconds: 50));

      // تشغيل الموسيقى الجديدة
      await _musicPlayer.play(AssetSource('audio/music/$musicFile'));
      _currentlyPlayingMusic = musicFile;
      _isMusicPlaying = true;
    } catch (e) {
      print('Error playing music: $e');
    }
  }

  // Stop background music
  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
      _currentlyPlayingMusic = null;
      _isMusicPlaying = false;
    } catch (e) {
      print('Error stopping music: $e');
    }
  }

  // Pause background music
  Future<void> pauseMusic() async {
    try {
      await _musicPlayer.pause();
      _isMusicPlaying = false;
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
    } catch (e) {
      print('Error resuming music: $e');
    }
  }

  // Check if specific music is currently playing
  bool isPlayingMusic(String musicFile) {
    return _currentlyPlayingMusic == musicFile && _isMusicPlaying;
  }

  // Play sound effect
  Future<void> playSound(String soundFile) async {
    if (!_isSoundEnabled) return;

    try {
      await _soundPlayer.stop();
      await _soundPlayer.play(AssetSource('audio/sounds/$soundFile'));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  // Specific sound methods
  Future<void> playCorrectAnswer() async {
    await playSound('correct_answer.mp3');
  }

  Future<void> playWrongAnswer() async {
    await playSound('wrong_answer.mp3');
  }

  Future<void> playMainMenuMusic() async {
    await playMusic('main_menu_music.mp3');
  }

  Future<void> playResultsMusic() async {
    await playMusic('results_music.mp3');
  }

  // تأكد من استمرار تشغيل موسيقى القائمة الرئيسية
  Future<void> ensureMainMenuMusicPlaying() async {
    if (_isMusicEnabled && !isPlayingMusic('main_menu_music.mp3')) {
      await playMainMenuMusic();
    }
  }

  // إعادة تشغيل موسيقى القائمة الرئيسية بالقوة
  Future<void> forceRestartMainMenuMusic() async {
    if (_isMusicEnabled) {
      await stopMusic();
      await Future.delayed(const Duration(milliseconds: 100)); // انتظار قصير
      await playMainMenuMusic();
    }
  }

  // Dispose resources
  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _soundPlayer.dispose();
  }
}
