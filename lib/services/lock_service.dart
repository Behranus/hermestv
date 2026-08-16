import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama açılış şifresi (kilit) servisi.
///
/// Şifre düz metin olarak saklanmaz; SHA-256 özeti kaydedilir.
/// Varsayılan şifre: `Berjin.2017` (kullanıcı değiştirebilir).
class LockService {
  static const defaultPassword = 'Berjin.2017';

  static const _enabledKey = 'lock_enabled';
  static const _hashKey = 'lock_hash';

  static String _hash(String password) =>
      sha256.convert(utf8.encode(password)).toString();

  /// Kilit açık mı? (Kayıt yoksa varsayılan olarak açık.)
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  /// Verilen şifre doğru mu?
  static Future<bool> verify(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_hashKey);
    final expected = stored ?? _hash(defaultPassword);
    return _hash(password.trim()) == expected;
  }

  /// Kilidi aç/kapat.
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Şifreyi değiştirir (boş bırakılamaz).
  static Future<void> changePassword(String newPassword) async {
    final trimmed = newPassword.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Şifre boş olamaz.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hashKey, _hash(trimmed));
    await prefs.setBool(_enabledKey, true);
  }

  /// Varsayılan şifreyi yeniden kurar (şifre unutulursa).
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hashKey);
    await prefs.setBool(_enabledKey, true);
  }
}
