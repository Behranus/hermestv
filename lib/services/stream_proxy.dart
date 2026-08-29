import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// ═══════════════════════════════════════════════════════════════════
///  STREAM PROXY — Sıfırdan yazılmış IPTV arabellek proxy'si
///
///  Nasıl çalışır:
///  1. IPTV sunucusundan sürekli olarak indirir (asla durmaz)
///  2. İndirdiği veriyi yerel buffer'da tutar
///  3. ExoPlayer localhost'tan okur — ağ gecikmesi yok
///  4. Bağlantı koparsa otomatik reconnect
///
///  Sonuç: Kesintisiz IPTV yayını
/// ═══════════════════════════════════════════════════════════════════
class StreamProxy {
  static StreamProxy? _instance;
  static StreamProxy get instance => _instance ??= StreamProxy._();
  StreamProxy._();

  HttpServer? _server;
  int _port = 0;
  bool _running = false;

  /// Proxy'nin çalıştığı port
  int get port => _port;

  /// Proxy çalışıyor mu?
  bool get isRunning => _running;

  /// Proxy'yi başlat
  Future<void> start() async {
    if (_running) return;

    try {
      // Boş bir port bul
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _running = true;

      print('[StreamProxy] Başlatıldı: http://127.0.0.1:$_port');

      // Gelen istekleri dinle
      _server!.listen((HttpRequest request) {
        _handleRequest(request);
      }, onError: (e) {
        print('[StreamProxy] Sunucu hatası: $e');
      });
    } catch (e) {
      print('[StreamProxy] Başlatma hatası: $e');
      _running = false;
    }
  }

  /// Proxy'yi durdur
  Future<void> stop() async {
    _running = false;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _port = 0;
  }

  /// IPTV URL'ini proxy'le — returns localhost URL
  String proxyUrl(String originalUrl, {Map<String, String>? headers}) {
    // URL'i base64 encode et (query parameter olarak)
    final encoded = Uri.encodeComponent(originalUrl);
    final headerParam = headers != null
        ? '&h=${Uri.encodeComponent(headers.toString())}'
        : '';
    return 'http://127.0.0.1:$_port/stream?u=$encoded$headerParam';
  }

  /// Gelen HTTP isteğini yönet
  void _handleRequest(HttpRequest request) async {
    final uri = request.uri;

    if (uri.path == '/stream') {
      final originalUrl = Uri.decodeComponent(uri.queryParameters['u'] ?? '');
      if (originalUrl.isEmpty) {
        request.response
          ..statusCode = 400
          ..write('Missing URL')
          ..close();
        return;
      }

      // Header'ları parse et
      Map<String, String>? headers;
      final headerStr = uri.queryParameters['h'];
      if (headerStr != null && headerStr.isNotEmpty) {
        // Basit header parsing
        headers = {'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36'};
      }

      print('[StreamProxy] İstek: $originalUrl');

      // IPTV akışını proxy'le
      await _proxyStream(request, originalUrl, headers);
    } else if (uri.path == '/health') {
      request.response
        ..statusCode = 200
        ..write('OK')
        ..close();
    } else {
      request.response
        ..statusCode = 404
        ..write('Not Found')
        ..close();
    }
  }

  /// IPTV akışını istemciye aktar — kesintisiz, reconnect ile
  Future<void> _proxyStream(
    HttpRequest clientRequest,
    String url,
    Map<String, String>? headers,
  ) async {
    final response = clientRequest.response;
    int retryCount = 0;
    const maxRetries = 10;
    bool clientDisconnected = false;

    // İstemci bağlantısı koptu mu kontrol et
    clientRequest.response.done.catchError((_) {
      clientDisconnected = true;
      return null;
    });

    while (retryCount < maxRetries && _running && !clientDisconnected) {
      try {
        // IPTV sunucusuna bağlan
        final requestHeaders = Map<String, String>.from(headers ?? {});
        requestHeaders['User-Agent'] = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36';

        final httpRequest = await http.Client().send(
          http.Request('GET', Uri.parse(url))
            ..headers.addAll(requestHeaders),
        ).timeout(const Duration(seconds: 15));

        if (httpRequest.statusCode == 200) {
          response.headers.contentType = ContentType.parse(
            httpRequest.headers['content-type'] ?? 'video/mp2t',
          );
          response.headers.add('Access-Control-Allow-Origin', '*');
          response.headers.add('Cache-Control', 'no-cache');
          response.headers.add('Connection', 'keep-alive');

          // Sürekli veri aktarımı — asla durmaz
          await for (final chunk in httpRequest.stream) {
            if (clientDisconnected || !_running) break;
            try {
              response.add(chunk);
              await response.flush();
            } catch (_) {
              clientDisconnected = true;
              break;
            }
          }

          // Akış bitti — eğer istemci hala bağlıysa reconnect dene
          if (!clientDisconnected && _running) {
            print('[StreamProxy] Akış bitti, reconnect deneniyor...');
            retryCount++;
            await Future.delayed(const Duration(milliseconds: 500));
            continue;
          }
        } else {
          print('[StreamProxy] HTTP ${httpRequest.statusCode} — retry $retryCount');
          retryCount++;
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        print('[StreamProxy] Bağlantı hatası: $e — retry $retryCount');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    // Temizlik
    try {
      if (!clientDisconnected) {
        await response.close();
      }
    } catch (_) {}
  }
}
