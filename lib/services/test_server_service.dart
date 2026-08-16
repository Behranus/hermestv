import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// İnternette halka açık Xtream test sunucusu.
class TestServer {
  TestServer({
    required this.name,
    required this.server,
    required this.username,
    required this.password,
    required this.description,
  });

  final String name;
  final String server;
  final String username;
  final String password;
  final String description;

  /// Son kontrol sonrası durum (yalnızca çalışma anında; kaydedilmez).
  bool working = false;
  int liveCount = 0;
  int vodCount = 0;
  DateTime? lastChecked;

  String get label =>
      '$name — $liveCount kategori${vodCount > 0 ? ', $vodCount film' : ''}';

  Map<String, dynamic> toJson() => {
        'name': name,
        'server': server,
        'username': username,
        'password': password,
        'description': description,
      };

  static TestServer? fromJson(Map<String, dynamic> json) {
    final s = json['server'] as String?;
    final u = json['username'] as String?;
    final p = json['password'] as String?;
    final n = json['name'] as String?;
    if (s == null || u == null || p == null || n == null) return null;
    return TestServer(
      name: n,
      server: s,
      username: u,
      password: p,
      description: (json['description'] as String?) ?? '',
    );
  }
}

/// Xtream test sunucu havuzu.
///
/// - **Günde bir kez otomatik yenilenir:** her sunucu `player_api.php` ile
///   canlı kontrol edilir (kimlik doğrulama + kategori/film sayıları).
/// - Ölü sunucular otomatik elenir; çalışanlar önbelleğe kaydedilir.
/// - Kullanıcı "Test Yayınları"na her bastığında zorlamalı taze kontrol yapılır.
class TestServerService {
  static const _lastCheckKey = 'test_server_last_check';
  static const _cacheKey = 'test_server_cache';
  static const _daily = Duration(hours: 24);
  static const _timeout = Duration(seconds: 12);

  /// Aday sunucular. İnternetten canlı doğrulanmış/çalışır durumda olanlar:
  /// - **Free TV Demo (iptv-org):** Render üzerinde barınan Xtream panel —
  ///   iptv-org'un yasal ücretsiz kanallarını sunar (1059+ kanal). Doğrulandı.
  /// - fast-sat: uzun süredir bilinen halka açık test hattı (ölürse otomatik elenir).
  static final seeds = <TestServer>[
    TestServer(
      name: 'Free TV Demo (iptv-org)',
      server: 'https://properiptv-review-panel.onrender.com',
      username: 'demo',
      password: 'demo',
      description: 'iptv-org kataloğundan yasal ücretsiz kanallar',
    ),
    TestServer(
      name: 'Xtream Test Hattı (fast-sat)',
      server: 'http://pro.test.fast-sat.tv:8080',
      username: 'test',
      password: 'test',
      description: 'Halka açık Xtream test hattı',
    ),
  ];

  /// Havuzu yeniler ve **çalışan** sunucuları döndürür (canlı sayısına göre sıralı).
  ///
  /// [force] true ise önbelleği atlayıp her sunucuyu taze kontrol eder
  /// (kullanıcı "Test Yayınları"na bastığında). false ise son kontrol 24 saat
  /// içindeyse önbelleği kullanır (uygulama açılışı — günlük yenileme).
  static Future<List<TestServer>> refresh({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final lastRaw = prefs.getString(_lastCheckKey);
      if (lastRaw != null) {
        final last = DateTime.tryParse(lastRaw);
        if (last != null && DateTime.now().difference(last) < _daily) {
          return await _loadCache();
        }
      }
    }

    final results = await Future.wait(seeds.map(_check));
    final working = results.where((s) => s.working).toList()
      ..sort((a, b) => b.liveCount.compareTo(a.liveCount));

    await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());
    await prefs.setString(
      _cacheKey,
      jsonEncode(working.map((s) => s.toJson()).toList()),
    );
    return working;
  }

  /// Sunucuyu `player_api.php` ile kontrol eder: kimlik doğrulama +
  /// canlı kategori sayısı + VOD (film) kategori sayısı.
  static Future<TestServer> _check(TestServer server) async {
    final base = server.server.replaceAll(RegExp(r'/+$'), '');
    final u = Uri.encodeQueryComponent(server.username);
    final p = Uri.encodeQueryComponent(server.password);

    Future<int> count(String action) async {
      try {
        final resp = await http
            .get(
              Uri.parse(
                '$base/player_api.php?username=$u&password=$p&action=$action',
              ),
              headers: {'User-Agent': 'IPTVPlayer/1.0'},
            )
            .timeout(_timeout);
        if (resp.statusCode != 200) return 0;
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        return data is List ? data.length : 0;
      } catch (_) {
        return 0;
      }
    }

    // Kimlik doğrulama: user_info içermeli.
    bool authOk = false;
    try {
      final resp = await http
          .get(
            Uri.parse('$base/player_api.php?username=$u&password=$p'),
            headers: {'User-Agent': 'IPTVPlayer/1.0'},
          )
          .timeout(_timeout);
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final info = data is Map ? data['user_info'] : null;
        authOk = info is Map && (info['auth'] == 1 || info['auth'] == '1');
      }
    } catch (_) {
      authOk = false;
    }

    server.working = authOk;
    server.lastChecked = DateTime.now();
    if (authOk) {
      server.liveCount = await count('get_live_categories');
      server.vodCount = await count('get_vod_categories');
    }
    return server;
  }

  static Future<List<TestServer>> _loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      final servers = list
          .whereType<Map<String, dynamic>>()
          .map(TestServer.fromJson)
          .whereType<TestServer>()
          .toList();
      return servers..sort((a, b) => b.liveCount.compareTo(a.liveCount));
    } catch (_) {
      return [];
    }
  }
}
