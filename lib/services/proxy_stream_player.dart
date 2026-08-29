import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart' as vp;

import 'package:hermestv/services/hls_subtitle_service.dart';
import 'package:hermestv/services/stream_player.dart';
import 'package:hermestv/services/stream_proxy.dart';

/// ═══════════════════════════════════════════════════════════════════
///  PROXY OYNATICI — Sıfırdan yazılmış kesintisiz IPTV motoru
///
///  Nasıl çalışır:
///  1. Dart proxy sunucusu IPTV'yi sürekli indirir (asla durmaz)
///  2. ExoPlayer localhost'tan okur (ağ gecikmesi yok)
///  3. Proxy bağlantı koparsa otomatik reconnect yapar
///  4. ExoPlayer sadece localhost'taki veriyi oynatır
///
///  Sonuç: 30 saniye donma SIFIR, kesintisiz yayın
/// ═══════════════════════════════════════════════════════════════════
class ProxyStreamPlayer extends StreamPlayer {
  ProxyStreamPlayer({required this.bufferSecs});

  vp.VideoPlayerController? _controller;
  VoidCallback? _listener;
  int _generation = 0;
  bool _disposed = false;
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
    _startedPlaying = false;
    _cues = const []; _activeSubtitle = null;
    _safeAdd(_subtitleText, null); _safeAdd(_activeSubtitleId, null);
    _safeAdd(_buffering, true); _safeAdd(_position, Duration.zero);
    _safeAdd(_duration, Duration.zero);
    _headers = headers; _lastUrl = url;
    _hlsSubtitleRefresh?.cancel(); _hlsSubtitleRefresh = null;

    // Eski controller'ı temizle
    final old = _controller;
    if (old != null) {
      _controller = null;
      try {
        if (_listener != null) { old.removeListener(_listener!); _listener = null; }
        await old.pause();
      } catch (_) {}
      try { await old.dispose(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // ═══════════════════════════════════════════════════════════════
    //  ADIM 1: Proxy'yi başlat (eğer çalışmıyorsa)
    // ═══════════════════════════════════════════════════════════════
    final proxy = StreamProxy.instance;
    if (!proxy.isRunning) {
      await proxy.start();
    }

    // ═══════════════════════════════════════════════════════════════
    //  ADIM 2: Proxy URL'i oluştur
    // ═══════════════════════════════════════════════════════════════
    final localUrl = proxy.proxyUrl(url, headers: headers);
    print('[ProxyPlayer] Local URL: $localUrl');

    // ═══════════════════════════════════════════════════════════════
    //  ADIM 3: ExoPlayer ile localhost'tan oynat
    // ═══════════════════════════════════════════════════════════════
    vp.VideoPlayerController? c;
    final trial = vp.VideoPlayerController.networkUrl(Uri.parse(localUrl));
    try {
      await trial.initialize().timeout(const Duration(seconds: 15));
      c = trial;
      _listener = () => _onValueChanged(c!);
      c.addListener(_listener!);
    } catch (_) {
      try { await trial.dispose(); } catch (_) {}
    }

    if (c == null || gen != _generation || _disposed) {
      if (c != null) try { await c.dispose(); } catch (_) {}
      if (gen != _generation || _disposed) return;
      _lastError = 'Akış açılamadı';
      _safeAdd(_error, _lastError!);
      return;
    }

    _controller = c;
    _live = c.value.duration == Duration.zero;

    // Altyazı keşfi
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      await setExternalSubtitle(subtitleUrl);
    } else {
      unawaited(_discoverHlsSubtitles(url));
    }

    try { await c.setVolume(_pendingVolume); } catch (_) {}
    try { await c.play(); } catch (_) {}
  }

  void _onValueChanged(vp.VideoPlayerController src) {
    if (_disposed) return;
    final c = _controller;
    if (c == null || !identical(src, c)) return;
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

  void _captureStreamInfo() {
    if (_streamInfo != null) return;
    final c = _controller;
    if (c != null) {
      final size = c.value.size;
      if (size.width > 0 && size.height > 0) {
        _streamInfo = '${size.width.round()}×${size.height.round()}';
      }
    }
  }

  void _updateSubtitleAt(Duration position) {
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
    final c = _controller;
    if (c == null) return const ColoredBox(color: Colors.black);
    return ColoredBox(color: Colors.black, child: vp.VideoPlayer(c));
  }

  @override
  Future<void> play() async {
    try { await _controller?.play(); } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try { await _controller?.pause(); } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    try { await _controller?.seekTo(position); } catch (_) {}
  }

  @override
  Future<void> setVolume(double v) async {
    _pendingVolume = v.clamp(0.0, 1.0);
    try { await _controller?.setVolume(_pendingVolume); } catch (_) {}
  }

  @override
  Future<void> setExternalSubtitle(String url) async {
    // Gelecek versiyonda
  }

  @override
  Future<void> disableSubtitles() async {
    _safeAdd(_subtitleText, null);
  }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    if (id == 'off') { _safeAdd(_subtitleText, null); return; }
  }

  @override
  Future<void> setAudioTrackById(String id) async {}

  @override
  int? get textureId => null;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _hlsSubtitleRefresh?.cancel();
    if (_listener != null && _controller != null) {
      try { _controller!.removeListener(_listener!); } catch (_) {}
      _listener = null;
    }
    if (_controller != null) {
      try { await _controller!.pause(); } catch (_) {}
      try { await _controller!.dispose(); } catch (_) {}
      _controller = null;
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
    await _activeSubtitleId.close();
    await _audioTracksCtrl.close();
    await _activeAudioTrackId.close();
  }
}
