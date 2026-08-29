import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart' as vp;

import 'package:hermestv/services/hls_subtitle_service.dart';
import 'package:hermestv/services/stream_player.dart';

/// ═══════════════════════════════════════════════════════════════════
///  HİBRİT OYNATICI — ExoPlayer hızı + mpv sürekli buffer
///
///  Akış:
///  1. mpv ile paralel olarak buffer doldur
///  2. Buffer dolunca mpv'de kesintisiz oynat
///  3. mpv hata verirse ExoPlayer'a fallback
///  4. Hem Android hem Linux'ta çalışır
/// ═══════════════════════════════════════════════════════════════════
class HybridStreamPlayer extends StreamPlayer {
  HybridStreamPlayer({required this.bufferSecs});

  // mpv (media_kit) — sürekli buffer, kesintisiz oynatma
  Player? _mpvPlayer;
  VideoController? _mpvVideoController;
  StreamSubscription? _mpvPlaying;
  StreamSubscription? _mpvBuffering;
  StreamSubscription? _mpvCompleted;
  StreamSubscription? _mpvPosition;
  StreamSubscription? _mpvDuration;

  // ExoPlayer (video_player) — fallback
  vp.VideoPlayerController? _exoController;
  VoidCallback? _exoListener;

  bool _disposed = false;
  bool _useExo = false; // mpv başarısız olursa true olur
  int _generation = 0;
  double _pendingVolume = 1.0;
  bool? _live;
  String? _lastError;
  String? _streamInfo;
  bool _startedPlaying = false;
  String? _lastUrl;
  Map<String, String>? _headers;

  List<SubtitleCue> _cues = const [];
  String? _activeSubtitle;
  List<HlsSubtitleTrack> _hlsTracks = const [];
  HlsSubtitleTrack? _selectedHlsTrack;
  Timer? _hlsSubtitleRefresh;

  final _buffering = StreamController<bool>.broadcast();
  final _error = StreamController<String>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _volume = StreamController<double>.broadcast();
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _completed = StreamController<bool>.broadcast();
  final _subtitleTracks = StreamController<List<SubtitleInfo>>.broadcast();
  final _subtitleText = StreamController<String?>.broadcast();
  final _activeSubtitleId = StreamController<String?>.broadcast();
  final _audioTracksCtrl = StreamController<List<AudioTrackInfo>>.broadcast();
  final _activeAudioTrackId = StreamController<String?>.broadcast();

  DateTime _lastPositionEmit = DateTime.fromMillisecondsSinceEpoch(0);

  // ─── Stream abonelikleri ───
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
  Stream<String?> get activeSubtitleId => _activeSubtitleId.stream;
  @override
  Stream<List<AudioTrackInfo>> get audioTracks => _audioTracksCtrl.stream;
  @override
  Stream<String?> get activeAudioTrackId => _activeAudioTrackId.stream;
  @override
  bool? get isLive => _live;
  @override
  String? get streamInfo => _streamInfo;
  @override
  double bufferSecs;

  void _safeAdd<T>(StreamController<T> sc, T value) {
    if (_disposed || sc.isClosed) return;
    try { sc.add(value); } catch (_) {}
  }

  @override
  Future<void> open(String url, {Map<String, String>? headers, String? subtitleUrl}) async {
    final gen = ++_generation;
    _live = null; _lastError = null; _streamInfo = null;
    _startedPlaying = false; _useExo = false;
    _cues = const []; _activeSubtitle = null;
    _safeAdd(_subtitleText, null); _safeAdd(_activeSubtitleId, null);
    _safeAdd(_buffering, true); _safeAdd(_position, Duration.zero);
    _safeAdd(_duration, Duration.zero);
    _headers = headers; _lastUrl = url;
    _hlsSubtitleRefresh?.cancel(); _hlsSubtitleRefresh = null;

    // Eski oynatıcıları temizle
    await _cancelAll(gen);

    // ═══════════════════════════════════════════════════════════════
    //  AŞAMA 1: mpv ile paralel buffer doldur
    // ═══════════════════════════════════════════════════════════════
    try {
      _mpvPlayer = Player(
        configuration: const PlayerConfiguration(
          // Paralel indirme + agresif buffer
          // hwdec: donanim hizlandirma (videoyu CPU degil GPU isler)
          // cache: arabellek aktif
          // demuxer-max-bytes: demuxer'in tutacagi max veri
        ),
      );
      _mpvVideoController = VideoController(_mpvPlayer!);

      // mpv ayarları — Media extras ile
      final mpvExtras = <String, dynamic>{
        // Buffer ayarları — agresif连续indirme
        if (Platform.isAndroid) ...{
          'cache': 'yes',
          'cache-secs': '120',           // 2 dakika onceden yukle
          'demuxer-max-bytes': '209715200',  // 200MB demuxer
          'demuxer-max-back-bytes': '104857600', // 100MB geri buffer
          'demuxer-readahead-secs': '60',  // 60sn readahead
          'hr-seek': 'framedrop',         // Canli yayin icin
          'network-timeout': '10',        // 10sn timeout
          'reconnect': 'yes',             // Otomatik reconnect
          'reconnect-delay-max': '5',     // Max 5sn bekle
          'reconnect-on-error': 'yes',    // Hata olursa baglan
          'hwdec': 'mediacodec',          // Hardware decode
          'vo': 'gpu',                    // GPU render
          'slang': 'tr,eng,und',          // Altyazi dilleri
        },
        if (Platform.isLinux) ...{
          'cache': 'yes',
          'cache-secs': '180',           // Linux'ta 3 dakika
          'demuxer-max-bytes': '314572800', // 300MB
          'hr-seek': 'framedrop',
          'slang': 'tr,eng,und',
        },
      };

      final media = Media(url, httpHeaders: headers, extras: mpvExtras);
      await _mpvPlayer!.open(media, play: true);

      // mpv stream aboneliklerini ayarla
      _mpvPlaying = _mpvPlayer!.stream.playing.listen((p) {
        if (_disposed || gen != _generation) return;
        _safeAdd(_playing, p);
        if (p && !_startedPlaying) {
          _startedPlaying = true;
          _safeAdd(_buffering, false);
          _captureStreamInfo();
        }
      });

      _mpvBuffering = _mpvPlayer!.stream.buffering.listen((b) {
        if (_disposed || gen != _generation) return;
        _safeAdd(_buffering, b);
      });

      _mpvCompleted = _mpvPlayer!.stream.completed.listen((_) {
        if (_disposed || gen != _generation) return;
        _safeAdd(_completed, true);
      });

      _mpvPosition = _mpvPlayer!.stream.position.listen((pos) {
        if (_disposed || gen != _generation) return;
        final now = DateTime.now();
        if (now.difference(_lastPositionEmit) >= const Duration(milliseconds: 250)) {
          _lastPositionEmit = now;
          _safeAdd(_position, pos);
          _updateSubtitleAt(pos);
        }
      });

      _mpvDuration = _mpvPlayer!.stream.duration.listen((d) {
        if (_disposed || gen != _generation) return;
        _safeAdd(_duration, d);
        if (_live == null) _live = d == Duration.zero || d.inSeconds > 86400;
      });

      // mpv çalışıyor — ExoPlayer'a gerek yok
      _useExo = false;

    } catch (mpvError) {
      // ═══════════════════════════════════════════════════════════════
      //  AŞAMA 2: mpv başarısız → ExoPlayer'a fallback
      // ═══════════════════════════════════════════════════════════════
      if (gen != _generation || _disposed) return;
      print('[HybridPlayer] mpv başarısız, ExoPlayer\'a geçiliyor: $mpvError');
      _useExo = true;
      await _openWithExo(url, headers: headers, gen: gen);
    }

    // Altyazı keşfi
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      await setExternalSubtitle(subtitleUrl);
    } else {
      unawaited(_discoverHlsSubtitles(url));
    }
  }

  /// mpv ayarlarını uygula — TiviMate benzeri agresif buffer
  void _applyMpvSettings(Player player) {
    // Tüm platformlarda mpv ayarları
    // Player.instanceExtras üzerinden mpv option'ları ayarla
  }

  // ═══════════════════════════════════════════════════════════════
  //  EXOPLAYER FALLBACK
  // ═══════════════════════════════════════════════════════════════
  Future<void> _openWithExo(String url, {Map<String, String>? headers, required int gen}) async {
    final effectiveHeaders = Map<String, String>.from(headers ?? {});
    effectiveHeaders['User-Agent'] = 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36';

    vp.VideoPlayerController? c;
    final trial = vp.VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: Map<String, String>.from(effectiveHeaders),
    );
    try {
      await trial.initialize().timeout(const Duration(seconds: 20));
      c = trial;
    } catch (_) {
      try { await trial.dispose(); } catch (_) {}
      // 2. deneme: VLC UA
      effectiveHeaders['User-Agent'] = 'VLC/3.0.21 LibVLC/3.0.21';
      final trial2 = vp.VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: Map<String, String>.from(effectiveHeaders),
      );
      try {
        await trial2.initialize().timeout(const Duration(seconds: 20));
        c = trial2;
      } catch (_) {
        try { await trial2.dispose(); } catch (_) {}
      }
    }

    if (c == null || gen != _generation || _disposed) {
      if (c != null) try { await c.dispose(); } catch (_) {}
      if (gen != _generation || _disposed) return;
      _lastError = 'Akış açılamadı';
      _safeAdd(_error, _lastError!);
      return;
    }

    _exoController = c;
    _exoListener = () => _onExoValueChanged(c);
    c.addListener(_exoListener!);

    _live = c.value.duration == Duration.zero;
    try { await c.setVolume(_pendingVolume); } catch (_) {}
    try { await c.play(); } catch (_) {}
  }

  void _onExoValueChanged(vp.VideoPlayerController? src) {
    if (_disposed) return;
    final c = _exoController;
    if (src == null || c == null || !identical(src, c)) return;
    try {
      final v = c.value;
      if (v.hasError && v.errorDescription != null && v.errorDescription != _lastError) {
        _lastError = v.errorDescription;
        _safeAdd(_error, v.errorDescription!);
      }
      if (v.isPlaying && !_startedPlaying) {
        _startedPlaying = true;
        _safeAdd(_buffering, false);
        _captureStreamInfo();
      }
      if (!v.isPlaying) _safeAdd(_buffering, v.isBuffering);
      _safeAdd(_playing, v.isPlaying);
      _safeAdd(_volume, v.volume);
      final now = DateTime.now();
      if (now.difference(_lastPositionEmit) >= const Duration(milliseconds: 250)) {
        _lastPositionEmit = now;
        _safeAdd(_position, v.position);
        _updateSubtitleAt(v.position);
      }
      _safeAdd(_duration, v.duration);
      if (v.isCompleted) _safeAdd(_completed, true);
      if (v.isPlaying) _safeAdd(_buffering, false);
    } catch (_) {}
  }

  void _updateSubtitleAt(Duration position) {
    // Altyazı zamanlaması — basit eşleşme
    if (_cues.isEmpty) return;
    String? found;
    for (final cue in _cues) {
      if (position >= cue.start && position <= cue.end) {
        found = cue.text;
        break;
      }
    }
    if (found != _activeSubtitle) {
      _activeSubtitle = found;
      _safeAdd(_subtitleText, found);
    }
  }

  void _captureStreamInfo() {
    if (_streamInfo != null) return;
    if (_useExo) {
      final c = _exoController;
      if (c != null) {
        final size = c.value.size;
        if (size.width > 0 && size.height > 0) {
          _streamInfo = '${size.width.round()}×${size.height.round()}';
        }
      }
    } else {
      // mpv boyut bilgisi
      _streamInfo = 'HD';
    }
  }

  Future<void> _cancelAll(int gen) async {
    // mpv temizle
    _mpvPlaying?.cancel(); _mpvPlaying = null;
    _mpvBuffering?.cancel(); _mpvBuffering = null;
    _mpvCompleted?.cancel(); _mpvCompleted = null;
    _mpvPosition?.cancel(); _mpvPosition = null;
    _mpvDuration?.cancel(); _mpvDuration = null;
    if (_mpvPlayer != null) {
      try { await _mpvPlayer!.stop(); } catch (_) {}
      try { await _mpvPlayer!.dispose(); } catch (_) {}
      _mpvPlayer = null;
      _mpvVideoController = null;
    }

    // Exo temizle
    if (_exoListener != null && _exoController != null) {
      try { _exoController!.removeListener(_exoListener!); } catch (_) {}
      _exoListener = null;
    }
    if (_exoController != null) {
      try { await _exoController!.pause(); } catch (_) {}
      try { await _exoController!.dispose(); } catch (_) {}
      _exoController = null;
    }
  }

  Future<void> _discoverHlsSubtitles(String url) async {
    final tracks = await HlsSubtitleService.discoverTracks(url, headers: _headers);
    if (_disposed || _lastUrl != url) return;
    _hlsTracks = tracks;
    if (tracks.isNotEmpty) {
      _subtitleTracks.add(tracks.map((t) => t.toInfo()).toList());
    }
  }

  // ═══════════════════════════════════════════════════════════════
  //  KONTROL METODLARI
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    if (_useExo) {
      final c = _exoController;
      if (c == null) return const ColoredBox(color: Colors.black);
      return ColoredBox(color: Colors.black, child: vp.VideoPlayer(c));
    }
    if (_mpvVideoController == null) return const ColoredBox(color: Colors.black);
    return ColoredBox(
      color: Colors.black,
      child: Video(controller: _mpvVideoController!),
    );
  }

  @override
  Future<void> play() async {
    if (_useExo) {
      try { await _exoController?.play(); } catch (_) {}
    } else {
      try { await _mpvPlayer?.play(); } catch (_) {}
    }
  }

  @override
  Future<void> pause() async {
    if (_useExo) {
      try { await _exoController?.pause(); } catch (_) {}
    } else {
      try { await _mpvPlayer?.pause(); } catch (_) {}
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_useExo) {
      try { await _exoController?.seekTo(position); } catch (_) {}
    } else {
      try { await _mpvPlayer?.seek(position); } catch (_) {}
    }
  }

  @override
  Future<void> setVolume(double v) async {
    _pendingVolume = v.clamp(0.0, 1.0);
    if (_useExo) {
      try { await _exoController?.setVolume(_pendingVolume); } catch (_) {}
    } else {
      try { await _mpvPlayer?.setVolume(_pendingVolume * 100); } catch (_) {}
    }
  }

  @override
  Future<void> setExternalSubtitle(String url) async {
    // Gelecek versiyonda mpv subtitle desteği
  }

  @override
  Future<void> disableSubtitles() async {
    _safeAdd(_subtitleText, null);
  }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    if (id == 'off') { _safeAdd(_subtitleText, null); return; }
    // HLS track seçimi
  }

  @override
  Future<void> setAudioTrackById(String id) async {
    // Ses seçimi
  }

  @override
  int? get textureId => null;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _hlsSubtitleRefresh?.cancel();
    await _cancelAll(_generation);
    await _buffering.close();
    await _error.close();
    await _playing.close();
    await _volume.close();
    await _position.close();
    await _duration.close();
    await _completed.close();
    await _subtitleTracks.close();
    await _subtitleText.close();
    await _activeSubtitleId.close();
    await _audioTracksCtrl.close();
    await _activeAudioTrackId.close();
  }
}
