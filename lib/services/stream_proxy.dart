import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// HLS Live Stream Proxy — m3u8 manifest'lerini yeniden yazar
/// ve canlı yayınları kesintisiz hale getirir.
///
/// Canlı yayın sorunu: ExoPlayer live edge'e ulaştığında yeniden buffer'lama
/// yapar ve ~30sn'de bir donar.
///
/// Çözüm: Her m3u8 isteğinde son 2 segment'i çıkararak oyuncuyu
/// her zaman live edge'in 2 segment (≈10-15sn) gerisinde tutar.
class StreamProxy {
  static StreamProxy? _instance;
  static StreamProxy get instance => _instance ??= StreamProxy._();
  StreamProxy._();

  HttpServer? _server;
  int _port = 0;
  bool _running = false;

  // m3u8 cache — canlı yayınlar için
  final Map<String, _CachedManifest> _manifestCache = {};

  int get port => _port;
  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _running = true;
      _server!.listen(_handleRequest);
    } catch (_) { _running = false; }
  }

  Future<void> stop() async {
    _running = false;
    try { await _server?.close(force: true); } catch (_) {}
    _server = null;
    _port = 0;
    _manifestCache.clear();
  }

  String proxyUrl(String originalUrl) {
    final encoded = Uri.encodeComponent(originalUrl);
    return 'http://127.0.0.1:$_port/stream?u=$encoded';
  }

  void _handleRequest(HttpRequest request) async {
    final uri = request.uri;
    if (uri.path == '/stream') {
      final url = Uri.decodeComponent(uri.queryParameters['u'] ?? '');
      if (url.isEmpty) { request.response..statusCode = 400..close(); return; }
      await _handleStream(request, url);
    } else if (uri.path.startsWith('/segment/')) {
      final segmentUrl = Uri.decodeComponent(uri.path.substring('/segment/'.length));
      await _relaySegment(request, segmentUrl);
    } else {
      request.response..statusCode = 404..close();
    }
  }

  Future<void> _handleStream(HttpRequest request, String url) async {
    final response = request.response;
    try {
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36';
      final res = await client.send(req).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        response..statusCode = res.statusCode..close();
        return;
      }

      final contentType = res.headers['content-type'] ?? '';
      final body = await res.stream.bytesToString();
      client.close();

      final isHls = contentType.contains('mpegurl') ||
          contentType.contains('m3u8') ||
          url.endsWith('.m3u8') ||
          body.trimLeft().startsWith('#EXTM3U');

      if (isHls) {
        // m3u8 manifest — segment URL'lerini yeniden yaz + canlı yayın optimizasyonu
        final rewritten = _rewriteManifest(body, url);
        response.headers.contentType = ContentType.parse('application/vnd.apple.mpegurl');
        // Cache-control — oyuncu her zaman proxy'den çeksin
        response.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
        response..add(utf8.encode(rewritten))..close();
      } else {
        // Doğrudan akış (MPEG-TS) — relay et
        response.headers.contentType = ContentType.parse(contentType);
        response.add(utf8.encode(body));
        response.close();
      }
    } catch (e) {
      try { response..statusCode = 502..close(); } catch (_) {}
    }
  }

  String _rewriteManifest(String manifest, String baseUrl) {
    final baseUri = Uri.parse(baseUrl);
    final baseOrigin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ':${baseUri.port}' : ''}';
    final lines = manifest.split('\n');

    // Önce tüm satırları ayrıştır
    final List<String> result = [];
    final List<int> segmentIndices = []; // Segment satır endekslerini kaydet

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('#') || line.trim().isEmpty) {
        result.add(line);
      } else {
        // Segment URL'sini proxy'ye yönlendir
        String segUrl = line.trim();
        if (!segUrl.startsWith('http')) {
          segUrl = '$baseOrigin${segUrl.startsWith('/') ? '' : '/'}$segUrl';
        }
        final encoded = Uri.encodeComponent(segUrl);
        result.add('/segment/$encoded');
        segmentIndices.add(result.length - 1);
      }
    }

    // ═══════════════════════════════════════════════════════════════
    //  CANLI YAYIN OPTİMİZASYONU: Son 3 segment'i çıkar
    //  Böylece oyuncu her zaman live edge'in ≈10-15sn gerisinde olur
    //  ve periyodik yeniden buffer-lama yapmaz.
    // ═══════════════════════════════════════════════════════════════
    if (segmentIndices.length > 4) {
      final removeCount = segmentIndices.length > 8 ? 3 : 2;
      final startRemove = segmentIndices.length - removeCount;
      final indicesToRemove = segmentIndices.sublist(startRemove).toSet();
      final filtered = <String>[];
      for (int i = 0; i < result.length; i++) {
        if (!indicesToRemove.contains(i)) {
          filtered.add(result[i]);
        }
      }
      return filtered.join('\n');
    }

    return result.join('\n');
  }

  Future<void> _relaySegment(HttpRequest request, String url) async {
    final response = request.response;
    try {
      final client = http.Client();
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36';
      final res = await client.send(req).timeout(const Duration(seconds: 10));
      response.headers.contentType = ContentType.parse(res.headers['content-type'] ?? 'video/mp2t');
      await response.addStream(res.stream);
      client.close();
    } catch (_) {
      try { response..statusCode = 502..close(); } catch (_) {}
    }
  }
}

class _CachedManifest {
  final String content;
  final DateTime fetchedAt;
  _CachedManifest(this.content, this.fetchedAt);
}
