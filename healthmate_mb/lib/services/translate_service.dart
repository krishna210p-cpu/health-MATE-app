import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

class TranslateService {
  // Lightweight wrapper around LibreTranslate public instance.
  // Note: For production, replace with a paid/hosted translation API or server-side pre-translation.
  static const _endpoint = 'https://libretranslate.de/translate';

  static Future<String?> translate(String text, String targetLang) async {
    try {
      final resp = await http.post(Uri.parse(_endpoint), headers: {'Content-Type': 'application/json'}, body: convert.jsonEncode({'q': text, 'source': 'auto', 'target': targetLang, 'format': 'text'})).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final j = convert.jsonDecode(resp.body);
        if (j != null && j['translatedText'] != null) return j['translatedText'] as String;
      }
    } catch (_) {}
    return null;
  }
}
