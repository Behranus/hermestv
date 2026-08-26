import 'package:shared_preferences/shared_preferences.dart';

/// Çocuk kilidi servisi — belirli kanalları PIN ile kilitleme.
class ParentalLockService {
  static const _keyPrefix = 'parental_locked_';
  static const _pinKey = 'parental_pin';

  /// Varsayılan PIN
  static const defaultPin = '0000';

  /// Kanal kilidini kontrol et
  static Future<bool> isLocked(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_keyPrefix$channelId') ?? false;
  }

  /// Kanal kilidini aç/kapat
  static Future<void> toggleLock(String channelId, bool locked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_keyPrefix$channelId', locked);
  }

  /// Tüm kilitli kanalların ID'lerini al
  static Future<List<String>> getLockedChannels() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    return keys.map((k) => k.substring(_keyPrefix.length)).toList();
  }

  /// PIN'i kaydet
  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
  }

  /// PIN'i kontrol et
  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinKey);
    return stored == pin || (stored == null && pin == defaultPin);
  }

  /// Mevcut PIN'i al (varsayılan: 0000)
  static Future<String> getPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinKey) ?? defaultPin;
  }
}
