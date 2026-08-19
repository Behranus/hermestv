import 'dart:convert';

import 'package:http/http.dart' as http;

/// Alternatif altyazı servisleri — OpenSubtitles bulamazsa denenir.
///
/// Desteklenen kaynaklar:
/// 1. YIFY Subtitles (yifysubtitles.org) — popüler, geniş arşiv
/// 2. Subdl API (subdl.com) — hızlı, çoklu dil desteği
class AlternativeSubtitlesService {
  /// YIFY Subtitles'da ara.
  ///
  /// YIFY'nin resmi API'si yok, web scraping kullanır.
  /// Film adına göre arar, SRT linklerini döner.
  static Future<List<AltSubtitleResult>> searchYify({
    required String query,
    String languageCode = 'turkish',
    int limit = 10,
  }) async {
    try {
      final encoded = Uri.encodeComponent(query);
      final searchUrl = 'https://yts-subs.com/search/$encoded';
      final resp = await http
          .get(Uri.parse(searchUrl), headers: {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
          })
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return [];

      // Basit parsing — sayfadaki SRT linklerini bul
      final results = <AltSubtitleResult>[];
      final lines = resp.body.split('\n');
      for (final line in lines) {
        if (line.contains('.srt') && line.contains('href')) {
          final hrefMatch = RegExp(r'href="([^"]+\.srt)"').firstMatch(line);
          if (hrefMatch != null) {
            final href = hrefMatch.group(1)!;
            final nameMatch = RegExp(r'>([^<]+)<').firstMatch(line);
            results.add(AltSubtitleResult(
              id: 'yify_${results.length}',
              fileName: nameMatch?.group(1)?.trim() ?? 'subtitle.srt',
              language: 'turkish',
              languageName: 'Türkçe',
              downloadUrl: href.startsWith('http')
                  ? href
                  : 'https://yts-subs.com$href',
              source: 'YIFY',
            ));
          }
        }
        if (results.length >= limit) break;
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Subdl.com API ile ara.
  ///
  /// Subdl ücretsiz bir altyazı API'sidir. Film/dizi adı veya IMDB ile arar.
  static Future<List<AltSubtitleResult>> searchSubdl({
    required String query,
    String languages = 'tr,en',
    String type = 'movie', // movie veya tv
    int limit = 10,
  }) async {
    try {
      final params = {
        'film_name': query,
        'type': type,
        'languages': languages,
      };
      final uri = Uri.parse('https://api.subdl.com/auto')
          .replace(queryParameters: params);
      final resp = await http
          .get(uri, headers: {
            'User-Agent': 'bbtv v1.1',
          })
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode != 200) return [];

      final data = json.decode(resp.body);
      final subs = data['subtitles'] as List<dynamic>? ?? [];
      return subs.take(limit).map((item) {
        return AltSubtitleResult(
          id: 'subdl_${item['id'] ?? ''}',
          fileName: item['release_name'] ?? item['name'] ?? 'subtitle',
          language: item['lang'] ?? '',
          languageName: item['lang'] ?? '',
          downloadUrl: item['url'] ?? '',
          source: 'Subdl',
          format: item['format'],
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Tüm kaynakları paralel olarak dene.
  ///
  /// OpenSubtitles, YIFY ve Subdl'i aynı anda sorgular, sonuçları birleştirir.
  static Future<List<AltSubtitleResult>> searchAll({
    required String query,
    String languages = 'tr,en',
    int limit = 15,
  }) async {
    final results = <AltSubtitleResult>[];

    // Paralel olarak tüm kaynakları dene
    final futures = [
      searchYify(query: query, limit: 5),
      searchSubdl(query: query, languages: languages, limit: 5),
    ];

    final allResults = await Future.wait(futures, eagerError: false);
    for (final sourceResults in allResults) {
      results.addAll(sourceResults);
    }

    // Tekrar edenleri temizle (aynı dosya adı)
    final seen = <String>{};
    return results.where((r) => seen.add(r.fileName)).take(limit).toList();
  }
}

/// Alternatif altyazı sonucu.
class AltSubtitleResult {
  final String id;
  final String fileName;
  final String language;
  final String languageName;
  final String downloadUrl;
  final String source;
  final String? format;

  const AltSubtitleResult({
    required this.id,
    required this.fileName,
    required this.language,
    required this.languageName,
    required this.downloadUrl,
    required this.source,
    this.format,
  });

  String get subtitleFormat {
    if (format != null && format!.isNotEmpty) return format!;
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.srt')) return 'SRT';
    if (lower.endsWith('.vtt')) return 'VTT';
    if (lower.endsWith('.ass')) return 'ASS';
    return 'SRT';
  }

  /// Bu altyazı içeriğini indir.
  Future<String?> download() async {
    if (downloadUrl.isEmpty) return null;
    try {
      final resp = await http
          .get(Uri.parse(downloadUrl), headers: {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
          })
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) return resp.body;
      return null;
    } catch (_) {
      return null;
    }
  }
}
