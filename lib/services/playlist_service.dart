import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/services/channel_probe_service.dart';
import 'package:hermestv/services/m3u_parser.dart';
import 'package:hermestv/services/test_stream_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Playlistin nereden geldiğini belirtir.
enum PlaylistSourceType { url, file, demo, xtream }

/// Kaydedilebilir playlist kaynağı.
class PlaylistSource {
  const PlaylistSource(this.type, this.value, {this.isTest = false, this.isActive = true, this.channelCount});

  final PlaylistSourceType type;
  final String value;

  /// Kaynak test bölümünden mi geldi? (kanal doğrulama + VOD kataloğu için)
  final bool isTest;

  /// Kaynak aktif mi (kanal listesinde görünsün mü)
  final bool isActive;

  /// Bu kaynaktan yüklenen kanal sayısı
  final int? channelCount;

  PlaylistSource copyWith({bool? isActive, int? channelCount}) {
    return PlaylistSource(type, value, isTest: isTest, isActive: isActive ?? this.isActive, channelCount: channelCount ?? this.channelCount);
  }

  Map<String, dynamic> toJson() =>
      {'type': type.name, 'value': value, 'test': isTest, 'active': isActive, 'channelCount': channelCount};

  static PlaylistSource? fromJson(Map<String, dynamic> json) {
    final t = PlaylistSourceType.values.asNameMap()[json['type']];
    final v = json['value'] as String?;
    if (t == null || v == null || v.isEmpty) return null;
    return PlaylistSource(t, v, isTest: json['test'] == true, isActive: json['active'] != false, channelCount: json['channelCount'] as int?);
  }
}

/// Playlist yükleme ve kaynak kalıcılığı.
class PlaylistService {
  static const _sourceKey = 'playlist_source';

  /// URL'den veya dosyadan playlist içeriğini çeker ve ayrıştırır.
  ///
  /// İndirme + çözümleme + ayrıştırma **tamamen arka plan izolatında** çalışır
  /// ([compute]). 30MB'lık bir iptv-org listesinde `utf8.decode` ve 10k kanal
  /// ayrıştırması UI izolatında yapılırsa yavaş Box'larda saniyelerce donma
  /// (ANR) ve çökme olur — [onProgress] bu nedenle artık kullanılmaz, UI
  /// yalnızca dönen yükleyici gösterir.
  static Future<List<Channel>> load(
    PlaylistSource source, {
    void Function(int done)? onProgress,
  }) async {
    final channels = await compute(_loadInIsolate, source);
    if (channels.isEmpty) {
      throw const FormatException('Playlist içinde kanal bulunamadı.');
    }
    return channels;
  }

  /// [compute] geri çağrısı: indirme + çözümleme + ayrıştırma tek izolatta.
  static Future<List<Channel>> _loadInIsolate(PlaylistSource source) async {
    final content = await _fetch(source);
    return M3uParser.parse(content);
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

  /// URL/dosya kaynağı için **disk önbelleği**. Devasa ücretsiz kanal
  /// listeleri (iptv-org — 10k+ kanal) her açılışta yeniden indirilirse
  /// hem yavaş hem RAM'li Box'larda çökmeye neden olur. Önbellek günde bir
  /// kez tazelenir; aradaki açılışlar diski okur (anında).
  static Future<List<Channel>?> loadCached(PlaylistSource source) async {
    if (source.type != PlaylistSourceType.url &&
        source.type != PlaylistSourceType.file) {
      return null;
    }
    final file = await _cacheFile(source);
    if (file == null) return null;
    try {
      if (!await file.exists()) return null;
      final stat = await file.stat();
      if (DateTime.now().difference(stat.modified) > const Duration(hours: 24)) {
        return null; // Günlük yenileme: önbellek bayat.
      }
      // 10k+ kanallık JSON'u UI izolatında çözmek yine kısa bir blok yaratır;
      // arka plan izolatında çözülür.
      final channels = await compute(
        ChannelProbeService.decode,
        await file.readAsString(),
      );
      return channels.isEmpty ? null : channels;
    } catch (_) {
      return null;
    }
  }

  /// Ayrıştırılan kanalları disk önbelleğine yazar.
  static Future<void> saveCache(
    PlaylistSource source,
    List<Channel> channels,
  ) async {
    if (source.type != PlaylistSourceType.url &&
        source.type != PlaylistSourceType.file) {
      return;
    }
    final file = await _cacheFile(source);
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      // 10k+ kanalın JSON kodlaması UI izolatında yapılırsa kısa ama hissedilir
      // bir donma yaratır; arka plan izolatında kodlanır.
      final json = await compute(ChannelProbeService.encode, channels);
      await file.writeAsString(json);
    } catch (_) {
      // Önbellek yazılamazsa sessizce geç — indirme her zaman çalışır.
    }
  }

  static Future<File?> _cacheFile(PlaylistSource source) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final key = '${source.type.name}:${source.value}';
      final hash = sha256.convert(utf8.encode(key)).toString().substring(0, 20);
      return File('${dir.path}/playlist_$hash.json');
    } catch (_) {
      return null;
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

  // ---- Çoklu kaynak desteği (TiviMate tarzı) ----
  static const _multiSourceKey = 'multi_sources';
  static const _activeSourceKey = 'active_source_index';

  /// Tüm IPTV kaynaklarını kaydet.
  static Future<void> saveAllSources(List<PlaylistSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = sources.map((s) => s.toJson()).toList();
    await prefs.setString(_multiSourceKey, jsonEncode(jsonList));
  }

  /// Tüm IPTV kaynaklarını yükle.
  static Future<List<PlaylistSource>> loadAllSources() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_multiSourceKey);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map((j) => PlaylistSource.fromJson(j)!).toList();
    } catch (_) {
      return [];
    }
  }

  /// Aktif kaynağın indeksini kaydet (son yüklenen).
  static Future<void> saveActiveIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeSourceKey, index);
  }

  /// Aktif kaynak indeksini al.
  static Future<int> loadActiveIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeSourceKey) ?? 0;
  }

  /// Kaynağı listeye ekle veya güncelle (aynı value varsa güncelle).
  static Future<List<PlaylistSource>> addOrUpdateSource(PlaylistSource source) async {
    final sources = await loadAllSources();
    final idx = sources.indexWhere((s) => s.value == source.value);
    if (idx >= 0) {
      sources[idx] = source;
    } else {
      sources.add(source);
    }
    await saveAllSources(sources);
    return sources;
  }

  /// Kaynağı sil.
  static Future<List<PlaylistSource>> removeSource(int index) async {
    final sources = await loadAllSources();
    if (index >= 0 && index < sources.length) {
      sources.removeAt(index);
      await saveAllSources(sources);
    }
    return sources;
  }
}
