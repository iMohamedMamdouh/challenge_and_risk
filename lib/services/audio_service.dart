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

  // Getters
  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSoundEnabled => _isSoundEnabled;

  // Initialize audio service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _loadSettings();

    // Set music player to loop
    _musicPlayer.setReleaseMode(ReleaseMode.loop);

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
      await _musicPlayer.stop();
      await _musicPlayer.play(AssetSource('audio/music/$musicFile'));
    } catch (e) {
      print('Error playing music: $e');
    }
  }

  // Stop background music
  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
    } catch (e) {
      print('Error stopping music: $e');
    }
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

  // Dispose resources
  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _soundPlayer.dispose();
  }
}
