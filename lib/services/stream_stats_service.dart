import 'dart:async';
import 'dart:io';

/// Basit ağ istatistikleri servisi — FPS, bant genişliği, gecikme tahmini.
/// Kanal oynatılırken periyodik olarak URL'ye HEAD isteği atarak gecikme ölçer.
class StreamStatsService {
  Timer? _timer;
  final _statsController = StreamController<StreamStats>.broadcast();

  Stream<StreamStats> get stats => _statsController.stream;

  double _latency = 0;
  int _bytesPerSecond = 0;
  double _estimatedFps = 30;

  void start(String url) {
    stop();

    // Her 3 saniyede bir kontrol et
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check(url));

    // İlk ölçümü hemen yap
    _check(url);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check(String url) async {
    try {
      // Gecikme ölçümü
      final sw = Stopwatch()..start();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.headUrl(Uri.parse(url));
      request.headers.set('Connection', 'close');
      final response = await request.close();
      sw.stop();
      _latency = sw.elapsedMilliseconds.toDouble();
      _bytesPerSecond = response.contentLength ?? 0;
      response.drain();
      client.close();
    } catch (_) {
      // Gecikme ölçümü başarısız — sonucu koru
    }

    if (!_statsController.isClosed) {
      _statsController.add(StreamStats(
        latencyMs: _latency,
        bandwidthBps: _bytesPerSecond,
        estimatedFps: _estimatedFps,
      ));
    }
  }

  /// Manuel FPS tahmini güncelle ( video_player value.size değişiminden).
  void updateFps(double fps) {
    _estimatedFps = fps;
  }

  void dispose() {
    stop();
    _statsController.close();
  }
}

class StreamStats {
  final double latencyMs;
  final int bandwidthBps;
  final double estimatedFps;

  const StreamStats({
    required this.latencyMs,
    required this.bandwidthBps,
    required this.estimatedFps,
  });

  String get latencyDisplay => '${latencyMs.round()} ms';

  String get bandwidthDisplay {
    if (bandwidthBps > 1024 * 1024) {
      return '${(bandwidthBps / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bandwidthBps > 1024) {
      return '${(bandwidthBps / 1024).toStringAsFixed(0)} KB/s';
    }
    return '$bandwidthBps B/s';
  }

  String get fpsDisplay => '${estimatedFps.round()} FPS';

  /// Kalite seviyesi: düşük, orta, iyi
  String get qualityLevel {
    if (latencyMs < 100) return 'Mükemmel';
    if (latencyMs < 300) return 'İyi';
    if (latencyMs < 800) return 'Orta';
    return 'Düşük';
  }
}
