import 'package:shared_preferences/shared_preferences.dart';

/// Favori kanal URL'lerini cihazda saklar.
class FavoritesService {
  static const _key = 'favorite_urls';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  static Future<void> save(Set<String> urls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, urls.toList());
  }
}
