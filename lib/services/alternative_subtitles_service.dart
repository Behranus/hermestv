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
            'User-Agent': 'hermestv v1.0',
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

  /// Subf2m.co ile ara — büyük Türkçe altyazı arşivi.
  static Future<List<AltSubtitleResult>> searchSubf2m({
    required String query,
    String language = 'turkish',
    int limit = 10,
  }) async {
    try {
      final encoded = Uri.encodeComponent(query);
      // 1. Film sayfasını bul
      final searchUrl = 'https://subf2m.co/subtitles/searchbytitle?query=$encoded';
      final searchResp = await http
          .get(Uri.parse(searchUrl), headers: {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
          })
          .timeout(const Duration(seconds: 12));

      if (searchResp.statusCode != 200) return [];

      // Film linklerini ayıkla
      final filmLinks = <String>[];
      final linkMatches = RegExp(r'href="/subtitles/([^"]+)"').allMatches(searchResp.body);
      for (final m in linkMatches) {
        final slug = m.group(1)!;
        if (!slug.contains('searchbytitle') && !filmLinks.contains(slug)) {
          filmLinks.add(slug);
        }
      }
      if (filmLinks.isEmpty) return [];

      // İlk 2 film için altyazıları çek
      final results = <AltSubtitleResult>[];
      for (final slug in filmLinks.take(2)) {
        if (results.length >= limit) break;
        final detailUrl = 'https://subf2m.co/subtitles/$slug/$language';
        try {
          final detailResp = await http
              .get(Uri.parse(detailUrl), headers: {
                'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
              })
              .timeout(const Duration(seconds: 10));
          if (detailResp.statusCode != 200) continue;

          // Altyazı linklerini ve bilgilerini ayıkla
          final subtitlePattern = RegExp(
            r'<div class=.topright.>\s*<span class=.language[^>]*>([^<]+)</span>.*?' // dil
            r'(?:<p>([^<]*)</p>)?.*?' // açıklama
            r"<a class='download icon-download' href='(/subtitles/[\w-]+/[\w-]+/(\d+))'",
            dotAll: true,
          );
          for (final m in subtitlePattern.allMatches(detailResp.body)) {
            if (results.length >= limit) break;
            final lang = m.group(1)?.trim() ?? '';
            final desc = m.group(2)?.trim() ?? '';
            final downloadPage = m.group(3) ?? '';
            final id = m.group(4) ?? '';
            results.add(AltSubtitleResult(
              id: 'subf2m_$id',
              fileName: desc.isNotEmpty ? '$slug ($lang) - $desc' : '$slug ($lang)',
              language: language,
              languageName: lang,
              downloadUrl: 'https://subf2m.co$downloadPage/download',
              source: 'Subf2m',
              format: 'SRT',
            ));
          }
        } catch (_) {}
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// TürkçeAltyazi.org'dan son yüklenen altyazıları çek.
  /// Web scraping — site JavaScript ağırlıklı olduğu için homepage'deki
  /// son altyazıları okur.
  static Future<List<AltSubtitleResult>> searchTurkceAltyazi({
    required String query,
    int limit = 10,
  }) async {
    try {
      // Filmin sayfasını bul (turkcealtyazi.org'un araması JS tabanlı,
      // bu yüzden Google site araması kullanıyoruz)
      final encoded = Uri.encodeComponent('site:turkcealtyazi.org/mov $query');
      final searchUrl = 'https://www.google.com/search?q=$encoded&num=5';
      final resp = await http
          .get(Uri.parse(searchUrl), headers: {
            'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
          })
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return [];

      // Film sayfalarını bul
      final pageLinks = <String>{};
      final linkMatches = RegExp(r'turkcealtyazi\.org/mov/[^"&\s]+').allMatches(resp.body);
      for (final m in linkMatches) {
        final url = 'https://${m.group(0)!}';
        if (!pageLinks.contains(url)) pageLinks.add(url);
      }

      final results = <AltSubtitleResult>[];
      for (final url in pageLinks.take(2)) {
        if (results.length >= limit) break;
        try {
          final pageResp = await http
              .get(Uri.parse(url), headers: {
                'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
              })
              .timeout(const Duration(seconds: 10));
          if (pageResp.statusCode != 200) continue;

          // Sayfadaki altyazı bilgilerini ayıkla
          final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(pageResp.body);
          final filmTitle = titleMatch?.group(1)?.replaceAll(' - Türkçe Altyazı', '').trim() ?? query;

          // Altyazı listesi (sub-container)
          final subPattern = RegExp(
            r"altsondiv[^>]*>.*?<a[^>]*href='([^']+download[^']*)'[^>]*>.*?<td[^>]*>([^<]+)</td",
            dotAll: true,
          );
          for (final m in subPattern.allMatches(pageResp.body)) {
            if (results.length >= limit) break;
            final dlPath = m.group(1) ?? '';
            final info = m.group(2)?.trim() ?? '';
            results.add(AltSubtitleResult(
              id: 'ta_${results.length}',
              fileName: '$filmTitle - $info',
              language: 'tr',
              languageName: 'Türkçe',
              downloadUrl: dlPath.startsWith('http') ? dlPath : 'https://turkcealtyazi.org$dlPath',
              source: 'TürkçeAltyazı',
              format: 'SRT',
            ));
          }
        } catch (_) {}
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  /// Tüm kaynakları paralel olarak dene.
  static Future<List<AltSubtitleResult>> searchAll({
    required String query,
    String languages = 'tr,en',
    int limit = 20,
  }) async {
    final results = <AltSubtitleResult>[];

    final futures = [
      searchYify(query: query, limit: 5),
      searchSubdl(query: query, languages: languages, limit: 5),
      searchSubf2m(query: query, limit: 5),
      searchTurkceAltyazi(query: query, limit: 5),
    ];

    final allResults = await Future.wait(futures, eagerError: false);
    for (final sourceResults in allResults) {
      results.addAll(sourceResults);
    }

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
