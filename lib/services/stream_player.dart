import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:fvp/fvp.dart';
import 'package:video_player/video_player.dart' as vp;

/// Altyazı parçası bilgisi (oynatıcıdan bağımsız).
class SubtitleInfo {
  const SubtitleInfo({required this.id, required this.title, this.language});

  final String id;
  final String title;
  final String? language;
}

/// Oynatıcı motoru soyutlaması.
///
/// Android'de motor **fvp (libmdk)** — video_player API'si üzerinden.
/// - Donanım hızlandırmalı MediaCodec (varsayılan açık)
/// - Box sürümünde **tunnel modu**: decoder doğrudan surface'a çıkar
///   (OpenGL kopyası yok) → Full HD/2K/4K zayıf GPU'da bile akıcı
/// - `setBufferRange` ile hızlı kanal geçişi (küçük tampon, canlıda kare atma)
///
/// iOS/Linux hedeflenmediği için ikinci bir motor (mpv) yoktur.
abstract class StreamPlayer {
  Stream<bool> get buffering;
  Stream<String> get error;
  Stream<bool> get playing;
  Stream<double> get volume;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get completed;
  Stream<List<SubtitleInfo>> get subtitleTracks;

  /// Akış canlı mı? (biliniyorsa; bilinmiyorsa null → ekran süre tahminini kullanır)
  bool? get isLive;

  /// Açılan akışın çözünürlük/kodlayıcı bilgisi (HUD için, örn. "1920×1080 • h264").
  String? get streamInfo;

  /// Oynatıcının seçtiği tampon süresi (saniye). Küçük = hızlı kanal geçişi.
  double get bufferSecs;
  set bufferSecs(double value);

  Widget buildVideo({BoxFit fit = BoxFit.contain});

  /// [url]'i açar. [subtitleUrl] varsa harici altyazı olarak yüklenir.
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    String? subtitleUrl,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double v);

  /// Harici altyazı dosyası/URL'si yükle.
  Future<void> setExternalSubtitle(String uri);

  /// Altyazıyı kapat.
  Future<void> disableSubtitles();

  /// Yerleşik (akış içi) altyazı parçasını seç.
  Future<void> setSubtitleTrackById(String id);

  Future<void> dispose();
}

/// fvp (libmdk) tabanlı oynatıcı — Android Box/telefon/TV.
StreamPlayer createStreamPlayer({double bufferSecs = 1.0}) {
  return FvpStreamPlayer(bufferSecs: bufferSecs);
}

class FvpStreamPlayer extends StreamPlayer {
  FvpStreamPlayer({required this.bufferSecs});

  vp.VideoPlayerController? _controller;
  int _generation = 0;
  bool _disposed = false;
  double _pendingVolume = 1.0;
  bool? _live;
  String? _lastError;
  String? _streamInfo;
  bool _startedPlaying = false;

  final _buffering = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _volume = StreamController<double>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _subtitleTracks = StreamController<List<SubtitleInfo>>.broadcast();

  DateTime _lastPositionEmit = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Stream<bool> get buffering => _buffering.stream;
  @override
  Stream<String> get error => _error.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<double> get volume => _volume.stream;
  @override
  Stream<Duration> get position => _position.stream;
  @override
  Stream<Duration> get duration => _duration.stream;
  @override
  Stream<bool> get completed => _completed.stream;
  @override
  Stream<List<SubtitleInfo>> get subtitleTracks => _subtitleTracks.stream;
  @override
  bool? get isLive => _live;
  @override
  String? get streamInfo => _streamInfo;

  @override
  double bufferSecs;

  /// Sadece EKRANDAKİ oynatıcının olaylarını işler. Bekleyen/eski oynatıcıların
  /// olayları (özellikle hata) görmezden gelinir → hızlı kanal değişiminde
  /// eski akışın hatası yeni akışı kesmez.
  void _onValueChanged(vp.VideoPlayerController src) {
    final c = _controller;
    if (c == null || _disposed) return;
    if (!identical(src, c)) return;
    final v = c.value;
    if (v.hasError && v.errorDescription != null && v.errorDescription != _lastError) {
      _lastError = v.errorDescription;
      _error.add(v.errorDescription!);
    }
    // Oynatma ilk başladığında tampon göstergesini kapat (mdk isBuffering
    // canlıda asılı kalabilir → sonsuz "Kanal yükleniyor" olmasın).
    if (v.isPlaying && !_startedPlaying) {
      _startedPlaying = true;
      _buffering.add(false);
      _captureStreamInfo(c);
    }
    if (!v.isPlaying) {
      _buffering.add(v.isBuffering);
    }
    _playing.add(v.isPlaying);
    _volume.add(v.volume);
    final now = DateTime.now();
    if (now.difference(_lastPositionEmit) >= const Duration(milliseconds: 250)) {
      _lastPositionEmit = now;
      _position.add(v.position);
    }
    _duration.add(v.duration);
    if (v.isCompleted) _completed.add(true);
  }

  void _captureStreamInfo(vp.VideoPlayerController c) {
    if (_streamInfo != null) return;
    try {
      final info = c.getMediaInfo();
      final vids = info?.video;
      if (vids != null && vids.isNotEmpty) {
        final codec = vids.first.codec;
        final res = '${codec.width}×${codec.height}';
        final fps = codec.frameRate > 0 ? ' • ${codec.frameRate} fps' : '';
        _streamInfo = '$res • ${codec.codec}$fps';
      }
    } catch (_) {
      // Yayın bilgisi alınamazsa sessizce geç.
    }
  }

  @override
  Future<void> open(
    String url, {
    Map<String, String>? headers,
    String? subtitleUrl,
  }) async {
    final gen = ++_generation;
    _live = null;
    _lastError = null;
    _streamInfo = null;
    _startedPlaying = false;
    _buffering.add(true);
    _position.add(Duration.zero);
    _duration.add(Duration.zero);

    // Eski oynatıcının sesini kes ama SON KARESİNİ ekranda tut: yeni akış
    // hazır olana dek siyah ekran görünmez (hızlı kanal geçişi hissi).
    // dispose'u BEKLEMEYİZ — eski oynatıcının kapanması yeni kanalın
    // yüklenmesini engellememeli (gecikmenin gizli kaynağı buydu).
    final old = _controller;
    if (old != null) {
      try {
        unawaited(old.pause());
      } catch (_) {}
    }

    final c = vp.VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers ?? const <String, String>{},
    );
    c.addListener(() => _onValueChanged(c));

    try {
      await c.initialize().timeout(const Duration(seconds: 20));
    } catch (e) {
      if (gen != _generation || _disposed) {
        unawaited(c.dispose());
        return;
      }
      _error.add('Akış açılamadı: $e');
      return;
    }
    if (gen != _generation || _disposed) {
      unawaited(c.dispose());
      return;
    }

    // Yeni akış hazır → ekrandaki oynatıcıyı değiştir; eskiyi serbest bırak.
    _controller = c;
    if (old != null) {
      unawaited(old.dispose());
    }

    // Canlı mı? (mdk tespiti) — tampon aralığını ona göre seç.
    bool live;
    try {
      live = c.isLive() || c.value.duration == Duration.zero;
    } catch (_) {
      live = c.value.duration == Duration.zero;
    }
    _live = live;

    // Tampon aralığı — 2GB RAM'li giriş seviyesi Box'lar için ayarlandı:
    // - drop: false → ağ kısa kesilse bile KARE ATILMAZ (kare atma = görünür
    //   kasma). Tampon maksimuma ulaşınca demuxer bekler, yayın doğal olarak
    //   güncel kalır; küçük gecikme pahasına akıcılık kazanılır.
    // - min 1.2 sn → ağ dalgalanmasına dayanıklı; çok küçük değer sürekli
    //   yeniden tamponlama döngüsüne (donma hissi) yol açar.
    try {
      if (live) {
        final maxMs = bufferSecs <= 0.5
            ? 4000
            : bufferSecs <= 1.0
                ? 6000
                : bufferSecs <= 2.0
                    ? 8000
                    : 12000;
        c.setBufferRange(min: 1200, max: maxMs, drop: false);
      } else {
        c.setBufferRange(min: 2000, max: 12000, drop: false);
      }
    } catch (_) {
      // Tampon ayarı yapılamazsa varsayılanlarla devam et.
    }

    // Harici altyazı (kanaldan tanımlıysa).
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      try {
        c.setExternalSubtitle(subtitleUrl);
      } catch (_) {}
    }

    // Kayıtlı ses seviyesini uygula.
    try {
      await c.setVolume(_pendingVolume);
    } catch (_) {}

    try {
      await c.play();
    } catch (_) {}
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return vp.VideoPlayer(c);
  }

  @override
  Future<void> play() async {
    try {
      await _controller?.play();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _controller?.pause();
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _controller?.seekTo(position);
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double v) async {
    _pendingVolume = v.clamp(0.0, 1.0);
    try {
      await _controller?.setVolume(_pendingVolume);
    } catch (_) {}
  }

  @override
  Future<void> setExternalSubtitle(String uri) async {
    try {
      _controller?.setExternalSubtitle(uri);
    } catch (_) {}
  }

  @override
  Future<void> disableSubtitles() async {
    try {
      _controller?.setSubtitleTracks(const []);
    } catch (_) {}
  }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    // Yerleşik parça listesi video_player API'sinde yok; harici altyazı kullanılır.
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    final c = _controller;
    _controller = null;
    if (c != null) {
      try {
        await c.dispose();
      } catch (_) {}
    }
    await _buffering.close();
    await _error.close();
    await _playing.close();
    await _volume.close();
    await _position.close();
    await _duration.close();
    await _completed.close();
    await _subtitleTracks.close();
  }
}
