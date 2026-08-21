import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/models/vod.dart';

/// Xtream Codes portal bilgileri.
class XtreamCredentials {
  const XtreamCredentials({
    required this.server,
    required this.username,
    required this.password,
  });

  final String server;
  final String username;
  final String password;

  String get base => server.replaceAll(RegExp(r'/+$'), '');

  Map<String, dynamic> toJson() => {
        'server': server,
        'username': username,
        'password': password,
      };

  static XtreamCredentials? fromJson(Map<String, dynamic> json) {
    final s = json['server'] as String?;
    final u = json['username'] as String?;
    final p = json['password'] as String?;
    if (s == null || u == null || p == null) return null;
    return XtreamCredentials(server: s, username: u, password: p);
  }
}

/// Xtream Codes API istemcisi.
///
/// Referans: `player_api.php?username=..&password=..` endpoint'leri.
class XtreamService {
  /// Çoğu CDN'in reddettiği basit agent yerine tarayıcı benzeri UA —
  /// bazı 4K/HD kanal akışları bunu ister.
  static const _ua = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      'Chrome/120.0.0.0 Mobile Safari/537.36';
  static const _timeout = Duration(seconds: 30);

  static Future<dynamic> _api(
    XtreamCredentials c,
    String action,
  ) async {
    final url = '${c.base}/player_api.php'
        '?username=${Uri.encodeQueryComponent(c.username)}'
        '&password=${Uri.encodeQueryComponent(c.password)}'
        '${action.isEmpty ? '' : '&action=$action'}';
    final resp = await http
        .get(Uri.parse(url), headers: {'User-Agent': _ua})
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('Sunucu HTTP ${resp.statusCode} döndürdü.');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
    if (decoded is Map && decoded['user_info'] == null && action.isEmpty) {
      throw const FormatException('Geçersiz kullanıcı adı veya şifre.');
    }
    return decoded;
  }

  /// Büyük listeler (canlı kanallar, VOD) için API çağrısı.
  ///
  /// JSON çözümleme arka plan izolatında çalışır — 10k+ kanallık bir
  /// `get_live_streams` yanıtı UI izolatında çözülürse uygulama saniyelerce
  /// donar ve 2GB RAM'li Box'larda çökebilir.
  static Future<dynamic> _apiLarge(
    XtreamCredentials c,
    String action,
  ) async {
    final url = '${c.base}/player_api.php'
        '?username=${Uri.encodeQueryComponent(c.username)}'
        '&password=${Uri.encodeQueryComponent(c.password)}'
        '${action.isEmpty ? '' : '&action=$action'}';
    final resp = await http
        .get(Uri.parse(url), headers: {'User-Agent': _ua})
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw Exception('Sunucu HTTP ${resp.statusCode} döndürdü.');
    }
    return compute(_decodeJson, resp.bodyBytes);
  }

  /// Ham JSON baytlarını izolatta çözer (compute için top-level benzeri).
  static dynamic _decodeJson(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes));

  /// Girişi doğrular; `user_info` içeren hesap özetini döndürür.
  static Future<Map<String, dynamic>> login(XtreamCredentials c) async {
    final data = await _api(c, '');
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Beklenmeyen sunucu yanıtı.');
    }
    return data;
  }

  /// Canlı kanalları kategorileriyle birlikte yükler.
  ///
  /// Dönen kanalların `url` alanı doğrudan oynatılabilir:
  /// `{server}/live/{kullanıcı}/{şifre}/{stream_id}.m3u8`
  static Future<List<Channel>> loadLiveChannels(XtreamCredentials c) async {
    final categoriesRaw = await _api(c, 'get_live_categories');
    final streamsRaw = await _apiLarge(c, 'get_live_streams');
    if (streamsRaw is! List) {
      throw const FormatException('Kanal listesi alınamadı.');
    }

    final catNames = <String, String>{};
    if (categoriesRaw is List) {
      for (final cat in categoriesRaw) {
        if (cat is Map) {
          final id = cat['category_id']?.toString();
          final name = cat['category_name']?.toString();
          if (id != null && name != null) catNames[id] = name;
        }
      }
    }

    final channels = <Channel>[];
    final seen = <String>{};
    for (final s in streamsRaw) {
      if (s is! Map) continue;
      final id = s['stream_id']?.toString();
      if (id == null) continue;
      final name = (s['name']?.toString() ?? '').trim();
      if (name.isEmpty) continue;

      final categoryId = s['category_id']?.toString();
      final url = '${c.base}/live/${c.username}/${c.password}/$id.m3u8';
      // Aynı akış birden fazla kategoride listelenebilir.
      if (!seen.add('$id|$url')) continue;

      channels.add(Channel(
        name: name,
        url: url,
        group: catNames[categoryId] ?? 'Diğer',
        logo: s['stream_icon']?.toString().isNotEmpty == true
            ? s['stream_icon'].toString()
            : null,
        tvgId: s['epg_channel_id']?.toString(),
        tvgName: s['epg_channel_name']?.toString(),
      ));
    }

    if (channels.isEmpty) {
      throw const FormatException('Hesapta canlı kanal bulunamadı.');
    }
    return channels;
  }

  /// Xtream portalının EPG adresi (`xmltv.php`).
  static String epgUrl(XtreamCredentials c) =>
      '${c.base}/xmltv.php?username=${Uri.encodeQueryComponent(c.username)}'
      '&password=${Uri.encodeQueryComponent(c.password)}';

  /// Bir playlist URL'sinin Xtream tabanlı olup olmadığını anlar.
  ///
  /// Birçok sağlayıcı M3U adresi yerine şu biçimde Xtream linki verir:
  /// `http://sunucu:8080/get.php?username=xxx&password=yyy&type=m3u_plus`
  /// veya `http://sunucu:8080/player_api.php?username=xxx&password=yyy`.
  /// Böyle bir adres bulunursa kimlik bilgilerini çıkarır, yoksa null döner.
  static XtreamCredentials? tryParsePlaylistUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    if (!(uri.isScheme('http') || uri.isScheme('https'))) return null;
    final path = uri.path;
    final isXtreamEndpoint =
        path.endsWith('get.php') || path.contains('player_api.php');
    final username = uri.queryParameters['username'] ?? uri.queryParameters['user'];
    final password = uri.queryParameters['password'] ?? uri.queryParameters['pass'];
    if (username == null || password == null) return null;
    if (username.isEmpty || password.isEmpty) return null;
    // get.php olmayan sıradan M3U adreslerinde username paramı bulunmaz;
    // yine de emin olmak için uç noktayı doğrula.
    if (!isXtreamEndpoint && !path.contains('get.php')) return null;
    final server = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return XtreamCredentials(server: server, username: username, password: password);
  }

  /// M3U kanallarından Xtream kimlik bilgilerini çıkarmayı dener.
  ///
  /// Xtream tabanlı playlistlerde kanal adresleri şu biçimdedir:
  /// `{sunucu}/live/{kullanıcı}/{şifre}/{id}.m3u8` (movie/series de olabilir).
  /// Böyle bir kanal bulunursa aynı bilgilerle VOD erişimi açılabilir.
  static XtreamCredentials? tryFromChannelUrls(List<Channel> channels) {
    final re = RegExp(r'^(https?://[^/]+)/(?:live|movie|series)/([^/]+)/([^/]+)/');
    for (final c in channels) {
      final m = re.firstMatch(c.url);
      if (m == null) continue;
      final username = m.group(2) ?? '';
      final password = m.group(3) ?? '';
      if (username.isEmpty || password.isEmpty) continue;
      return XtreamCredentials(
        server: m.group(1)!,
        username: username,
        password: password,
      );
    }
    return null;
  }

  /// VOD filmi için oynatma adresi: `{server}/movie/{u}/{p}/{id}.m3u8`
  /// Film oynatma adresi: `{server}/movie/{u}/{p}/{id}.{uzantı}`
  ///
  /// Uzantı Xtream API'sinin bildirdiği `container_extension` değeridir
  /// (mp4/mkv/avi…). ExoPlayer URL uzantısına göre HLS/MP4 kararı verir;
  /// her zaman `.m3u8` eklemek MP4/MKV filmlerin açılmamasına yol açar.
  /// Uzantı bilinmiyorsa (boşsa) m3u8 denenir.
  static String movieUrl(XtreamCredentials c, int movieId,
          {String? containerExtension}) =>
      '${c.base}/movie/${c.username}/${c.password}/$movieId.'
      '${_ext(containerExtension)}';

  /// Dizi bölümü için oynatma adresi: `{server}/series/{u}/{p}/{id}.{uzantı}`
  static String episodeUrl(XtreamCredentials c, int episodeId,
          {String? containerExtension}) =>
      '${c.base}/series/${c.username}/${c.password}/$episodeId.'
      '${_ext(containerExtension)}';

  /// Sunucunun bildirdiği uzantı varsa onu, yoksa m3u8 döner.
  static String _ext(String? containerExtension) {
    final e = containerExtension?.trim().toLowerCase();
    if (e == null || e.isEmpty || e == '.' || e.contains('/')) return 'm3u8';
    return e;
  }

  /// VOD kategorilerini yükler: kategori_id → kategori adı.
  static Future<Map<String, String>> loadVodCategories(XtreamCredentials c) async {
    final raw = await _api(c, 'get_vod_categories');
    final map = <String, String>{};
    if (raw is List) {
      for (final cat in raw) {
        if (cat is Map) {
          final id = cat['category_id']?.toString();
          final name = cat['category_name']?.toString();
          if (id != null && name != null) map[id] = name;
        }
      }
    }
    return map;
  }

  /// Tüm filmleri yükler (kategori bilgisiyle birlikte).
  static Future<List<VodMovie>> loadVodMovies(XtreamCredentials c) async {
    final raw = await _apiLarge(c, 'get_vod_streams');
    final movies = <VodMovie>[];
    if (raw is List) {
      final seen = <int>{};
      for (final m in raw) {
        if (m is! Map<String, dynamic>) continue;
        final movie = VodMovie.fromJson(m);
        if (movie.id == 0 || movie.name.isEmpty) continue;
        if (!seen.add(movie.id)) continue;
        movies.add(movie);
      }
    }
    return movies;
  }

  /// Filmin detaylarını yükler (açıklama, tanıtım görseli, IMDb puanı…).
  static Future<VodMovieDetails> loadVodMovieDetails(
    XtreamCredentials c,
    int movieId,
  ) async {
    final raw = await _api(c, 'get_vod_info&vod_id=$movieId');
    if (raw is! Map<String, dynamic>) return const VodMovieDetails();
    return VodMovieDetails.fromJson(raw);
  }

  /// Dizi listesini yükler.
  static Future<List<VodSeries>> loadSeries(XtreamCredentials c) async {
    final raw = await _apiLarge(c, 'get_series');
    final series = <VodSeries>[];
    if (raw is List) {
      final seen = <int>{};
      for (final s in raw) {
        if (s is! Map<String, dynamic>) continue;
        final show = VodSeries.fromJson(s);
        if (show.id == 0 || show.name.isEmpty) continue;
        if (!seen.add(show.id)) continue;
        series.add(show);
      }
    }
    return series;
  }

  /// Dizinin sezon/bölüm yapısını ve detaylarını yükler.
  static Future<SeriesInfo> loadSeriesInfo(
    XtreamCredentials c,
    int seriesId,
  ) async {
    final raw = await _api(c, 'get_series_info&series_id=$seriesId');
    if (raw is! Map<String, dynamic>) {
      return const SeriesInfo(seasons: []);
    }
    return SeriesInfo.fromJson(raw);
  }
}
