import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermestv/services/stream_player.dart';

/// Doğrudan Media3/ExoPlayer — MethodChannel üzerinden kontrol.
/// Flutter video_player wrapper'ı ATLANIYOR.
class NativeExoStreamPlayer extends StreamPlayer {
  NativeExoStreamPlayer({required this.bufferSecs});

  static const _channel = MethodChannel('com.iptv.iptv_player/exo_player');

  int? _textureId;
  int? _producerId;  // SurfaceProducer'ın kendi ID'si — Texture widget için
  bool _disposed = false;
  String? _lastUrl;
  bool _live = false;

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

  double _pendingVolume = 1.0;
  String? _streamInfo;
  Timer? _positionTimer;
  int _openGeneration = 0; // hızlı zap'ta eski open() yarışını iptal etmek için

  // Yayın sağlığı — plugin metriklerinden saniyede bir örneklenir
  final _healthCtrl = StreamController<StreamHealth>.broadcast();
  Timer? _healthTimer;

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
  Stream<StreamHealth> get health => _healthCtrl.stream;
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
    if (_disposed) return;
    final gen = ++_openGeneration; // bu open()'ın sırası — yenisi gelirse iptal ol
    _lastUrl = url;
    _live = url.contains('/live/') || url.contains('.m3u8');
    _streamInfo = null;
    _safeAdd(_buffering, true);
    _safeAdd(_position, Duration.zero);
    _safeAdd(_duration, Duration.zero);

    try {
      // Eski player'ı temizle — ÖNCE sesi kapat, ses karışmasını önler
      if (_textureId != null) {
        try { await _channel.invokeMethod('setVolume', {'textureId': _textureId, 'volume': 0.0}); } catch (_) {}
        try { await _channel.invokeMethod('pause', {'textureId': _textureId}); } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 50));
        if (gen != _openGeneration) return; // bu arada yeni kanal istendi
        try { await _channel.invokeMethod('dispose', {'textureId': _textureId}); } catch (_) {}
        _textureId = null;
        _producerId = null;
        // ExoPlayer resource temizliği için bekleme
        await Future.delayed(const Duration(milliseconds: 200));
        if (gen != _openGeneration) return;
      }

      // Yeni texture oluştur
      final result = await _channel.invokeMethod<Map>('create', {
        'textureId': DateTime.now().millisecondsSinceEpoch,
      });
      if (gen != _openGeneration) {
        // Bu arada yeni kanal istendi — hemen yaratılanı öldür, eski URL'ye başlama
        try { await _channel.invokeMethod('dispose', {'textureId': result?['textureId']}); } catch (_) {}
        return;
      }
      if (result == null) { _safeAdd(_error, 'Texture oluşturulamadı'); return; }
      _textureId = result['textureId'] as int;
      _producerId = result['producerId'] as int? ?? _textureId;

      // Dinleyiciyi ayarla
      _setupListener();

      // Kanalı aç
      await _channel.invokeMethod('open', {
        'textureId': _textureId,
        'url': url,
      });
      if (gen != _openGeneration) return;

      // Ses seviyesini ayarla — bekleme, hemen ayarla
      unawaited(_channel.invokeMethod('setVolume', {
        'textureId': _textureId,
        'volume': _pendingVolume,
      }));

      // Pozisyon takibi — 500ms yeterli; 200ms MethodChannel yükü UI jank üretiyordu
      _positionTimer?.cancel();
      _positionTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _pollPosition());

      // Tampon/canlı kenar/yeniden bağlanma — saniyede bir
      _healthTimer?.cancel();
      _healthTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollHealth());

      // Ses/altyazi track'lerini keşfet — 2sn bekle (ExoPlayer parse etsin)
      unawaited(Future.delayed(const Duration(seconds: 2), () => _discoverTracks()));
    } catch (e) {
      _safeAdd(_error, 'Oynatıcı oluşturulamadı: $e');
    }
  }

  /// ExoPlayer'dan ses ve altyazi track'lerini keşfet.
  Future<void> _discoverTracks() async {
    if (_disposed || _textureId == null) return;
    try {
      // Ses track'leri
      final audioResult = await _channel.invokeMethod<List>('getAudioTracks', {'textureId': _textureId});
      if (audioResult != null && !_disposed) {
        final tracks = audioResult.map((t) => AudioTrackInfo(
          id: t['id'] as String,
          title: t['label'] as String,
          language: t['language'] as String?,
        )).toList();
        _safeAdd(_audioTracksCtrl, tracks);
        if (tracks.isNotEmpty) {
          _safeAdd(_activeAudioTrackId, tracks.first.id);
        }
      }

      // Altyazi track'leri
      final subResult = await _channel.invokeMethod<List>('getSubtitleTracks', {'textureId': _textureId});
      if (subResult != null && !_disposed) {
        final tracks = subResult.map((t) => SubtitleInfo(
          id: t['id'] as String,
          title: t['label'] as String,
          language: t['language'] as String?,
        )).toList();
        _safeAdd(_subtitleTracks, tracks);
      }
    } catch (_) {}
  }

  void _setupListener() {
    _channel.setMethodCallHandler((call) async {
      if (_disposed) return;
      final args = call.arguments as Map?;
      if (args == null) return;
      final tid = args['textureId'];
      if (tid != _textureId) return;

      switch (call.method) {
        case 'onReady':
          _safeAdd(_buffering, false);
          final dur = args['duration'] as int?;
          if (dur != null && dur > 0) _safeAdd(_duration, Duration(milliseconds: dur));
          break;
        case 'onBuffering':
          _safeAdd(_buffering, true);
          break;
        case 'onPlaying':
          final isPlaying = args['isPlaying'] as bool? ?? false;
          _safeAdd(_playing, isPlaying);
          if (isPlaying) _safeAdd(_buffering, false);
          break;
        case 'onCompleted':
          _safeAdd(_completed, true);
          break;
        case 'onError':
          _safeAdd(_error, args['message'] as String? ?? 'Hata');
          break;
      }
    });
  }

  Future<void> _pollPosition() async {
    if (_disposed || _textureId == null) return;
    try {
      final pos = await _channel.invokeMethod<int>('getPosition', {'textureId': _textureId});
      if (pos != null && pos >= 0) _safeAdd(_position, Duration(milliseconds: pos));
    } catch (_) {}
  }

  /// ExoPlayer metriklerini oku — tampon, canlı kenar mesafesi, yeniden bağlanma.
  Future<void> _pollHealth() async {
    if (_disposed || _textureId == null) return;
    try {
      final m = await _channel.invokeMethod<Map>('getPlaybackMetrics', {'textureId': _textureId});
      if (m == null) return;
      _safeAdd(_healthCtrl, streamHealthFromMetrics(m));
    } catch (_) {}
  }

  @override
  Future<void> play() async {
    if (_textureId == null) return;
    try { await _channel.invokeMethod('play', {'textureId': _textureId}); } catch (_) {}
  }

  @override
  Future<void> pause() async {
    if (_textureId == null) return;
    try { await _channel.invokeMethod('pause', {'textureId': _textureId}); } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    if (_textureId == null) return;
    try { await _channel.invokeMethod('seek', {'textureId': _textureId, 'positionMs': position.inMilliseconds}); } catch (_) {}
  }

  @override
  Future<void> setVolume(double v) async {
    _pendingVolume = v;
    if (_textureId == null) return;
    try { await _channel.invokeMethod('setVolume', {'textureId': _textureId, 'volume': v}); } catch (_) {}
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    if (_producerId == null) return const ColoredBox(color: Colors.black);
    return ColoredBox(color: Colors.black, child: Texture(textureId: _producerId!));
  }

  @override
  Future<void> setExternalSubtitle(String url) async {
    // Harici altyazi ExoPlayer'da desteklenmiyor — HLS'de kullanilir
  }

  @override
  Future<void> disableSubtitles() async {
    _safeAdd(_subtitleText, null);
    _safeAdd(_activeSubtitleId, null);
    if (_textureId != null) {
      try { await _channel.invokeMethod('selectSubtitleTrack', {'textureId': _textureId, 'trackIndex': -1}); } catch (_) {}
    }
  }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    if (_textureId == null) return;
    // ID formati: 'subtitle_2' -> index 2
    final parts = id.split('_');
    final idx = int.tryParse(parts.last);
    if (idx != null) {
      try {
        await _channel.invokeMethod('selectSubtitleTrack', {'textureId': _textureId, 'trackIndex': idx});
        _safeAdd(_activeSubtitleId, id);
      } catch (_) {}
    }
  }

  @override
  Future<void> setAudioTrackById(String id) async {
    if (_textureId == null) return;
    // ID formati: 'audio_1' -> index 1
    final parts = id.split('_');
    final idx = int.tryParse(parts.last);
    if (idx != null) {
      try {
        await _channel.invokeMethod('selectAudioTrack', {'textureId': _textureId, 'trackIndex': idx});
        _safeAdd(_activeAudioTrackId, id);
      } catch (_) {}
    }
  }
  @override
  int? get textureId => _textureId;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _positionTimer?.cancel();
    _healthTimer?.cancel();
    if (_textureId != null) {
      try { await _channel.invokeMethod('dispose', {'textureId': _textureId}); } catch (_) {}
      _textureId = null;
      _producerId = null;
    }
    for (final sc in [_healthCtrl, _buffering, _error, _playing, _volume, _position,
      _duration, _completed, _subtitleTracks, _subtitleText, _activeSubtitleId,
      _audioTracksCtrl, _activeAudioTrackId]) {
      try { await sc.close(); } catch (_) {}
    }
  }
}
