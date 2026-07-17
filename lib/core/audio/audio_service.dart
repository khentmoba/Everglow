import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isMuted = false;
  
  bool get isMuted => _isMuted;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isMuted = prefs.getBool('isMuted') ?? false;
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMuted', _isMuted);
  }

  Future<void> playSfx(String assetPath) async {
    if (_isMuted) return;
    
    try {
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      Logger.e('Error playing SFX', error: e);
    }
  }

  // Pre-defined SFX
  static const String pop = 'assets/audio/pop.mp3';
  static const String sparkle = 'assets/audio/sparkle.mp3';
  static const String levelUp = 'assets/audio/level_up.mp3';
}
