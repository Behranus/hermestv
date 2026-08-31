import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hermestv/models/vod.dart';

/// YTS (YIFY) Torrent Film Kütüphanesi
/// API: https://yts.mx/api/v2/list_movies.json
/// Bedava, yüksek kaliteli filmler magnet link ile
class YtsService {
  static const _baseUrl = 'https://yts.mx/api/v2';
  static const _imageBase = 'https://yts.mx/assets/images/movies';

  /// Film listesi çek — kategori ve sayfaya göre
  static Future<List<VodMovie>> fetchMovies({
    String? genre,
    String? quality,
    int page = 1,
    int limit = 20,
    String sortBy = 'date_added',
    String orderBy = 'desc',
  }) async {
    try {
      final params = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sort_by': sortBy,
        'order_by': orderBy,
      };
      if (genre != null && genre.isNotEmpty) params['genre'] = genre;
      if (quality != null && quality.isNotEmpty) params['quality'] = quality;

      final uri = Uri.parse('$_baseUrl/list_movies.json').replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      if (data['status'] != 'ok' || data['data'] == null) return [];

      final movies = (data['data']['movies'] as List?) ?? [];
      return movies.map((m) => _parseMovie(m)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Film ara
  static Future<List<VodMovie>> searchMovies(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/list_movies.json?query_term=$query&limit=$limit');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      if (data['status'] != 'ok' || data['data'] == null) return [];

      final movies = (data['data']['movies'] as List?) ?? [];
      return movies.map((m) => _parseMovie(m)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Film detayı + magnet link
  static Future<VodMovie?> getMovieDetail(int movieId) async {
    try {
      final uri = Uri.parse('$_baseUrl/movie_details.json?movie_id=$movieId');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      if (data['status'] != 'ok' || data['data'] == null) return null;

      return _parseMovie(data['data']['movie']);
    } catch (_) {
      return null;
    }
  }

  static VodMovie _parseMovie(Map<String, dynamic> m) {
    final torrents = (m['torrents'] as List?) ?? [];
    final magnetLinks = <String>[];

    for (final t in torrents) {
      final hash = t['hash'] ?? '';
      final name = Uri.encodeComponent('${m['title']} (${t['quality'] ?? ''})');
      if (hash.toString().isNotEmpty) {
        magnetLinks.add('magnet:?xt=urn:btih:$hash&dn=$name&tr=udp://open.demonii.com:1337/announce&tr=udp://tracker.openbittorrent.com:6969');
      }
    }

    // En yüksek kaliteyi seç
    String? streamUrl;
    if (torrents.isNotEmpty) {
      // 1080p varsa onu seç, yoksa en yükseğini al
      final best = torrents.firstWhere(
        (t) => t['quality'] == '1080p',
        orElse: () => torrents.first,
      );
      final hash = best['hash'] ?? '';
      if (hash.toString().isNotEmpty) {
        final name = Uri.encodeComponent(m['title'].toString() + ' (' + (best['quality'] ?? '') + ')');
        streamUrl = 'magnet:?xt=urn:btih:$hash&dn=$name&tr=udp://open.demonii.com:1337/announce&tr=udp://tracker.openbittorrent.com:6969';
      }
    }

    return VodMovie(
      id: 'yts_${m['id']}',
      name: m['title'] ?? 'Bilinmeyen',
      poster: m['medium_cover_image'] ?? m['small_cover_image'] ?? '',
      backdrop: m['background_image'] ?? '',
      plot: m['description_full'] ?? m['synopsis'] ?? '',
      rating: (m['rating'] ?? 0).toString(),
      year: m['year']?.toString() ?? '',
      genre: (m['genres'] as List?)?.join(', ') ?? '',
      streamUrl: streamUrl ?? '',
      duration: '${m['runtime'] ?? 0} dk',
      actors: '', // YTS'de oyuncu bilgisi yok
      director: '',
      extra: {
        'source': 'YTS',
        'magnetLinks': magnetLinks,
        'torrents': torrents.map((t) => {
          'quality': t['quality'],
          'type': t['type'],
          'size': t['size'],
          'hash': t['hash'],
        }).toList(),
        'language': m['language'] ?? '',
        'mpaRating': m['mpa_rating'] ?? '',
      },
    );
  }

  /// Popüler türler
  static const genres = [
    'Action', 'Adventure', 'Animation', 'Biography', 'Comedy',
    'Crime', 'Documentary', 'Drama', 'Family', 'Fantasy',
    'History', 'Horror', 'Music', 'Mystery', 'Romance',
    'Sci-Fi', 'Sport', 'Thriller', 'War', 'Western',
  ];
}
