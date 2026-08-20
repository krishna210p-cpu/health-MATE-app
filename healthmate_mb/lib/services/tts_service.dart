import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();

  TTSService() {
    _tts.setSpeechRate(0.45);
    _tts.setPitch(1.0);
  }

  Future<void> speak(String text, {String? lang}) async {
    if (lang != null) {
      // Map simplified language codes to likely TTS locales
      final code = _mapToTtsLocale(lang);
      await _tts.setLanguage(code);
    }
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}

String _mapToTtsLocale(String lang) {
  switch (lang) {
    case 'hi': return 'hi-IN';
    case 'en': return 'en-IN';
    case 'mr': return 'mr-IN';
    case 'bn': return 'bn-IN';
    case 'ta': return 'ta-IN';
    case 'te': return 'te-IN';
    case 'kn': return 'kn-IN';
    case 'ml': return 'ml-IN';
    case 'gu': return 'gu-IN';
    case 'pa': return 'pa-IN';
    default: return 'en-IN';
  }
}
