import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSService {
  static Future<Position?> getLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied) return null;
      }
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
    } catch (e) {
      return null;
    }
  }

  static Future<void> sendSms(String number, String message) async {
    final uri = Uri(scheme: 'sms', path: number, queryParameters: {'body': message});
    if (!await launchUrl(uri)) {
      throw Exception('Could not open SMS app');
    }
  }

  static Future<void> openDialer(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (!await launchUrl(uri)) throw Exception('Could not open dialer');
  }
}
