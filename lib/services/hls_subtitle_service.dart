import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:iptv_player/services/stream_player.dart';

/// HLS akışındaki bir altyazı parçası (`#EXT-X-MEDIA:TYPE=SUBTITLES`).
class HlsSubtitleTrack {
  const HlsSubtitleTrack({
    required this.id,
    required this.name,
    required this.uri,
    this.language,
    this.isDefault = false,
    this.isAutoselect = false,
  });

  /// Parça kimliği (menüde seçim için).
  final String id;

  /// Görünen ad (NAME alanı).
  final String name;

  /// Altyazı media playlist adresi (mutlak).
  final String uri;

  /// LANGUAGE alanı (ör. "tr", "en").
  final String? language;

  /// DEFAULT=YES / AUTOSELECT=YES bayrakları.
  final bool isDefault;
  final bool isAutoselect;

  /// Türkçe mi? (dil kodu veya adı Türkçe içeriyorsa)
  bool get isTurkish {
    final lang = language?.toLowerCase() ?? '';
    final n = name.toLowerCase();
    return lang == 'tr' ||
        lang == 'tur' ||
        lang == 'turkish' ||
        n.contains('türk') ||
        n.contains('turk') ||
        n.contains('tr ') ||
        n == 'tr';
  }

  SubtitleInfo toInfo() => SubtitleInfo(id: id, title: name, language: language);
}

/// HLS altyazı desteği.
///
/// ExoPlayer (video_player) gömülü altyazı parçalarını Flutter arayüzüne
/// açmadığı için master playlist'i kendimiz ayrıştırıyoruz:
/// 1. Master playlist'ten `#EXT-X-MEDIA:TYPE=SUBTITLES` parçalarını bul.
/// 2. Seçilen parçanın media playlist'ini indir, WebVTT segmentlerini çek.
/// 3. Segmentlerdeki cue'ları video zaman çizelgesine göre birleştir.
class HlsSubtitleService {
  static const _ua =
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
      'Chrome/120.0 Mobile Safari/537.36';

  /// Master playlist'ten altyazı parçalarını çıkarır.
  /// [url] doğrudan bir media playlist'iyse boş liste döner.
  static Future<List<HlsSubtitleTrack>> discoverTracks(
    String url, {
    Map<String, String>? headers,
  }) async {
    try {
      final resp = await http
          .get(Uri.parse(url), headers: headers ?? const {'User-Agent': _ua})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];
      final body = _decodeUtf8(resp.bodyBytes);
      return parseMasterPlaylist(body, baseUrl: url);
    } catch (_) {
      return const [];
    }
  }

  /// Bir altyazı parçasının tüm WebVTT cue'larını video zaman çizelgesine
  /// göre yükler (canlıda medya playlist'i kayar; [maxCues] ile sınırlanır).
  static Future<List<SubtitleCue>> loadTrackCues(
    HlsSubtitleTrack track, {
    Map<String, String>? headers,
  }) async {
    try {
      final resp = await http
          .get(Uri.parse(track.uri), headers: headers ?? const {'User-Agent': _ua})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return const [];
      final playlist = _decodeUtf8(resp.bodyBytes);

      // Media playlist: segment URI'leri + süreleri.
      final segments = <(String, double)>[];
      final lines = playlist.split('\n');
      double? pendingDuration;
      for (final line in lines) {
        final l = line.trim();
        if (l.startsWith('#EXTINF:')) {
          final m = RegExp(r'#EXTINF:\s*([\d.]+)').firstMatch(l);
          pendingDuration = m != null ? double.tryParse(m.group(1)!) : 1.0;
        } else if (l.isNotEmpty && !l.startsWith('#')) {
          final uri = _resolveUri(track.uri, l);
          segments.add((uri, pendingDuration ?? 1.0));
          pendingDuration = null;
        }
      }
      if (segments.isEmpty) return const [];

      // Son ~60 segmenti al (canlı playlist kayar; uzun VOD'larda taşma olmasın).
      final take = segments.length > 60 ? segments.sublist(segments.length - 60) : segments;

      final cues = <SubtitleCue>[];
      var offset = Duration.zero;
      for (final (uri, dur) in take) {
        final segResp = await http
            .get(Uri.parse(uri), headers: headers ?? const {'User-Agent': _ua})
            .timeout(const Duration(seconds: 15));
        if (segResp.statusCode == 200) {
          final segCues = parseSubtitleCues(_decodeUtf8(segResp.bodyBytes));
          for (final c in segCues) {
            cues.add(SubtitleCue(
              c.start + offset,
              c.end + offset,
              c.text,
            ));
          }
        }
        offset += Duration(milliseconds: (dur * 1000).round());
      }
      return cues;
    } catch (_) {
      return const [];
    }
  }

  /// Master playlist'teki `#EXT-X-MEDIA:TYPE=SUBTITLES` satırlarını çözer.
  /// (Test edilebilmesi için genel.)
  static List<HlsSubtitleTrack> parseMasterPlaylist(
    String body, {
    required String baseUrl,
  }) {
    final tracks = <HlsSubtitleTrack>[];
    for (final line in body.split('\n')) {
      final l = line.trim();
      if (!l.startsWith('#EXT-X-MEDIA:')) continue;
      if (!RegExp(r'TYPE\s*=\s*SUBTITLES', caseSensitive: false).hasMatch(l)) {
        continue;
      }
      final attrs = _parseAttrs(l.substring('#EXT-X-MEDIA:'.length));
      final uri = attrs['URI'];
      if (uri == null) continue;
      final name = attrs['NAME'] ?? attrs['LANGUAGE'] ?? 'Altyazı';
      final id = attrs['GROUP-ID'] ?? name;
      tracks.add(HlsSubtitleTrack(
        id: id,
        name: name,
        uri: _resolveUri(baseUrl, uri),
        language: attrs['LANGUAGE'],
        isDefault: attrs['DEFAULT']?.toUpperCase() == 'YES',
        isAutoselect: attrs['AUTOSELECT']?.toUpperCase() == 'YES',
      ));
    }
    return tracks;
  }

  /// `KEY=VALUE,KEY2="VALUE2"` biçimindeki HLS özniteliklerini çözer.
  static Map<String, String> _parseAttrs(String raw) {
    final map = <String, String>{};
    // Tırnaklı değerlerde virgül olabileceği için tırnak gruplarını koru.
    final parts = RegExp(r'(?:[^,"]+|"[^"]*")+').allMatches(raw);
    for (final m in parts) {
      final part = m.group(0)!;
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      var key = part.substring(0, eq).trim();
      var value = part.substring(eq + 1).trim();
      if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
        value = value.substring(1, value.length - 1);
      }
      // Çıplak tırnakları temizle (örn. NAME=English değilse).
      key = key.replaceAll('"', '');
      map[key.toUpperCase()] = value;
    }
    return map;
  }

  static String _resolveUri(String base, String uri) {
    final b = Uri.parse(base);
    final u = Uri.parse(uri);
    if (u.hasScheme) return u.toString();
    return b.resolve(uri).toString();
  }

  static String _decodeUtf8(List<int> bytes) {
    // BOM varsa at.
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return utf8.decode(bytes.sublist(3));
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
