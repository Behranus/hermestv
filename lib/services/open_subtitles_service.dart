import 'dart:convert';

import 'package:http/http.dart' as http;

/// OpenSubtitles servisi — hem yeni v1 API hem de eski REST API'yi kullanır.
///
/// v1 API: Requires valid API key (opensubtitles.org'dan ücretsiz alınır).
/// REST API (rest.opensubtitles.org): Ücretsiz, API key gerektirmez.
///
/// Akış: Önce REST API dener (key gerektirmez), başarısız olursa v1 API'ye düşer.
class OpenSubtitlesService {
  static const _restBaseUrl = 'https://rest.opensubtitles.org';
  static const _v1BaseUrl = 'https://api.opensubtitles.com/api/v1';

  // Varsayılan v1 API key
  static const _v1ApiKey = 'x7qNmWv2FGApt4CBOBqjGS7ktS6B4cQf';

  /// Film/dizi adına göre altyazı ara.
  ///
  /// Önce REST API'yi dener (key gerektirmez), sonra v1 API.
  static Future<List<SubtitleResult>> search({
    required String query,
    String? imdbId,
    String languages = 'tr,en',
    String? apiKey,
    int limit = 20,
  }) async {
    // Önce REST API'yi dene (daha güvenilir)
    final restResults = await _searchRest(
      query: query,
      imdbId: imdbId,
      languages: languages,
      limit: limit,
    );
    if (restResults.isNotEmpty) return restResults;

    // REST başarısız olursa v1 API'yi dene
    return _searchV1(
      query: query,
      imdbId: imdbId,
      languages: languages,
      apiKey: apiKey,
      limit: limit,
    );
  }

  /// REST API ile ara (rest.opensubtitles.org) — key gerektirmez.
  static Future<List<SubtitleResult>> _searchRest({
    required String query,
    String? imdbId,
    String languages = 'tr,en',
    int limit = 20,
  }) async {
    try {
      final langParts = languages.split(',');
      final langCode = langParts.first.trim();
      // Eski REST API tek dil kodu kullanır
      final restLang = _mapLangCode(langCode);

      final params = <String, String>{
        'query': query,
        'sublanguageid': restLang,
      };
      if (imdbId != null && imdbId.isNotEmpty) {
        params['imdbid'] = imdbId;
      }

      final uri = Uri.parse('$_restBaseUrl/search')
          .replace(queryParameters: params);
      final resp = await http
          .get(uri, headers: {
            'User-Agent': 'TemporaryUserAgent',
          })
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      if (data is! List) return [];

      final results = <SubtitleResult>[];
      for (final item in data) {
        if (item is! Map) continue;
        results.add(SubtitleResult(
          id: int.tryParse(item['IDSubtitleFile']?.toString() ?? '0') ?? 0,
          fileName: item['SubFileName'] ?? 'subtitle',
          language: item['ISO639'] ?? '',
          languageName: item['LanguageName'] ?? '',
          rating: (item['SubRating'] as num?)?.toInt(),
          format: item['SubFormat'],
          downloadCount: item['SubDownloadsCnt']?.toString(),
          imdbId: item['IDMovieImdb']?.toString(),
          movieName: item['MovieName'],
          season: int.tryParse(item['SeriesSeason']?.toString() ?? '0'),
          episode: int.tryParse(item['SeriesEpisode']?.toString() ?? '0'),
          downloadUrl: item['SubDownloadLink'] ?? '',
          isRestApi: true,
        ));
        if (results.length >= limit) break;
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// v1 API ile ara (api.opensubtitles.com) — API key gerektirir.
  static Future<List<SubtitleResult>> _searchV1({
    required String query,
    String? imdbId,
    String languages = 'tr,en',
    String? apiKey,
    int limit = 20,
  }) async {
    final key = apiKey ?? _v1ApiKey;
    final params = <String, String>{
      'query': query,
      'languages': languages,
      'limit': limit.toString(),
    };
    if (imdbId != null && imdbId.isNotEmpty) {
      params['imdb_id'] = imdbId;
    }

    try {
      final uri = Uri.parse('$_v1BaseUrl/subtitles')
          .replace(queryParameters: params);
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

  /// Altyazı dosyasının indirme URL'ini al.
  static Future<String?> getDownloadUrl({
    required String fileId,
    String? apiKey,
    bool isRestApi = false,
    String? restDownloadUrl,
  }) async {
    if (isRestApi && restDownloadUrl != null) {
      return restDownloadUrl;
    }
    final key = apiKey ?? _v1ApiKey;
    try {
      final resp = await http
          .post(
            Uri.parse('$_v1BaseUrl/download'),
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
    bool isRestApi = false,
    String? restDownloadUrl,
  }) async {
    final url = await getDownloadUrl(
      fileId: fileId,
      apiKey: apiKey,
      isRestApi: isRestApi,
      restDownloadUrl: restDownloadUrl,
    );
    if (url == null) return null;
    try {
      final resp = await http
          .get(Uri.parse(url), headers: {
            'User-Agent': 'TemporaryUserAgent',
          })
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) return resp.body;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// REST API dil kodunu OpenSubtitles formatına çevir.
  static String _mapLangCode(String code) {
    const map = {
      'tr': 'tur',
      'en': 'eng',
      'de': 'ger',
      'fr': 'fre',
      'es': 'spa',
      'it': 'ita',
      'pt': 'por',
      'ru': 'rus',
      'ar': 'ara',
      'ja': 'jpn',
      'ko': 'kor',
      'zh': 'chi',
      'nl': 'dut',
      'sv': 'swe',
      'pl': 'pol',
      'cs': 'cze',
      'el': 'gre',
      'hu': 'hun',
      'ro': 'rum',
      'da': 'dan',
      'fi': 'fin',
      'no': 'nor',
      'hr': 'hrv',
      'sr': 'srp',
      'bg': 'bul',
      'uk': 'ukr',
    };
    return map[code] ?? code;
  }
}

/// Arama sonucu altyazı bilgisi.
class SubtitleResult {
  final int id;
  final String fileName;
  final String language;
  final String languageName;
  final int? rating;
  final String? format;
  final String? downloadCount;
  final String? imdbId;
  final String? movieName;
  final int? season;
  final int? episode;
  final String downloadUrl;
  final bool isRestApi;

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
    this.downloadUrl = '',
    this.isRestApi = false,
  });

  factory SubtitleResult.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final lang = attrs['language'] as String? ?? '';
    return SubtitleResult(
      id: json['id'] ?? 0,
      fileName: attrs['release_name'] ??
          (attrs['files'] as List?)?.first?['file_name'] ??
          'subtitle',
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
      'tr': 'Türkçe', 'en': 'İngilizce', 'de': 'Almanca',
      'fr': 'Fransızca', 'es': 'İspanyolca', 'it': 'İtalyanca',
      'pt': 'Portekizce', 'ru': 'Rusça', 'ar': 'Arapça',
      'ja': 'Japonca', 'ko': 'Korece', 'zh': 'Çince',
      'nl': 'Felemenkçe', 'sv': 'İsveççe', 'pl': 'Lehçe',
      'cs': 'Çekçe', 'el': 'Yunanca', 'hu': 'Macarca',
      'ro': 'Rumence', 'da': 'Danca', 'fi': 'Fince',
      'no': 'Norveççe', 'hr': 'Hırvatça', 'sr': 'Sırpça',
      'bg': 'Bulgarca', 'uk': 'Ukraynaca',
    };
    return names[code] ?? code.toUpperCase();
  }

  String get subtitleFormat {
    if (format != null && format!.isNotEmpty) return format!;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.srt')) return 'SRT';
    if (lower.endsWith('.vtt')) return 'VTT';
    if (lower.endsWith('.ass')) return 'ASS';
    if (lower.endsWith('.ssa')) return 'SSA';
    return 'SRT';
  }
}
