import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/services/m3u_parser.dart';
import 'package:iptv_player/services/test_stream_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Playlistin nereden geldiğini belirtir.
enum PlaylistSourceType { url, file, demo, xtream }

/// Kaydedilebilir playlist kaynağı.
class PlaylistSource {
  const PlaylistSource(this.type, this.value, {this.isTest = false});

  final PlaylistSourceType type;
  final String value;

  /// Kaynak test bölümünden mi geldi? (kanal doğrulama + VOD kataloğu için)
  final bool isTest;

  Map<String, dynamic> toJson() =>
      {'type': type.name, 'value': value, 'test': isTest};

  static PlaylistSource? fromJson(Map<String, dynamic> json) {
    final t = PlaylistSourceType.values.asNameMap()[json['type']];
    final v = json['value'] as String?;
    if (t == null || v == null || v.isEmpty) return null;
    return PlaylistSource(t, v, isTest: json['test'] == true);
  }
}

/// Playlist yükleme ve kaynak kalıcılığı.
class PlaylistService {
  static const _sourceKey = 'playlist_source';

  /// URL'den veya dosyadan playlist içeriğini çeker ve ayrıştırır.
  static Future<List<Channel>> load(PlaylistSource source) async {
    final content = await _fetch(source);
    final channels = M3uParser.parse(content);
    if (channels.isEmpty) {
      throw const FormatException('Playlist içinde kanal bulunamadı.');
    }
    return channels;
  }

  /// İçeriği güvenli şekilde metne çevirir:
  /// önce UTF-8 dene (Türkçe karakterler için), olmazsa Latin-1 kullan.
  /// Baştaki BOM işaretini kaldırır.
  static String decodeContent(List<int> bytes) {
    var text = '';
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      // Birçok IPTV playlist'i ISO-8859-9/Latin-1 kodludur.
      text = latin1.decode(bytes);
    }
    // BOM kaldır.
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    return text;
  }

  static Future<String> _fetch(PlaylistSource source) async {
    switch (source.type) {
      case PlaylistSourceType.demo:
        // Test yayınları her çağrıda canlı kontrol edilir — liste kendini günceller.
        return TestStreamService.fetchPlaylist();
      case PlaylistSourceType.url:
        final uri = Uri.tryParse(source.value);
        if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
          throw const FormatException('Geçersiz URL.');
        }
        final resp = await http
            .get(uri, headers: {'User-Agent': 'IPTVPlayer/1.0'})
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200) {
          throw HttpException('HTTP ${resp.statusCode} hatası', uri: uri);
        }
        return decodeContent(resp.bodyBytes);
      case PlaylistSourceType.file:
        final file = File(source.value);
        if (!await file.exists()) {
          throw const FileSystemException('Dosya bulunamadı.');
        }
        return decodeContent(await file.readAsBytes());
      case PlaylistSourceType.xtream:
        // Xtream kaynağı AppState içinde özel olarak yüklenir.
        throw const FormatException('Xtream kaynağı doğrudan yüklenemez.');
    }
  }

  /// Kaydedilmiş playlist kaynağını geri yükler (yoksa null).
  static Future<PlaylistSource?> restoreSource() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sourceKey);
    if (raw == null) return null;
    try {
      return PlaylistSource.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveSource(PlaylistSource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sourceKey, jsonEncode(source.toJson()));
  }

  static Future<void> clearSource() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sourceKey);
  }
}
