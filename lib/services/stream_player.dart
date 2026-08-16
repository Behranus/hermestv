import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

/// Altyazı parçası bilgisi (oynatıcıdan bağımsız).
class SubtitleInfo {
  const SubtitleInfo({required this.id, required this.title, this.language});

  final String id;
  final String title;
  final String? language;
}

/// Oynatıcı motoru soyutlaması.
///
/// Motor **resmi video_player eklentisi (Android'de ExoPlayer)** — IPTV
/// dünyasında fiilen standart olan, en çok test edilmiş ve en kararlı motor.
/// TiviMate, IBO Player, Smarters, OTT Navigator — hepsi ExoPlayer tabanlıdır.
///
/// Neden ExoPlayer?
/// - Donanım hızlandırmalı MediaCodec (otomatik), 4K/2K/FHD akıcı
/// - Tampon yönetimi ExoPlayer'a ait → önceki motorun "3x hızda oynayıp
///   kapanma" ve VOD açmama gibi canlı/VOD tampon hataları yok
/// - HLS canlı + MP4/HLS VOD: endüstri standardı, çok kararlı
///
/// Altyazı: video_player harici altyazı dosyası desteklemediği için
/// SRT/VTT parser'ı burada Flutter içinde çalışır; metin [subtitleText]
/// akışıyla ekrana çizilir.
abstract class StreamPlayer {
  Stream<bool> get buffering;
  Stream<String> get error;
  Stream<bool> get playing;
  Stream<double> get volume;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get completed;
  Stream<List<SubtitleInfo>> get subtitleTracks;

  /// Şu an gösterilecek altyazı metni (null = altyazı yok).
  Stream<String?> get subtitleText;

  /// Akış canlı mı? (biliniyorsa; bilinmiyorsa null → ekran süre tahminini kullanır)
  bool? get isLive;

  /// Açılan akışın çözünürlük bilgisi (HUD için, örn. "1920×1080").
  String? get streamInfo;

  /// Oynatıcının seçtiği tampon süresi (saniye). ExoPlayer tamponu kendisi
  /// yönetir; bu değer yalnızca bilgi amaçlıdır (küçük = hızlı kanal geçişi).
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

  /// Harici altyazı dosyası/URL'si yükle (SRT/VTT — http, https veya file://).
  Future<void> setExternalSubtitle(String uri);

  /// Altyazıyı kapat.
  Future<void> disableSubtitles();

  /// Yerleşik (akış içi) altyazı parçasını seç.
  Future<void> setSubtitleTrackById(String id);

  Future<void> dispose();
}

/// video_player (ExoPlayer) tabanlı oynatıcı — Android Box/telefon/TV.
StreamPlayer createStreamPlayer({double bufferSecs = 1.0}) {
  return ExoStreamPlayer(bufferSecs: bufferSecs);
}

class ExoStreamPlayer extends StreamPlayer {
  ExoStreamPlayer({required this.bufferSecs});

  VideoPlayerController? _controller;
  int _generation = 0;
  bool _disposed = false;
  double _pendingVolume = 1.0;
  bool? _live;
  String? _lastError;
  String? _streamInfo;
  bool _startedPlaying = false;

  // ---- Altyazı durumu ----
  List<_SubCue> _cues = const [];
  String? _activeSubtitle;

  final _buffering = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _volume = StreamController<double>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _subtitleTracks = StreamController<List<SubtitleInfo>>.broadcast();
  final _subtitleText = StreamController<String?>.broadcast();

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
  Stream<String?> get subtitleText => _subtitleText.stream;
  @override
  bool? get isLive => _live;
  @override
  String? get streamInfo => _streamInfo;

  @override
  double bufferSecs;

  /// Sadece EKRANDAKİ oynatıcının olaylarını işler. Bekleyen/eski oynatıcıların
  /// olayları (özellikle hata) görmezden gelinir → hızlı kanal değişiminde
  /// eski akışın hatası yeni akışı kesmez.
  void _onValueChanged(VideoPlayerController src) {
    final c = _controller;
    if (c == null || _disposed) return;
    if (!identical(src, c)) return;
    final v = c.value;
    if (v.hasError &&
        v.errorDescription != null &&
        v.errorDescription != _lastError) {
      _lastError = v.errorDescription;
      _error.add(v.errorDescription!);
    }
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
      _updateSubtitleAt(v.position);
    }
    _duration.add(v.duration);
    if (v.isCompleted) _completed.add(true);
  }

  void _captureStreamInfo(VideoPlayerController c) {
    if (_streamInfo != null) return;
    final size = c.value.size;
    if (size.width > 0 && size.height > 0) {
      _streamInfo = '${size.width.round()}×${size.height.round()}';
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
    _cues = const [];
    _activeSubtitle = null;
    _subtitleText.add(null);
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

    // Doğrulama (ChannelProbeService) ile aynı User-Agent → doğrulanan
    // kanallar oynatıcıda da aynı şekilde açılır (bazı CDN'ler UA ister).
    final c = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers ??
          const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
                'Chrome/120.0 Mobile Safari/537.36',
          },
    );
    c.addListener(() => _onValueChanged(c));

    try {
      await c.initialize().timeout(const Duration(seconds: 20));
    } catch (e) {
      // Kontrolcüyü serbest bırak (kaynak sızıntısı olmasın) ve hatayı bildir.
      unawaited(c.dispose());
      if (gen != _generation || _disposed) return;
      _lastError = 'Akış açılamadı: $e';
      _error.add(_lastError!);
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

    // Canlı tespiti: canlı akışlar genellikle süre bildirmez (0).
    _live = c.value.duration == Duration.zero;

    // Harici altyazı (kanaldan tanımlıysa).
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      await setExternalSubtitle(subtitleUrl);
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
    return VideoPlayer(c);
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

  // ---- Altyazı ----

  @override
  Future<void> setExternalSubtitle(String uri) async {
    try {
      final raw = await _fetchSubtitle(uri);
      if (raw == null) return;
      _cues = _parseSubtitles(raw);
      _activeSubtitle = null;
      final c = _controller;
      if (c != null) {
        _updateSubtitleAt(c.value.position);
      }
    } catch (_) {
      // Altyazı yüklenemezse sessizce geç — oynatma etkilenmez.
    }
  }

  @override
  Future<void> disableSubtitles() async {
    _cues = const [];
    _activeSubtitle = null;
    _subtitleText.add(null);
  }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    // video_player yerleşik parça API'si sunmaz; yalnızca harici desteklenir.
  }

  Future<String?> _fetchSubtitle(String uri) async {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      final resp = await http
          .get(Uri.parse(uri), headers: const {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
                    'Chrome/120.0 Mobile Safari/537.36',
          })
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        // UTF-8; BOM varsa temizle.
        var body = resp.body;
        if (body.startsWith('\uFEFF')) body = body.substring(1);
        return body;
      }
      return null;
    }
    if (uri.startsWith('file://')) {
      final path = uri.replaceFirst('file://', '');
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }
    }
    return null;
  }

  void _updateSubtitleAt(Duration position) {
    if (_cues.isEmpty) return;
    String? text;
    for (final cue in _cues) {
      if (position >= cue.start && position <= cue.end) {
        text = cue.text;
        break;
      }
    }
    if (text != _activeSubtitle) {
      _activeSubtitle = text;
      _subtitleText.add(text);
    }
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
    await _subtitleText.close();
  }
}

// ---- SRT / VTT ayrıştırıcı ----

/// Bir altyazı parçası (zaman aralığı + metin).
class SubtitleCue {
  const SubtitleCue(this.start, this.end, this.text);

  final Duration start;
  final Duration end;
  final String text;
}

class _SubCue {
  const _SubCue(this.start, this.end, this.text);

  final Duration start;
  final Duration end;
  final String text;
}

/// SRT ("00:00:01,000 --> 00:00:04,000") ve WebVTT (nokta ayracı, opsiyonel
/// satır başlığı) formatlarını destekler.
List<SubtitleCue> parseSubtitleCues(String raw) {
  return _parseSubtitles(raw)
      .map((c) => SubtitleCue(c.start, c.end, c.text))
      .toList(growable: false);
}

List<_SubCue> _parseSubtitles(String raw) {
  final lines = raw
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final cues = <_SubCue>[];
  final re = RegExp(
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*'
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
  );
  for (var i = 0; i < lines.length; i++) {
    final m = re.firstMatch(lines[i]);
    if (m == null) continue;
    final start = _cueTime(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!);
    final end = _cueTime(m.group(5)!, m.group(6)!, m.group(7)!, m.group(8)!);
    final textLines = <String>[];
    i++;
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      textLines.add(lines[i].trim());
      i++;
    }
    if (textLines.isNotEmpty) {
      cues.add(_SubCue(start, end, textLines.join('\n')));
    }
  }
  return cues;
}

Duration _cueTime(String h, String m, String s, String ms) {
  var millis = ms.padRight(3, '0');
  if (millis.length > 3) millis = millis.substring(0, 3);
  return Duration(
    hours: int.parse(h),
    minutes: int.parse(m),
    seconds: int.parse(s),
    milliseconds: int.parse(millis),
  );
}
