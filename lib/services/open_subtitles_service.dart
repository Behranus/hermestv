import 'dart:convert';

import 'package:http/http.dart' as http;

/// OpenSubtitles API v1 servisi — film/dizi adına göre altyazı arar ve
/// SRT/VTT dosyalarını indirir.
///
/// Kullanım:
/// 1. Kullanıcı "Altyazı ara" butonuna basar
/// 2. Film/dizi adı ile arama yapılır (IMDB ID varsa onla)
/// 3. Dil filtresi uygulanır (varsayılan: Türkçe, İngilizce)
/// 4. Kullanıcı bir altyazı seçer
/// 5. SRT içeriği indirilip oynatıcıya yüklenir
///
/// API Key: Ücretsiz kayıtlı hesapla alınır (opensubtitles.org).
/// Kendi API key'ini ayarlara girerek kullanabilirsin.
class OpenSubtitlesService {
  static const _baseUrl = 'https://api.opensubtitles.com/api/v1';

  // Varsayılan API key — OpenSubtitles ücretsiz hesapla alınır.
  // Kullanıcı kendi key'ini ayarlara girebilir.
  static const _defaultApiKey = 'x7qNmWv2FGApt4CBOBqjGS7ktS6B4cQf';

  /// Film/dizi adına göre altyazı ara.
  ///
  /// [query] — Film/dizi adı (ör: "Inception", "Breaking Bad S01E01")
  /// [imdbId] — IMDB ID (varsa, daha kesin sonuç verir, ör: "tt1375666")
  /// [languages] — Dil kodları (ör: "tr,en"). Varsayılan "tr,en".
  /// [apiKey] — OpenSubtitles API key. Yoksa varsayılan kullanılır.
  ///
  /// Bulunan altyazı listesini döner.
  static Future<List<SubtitleResult>> search({
    required String query,
    String? imdbId,
    String languages = 'tr,en',
    String? apiKey,
    int limit = 10,
  }) async {
    final key = apiKey ?? _defaultApiKey;
    final params = <String, String>{
      'query': query,
      'languages': languages,
      'limit': limit.toString(),
    };
    if (imdbId != null && imdbId.isNotEmpty) {
      params['imdb_id'] = imdbId;
    }

    final uri = Uri.parse('$_baseUrl/subtitles').replace(queryParameters: params);
    try {
      final resp = await http
          .get(uri, headers: {
            'Api-Key': key,
            'User-Agent': 'bbtv v1.1',
          })
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final list = data['data'] as List<dynamic>? ?? [];
      return list.map((item) => SubtitleResult.fromJson(item)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Altyazı dosyasının indirme URL'ini al (SRT/VTT).
  ///
  /// OpenSubtitles API v1'de dosya indirmek için download endpoint'i kullanılır.
  /// Her istek 1 indirme kotasından düşer (günlük ücretsiz kota: 5).
  static Future<String?> getDownloadUrl({
    required String fileId,
    String? apiKey,
  }) async {
    final key = apiKey ?? _defaultApiKey;
    try {
      final resp = await http
          .post(
            Uri.parse('$_baseUrl/download'),
            headers: {
              'Api-Key': key,
              'Content-Type': 'application/json',
              'User-Agent': 'bbtv v1.1',
            },
            body: json.encode({'file_id': int.parse(fileId)}),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      return data['link'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Altyazı dosyasının içeriğini indir (SRT metni).
  static Future<String?> downloadSubtitleContent({
    required String fileId,
    String? apiKey,
  }) async {
    final url = await getDownloadUrl(fileId: fileId, apiKey: apiKey);
    if (url == null) return null;
    try {
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'bbtv v1.1'})
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) return resp.body;
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Arama sonucu altyazı bilgisi.
class SubtitleResult {
  final int id;
  final String fileName;
  final String language;
  final String languageName;
  final int? rating;
  final String? format; // SRT, VTT, ASS, vs.
  final String? downloadCount;
  final String? imdbId;
  final String? movieName;
  final int? season;
  final int? episode;

  const SubtitleResult({
    required this.id,
    required this.fileName,
    required this.language,
    required this.languageName,
    this.rating,
    this.format,
    this.downloadCount,
    this.imdbId,
    this.movieName,
    this.season,
    this.episode,
  });

  factory SubtitleResult.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final lang = attrs['language'] as String? ?? '';
    return SubtitleResult(
      id: json['id'] ?? 0,
      fileName: attrs['release_name'] ?? attrs['files']?[0]?['file_name'] ?? 'subtitle',
      language: lang,
      languageName: _langName(lang),
      rating: attrs['rating'] != null ? (attrs['rating'] as num).toInt() : null,
      format: attrs['format'],
      downloadCount: attrs['download_count']?.toString(),
      imdbId: attrs['imdb_id']?.toString(),
      movieName: attrs['movie_name'] ?? attrs['feature_title'],
      season: attrs['season_number'],
      episode: attrs['episode_number'],
    );
  }

  static String _langName(String code) {
    const names = {
      'tr': 'Türkçe',
      'en': 'İngilizce',
      'de': 'Almanca',
      'fr': 'Fransızca',
      'es': 'İspanyolca',
      'it': 'İtalyanca',
      'pt': 'Portekizce',
      'ru': 'Rusça',
      'ar': 'Arapça',
      'ja': 'Japonca',
      'ko': 'Korece',
      'zh': 'Çince',
      'nl': 'Felemenkçe',
      'sv': 'İsveççe',
      'pl': 'Lehçe',
      'cs': 'Çekçe',
      'el': 'Yunanca',
      'hu': 'Macarca',
      'ro': 'Rumence',
      'da': 'Danca',
      'fi': 'Fince',
      'no': 'Norveççe',
      'hr': 'Hırvatça',
      'sr': 'Sırpça',
      'bg': 'Bulgarca',
      'uk': 'Ukraynaca',
    };
    return names[code] ?? code.toUpperCase();
  }

  /// Dosya uzantısını belirle (SRT, VTT, ASS).
  String get subtitleFormat {
    if (format != null && format!.isNotEmpty) return format!;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.srt')) return 'SRT';
    if (lower.endsWith('.vtt')) return 'VTT';
    if (lower.endsWith('.ass')) return 'ASS';
    if (lower.endsWith('.ssa')) return 'SSA';
    if (lower.endsWith('.sub')) return 'SUB';
    return 'SRT'; // Varsayılan
  }
}
