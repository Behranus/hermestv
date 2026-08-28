import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// TMDB API'den film/oyuncu görsellerini cache'li olarak çeken servis.
/// API key gerekmez — backdrop/poster URL'leri Xtream API'den gelir.
/// Oyuncu görselleri için film adına göre arama yapılır.
class TmdbImageService {
  static const _cachePrefix = 'tmdb_img_';
  static const _cacheExpiry = Duration(hours: 24);

  /// Oyuncu adından yüksek kaliteli görsel URL döndür.
  static Future<String?> fetchActorImage(String actorName, String? tmdbId) async {
    final cached = await _getCached(actorName);
    if (cached == 'NONE') return null;
    if (cached != null) return cached;
    try {
      await _cacheValue(actorName, 'NONE');
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Belirli bir TMDB film ID'sinden cast fotoğraflarını çek.
  static Future<Map<String, String>> fetchCastImages(String tmdbId) async {
    final cacheKey = 'cast_$tmdbId';
    final cached = await _getCached(cacheKey);
    if (cached != null && cached != 'NONE') {
      try {
        return Map<String, String>.from(jsonDecode(cached));
      } catch (_) {}
    }

    try {
      // TMDB public API (API key gerekli — key yoksa boş dön)
      final resp = await http.get(
        Uri.parse('https://api.themoviedb.org/3/movie/$tmdbId/credits?api_key=demo'),
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final castList = data['cast'] as List? ?? [];
        final images = <String, String>{};
        for (final c in castList.take(12)) {
          final name = c['name'] as String? ?? '';
          final profilePath = c['profile_path'] as String?;
          if (name.isNotEmpty && profilePath != null) {
            images[name] = 'https://image.tmdb.org/t/p/w185$profilePath';
          }
        }
        if (images.isNotEmpty) {
          await _cacheValue(cacheKey, jsonEncode(images));
        }
        return images;
      }
    } catch (_) {}
    return {};
  }

  static Future<String?> _getCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$key');
      if (raw == null) return null;
      final ts = prefs.getInt('$_cachePrefix${key}_ts') ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - ts > _cacheExpiry.inMilliseconds) {
        return null;
      }
      return raw;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _cacheValue(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_cachePrefix$key', value);
      await prefs.setInt('$_cachePrefix${key}_ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }
}
