import 'dart:convert';

import 'package:iptv_player/models/channel.dart';

/// M3U / M3U8 playlist içeriğini kanal listesine çeviren ayrıştırıcı.
class M3uParser {
  static final _attrRe = RegExp(r'([\w-]+)="([^"]*)"');

  /// `#EXTINF` satırından sonra gelen kanal adını döndürür
  /// (son virgülden sonraki kısım).
  static String _nameFromExtinf(String line) {
    final idx = line.lastIndexOf(',');
    if (idx < 0) return '';
    return line.substring(idx + 1).trim();
  }

  /// `#EXTINF` satırından belirtilen özniteliği çeker (ör. `group-title`).
  static String? _attrFromExtinf(String line, String attr) {
    for (final m in _attrRe.allMatches(line)) {
      if (m.group(1) == attr) {
        final v = m.group(2)?.trim() ?? '';
        return v.isEmpty ? null : v;
      }
    }
    return null;
  }

  /// URL satırını temizler. Bazı playlistlerde URL'nin yanında
  /// fazladan boşluk/karakterler olabilir.
  static String _cleanUrl(String line) {
    var url = line.trim();
    // Satır sonundaki gereksiz karakterleri temizle.
    url = url.replaceFirst(RegExp(r'\s+.*$'), '');
    return url;
  }

  static String _guessName(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final seg = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (seg.isEmpty) return uri.host;
    return seg.last.split('.').first;
  }

  static List<Channel> parse(String content) {
    final lines = const LineSplitter().convert(content);
    final channels = <Channel>[];

    String? pendingName;
    String? pendingLogo;
    String? pendingGroup;
    String? pendingTvgId;
    String? pendingTvgName;
    String? pendingSubtitle;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTM3U') || line.startsWith('#EXT-X-')) {
        continue;
      }

      // VLC seçeneği: harici altyazı dosyası/adresi.
      if (line.startsWith('#EXTVLCOPT')) {
        final sub = _extvlcopt(line, 'sub-file');
        if (sub != null) pendingSubtitle = sub;
        continue;
      }
      if (line.startsWith('#EXTGRP')) {
        continue;
      }

      if (line.startsWith('#EXTINF')) {
        pendingName = _nameFromExtinf(line);
        pendingLogo = _attrFromExtinf(line, 'tvg-logo');
        pendingGroup = _attrFromExtinf(line, 'group-title');
        pendingTvgId = _attrFromExtinf(line, 'tvg-id');
        pendingTvgName = _attrFromExtinf(line, 'tvg-name');
        continue;
      }

      // Diğer yorum satırlarını atla.
      if (line.startsWith('#')) continue;

      final url = _cleanUrl(line);
      if (url.isEmpty) continue;

      final name = pendingName;
      channels.add(Channel(
        name: (name == null || name.isEmpty) ? _guessName(url) : name,
        url: url,
        group: pendingGroup,
        logo: pendingLogo,
        tvgId: pendingTvgId,
        tvgName: pendingTvgName,
        subtitleUrl: pendingSubtitle,
      ));

      pendingName = pendingLogo = pendingGroup = pendingTvgId = pendingTvgName = null;
      pendingSubtitle = null;
    }

    return channels;
  }

  /// `#EXTVLCOPT:anahtar=değer` biçiminden değeri çeker.
  static String? _extvlcopt(String line, String key) {
    final idx = line.indexOf(':');
    if (idx < 0) return null;
    final body = line.substring(idx + 1).trim();
    final eq = body.indexOf('=');
    if (eq < 0) return null;
    final k = body.substring(0, eq).trim();
    if (k != key) return null;
    final v = body.substring(eq + 1).trim();
    return v.isEmpty ? null : v;
  }
}
