import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hermestv/services/hls_subtitle_service.dart';

// Platforma göre oynatıcı motoru
import 'package:video_player/video_player.dart' as vp;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Altyazı parçası bilgisi (oynatıcıdan bağımsız).
class SubtitleInfo {
  const SubtitleInfo({required this.id, required this.title, this.language});
  final String id;
  final String title;
  final String? language;
}

/// Ses parçası bilgisi.
class AudioTrackInfo {
  const AudioTrackInfo({required this.id, required this.title, this.language, this.isDefault = false});
  final String id;
  final String title;
  final String? language;
  final bool isDefault;
}

/// Oynatıcı motoru soyutlaması.
abstract class StreamPlayer {
  Stream<bool> get buffering;
  Stream<String> get error;
  Stream<bool> get playing;
  Stream<double> get volume;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get completed;
  Stream<List<SubtitleInfo>> get subtitleTracks;
  Stream<String?> get subtitleText;
  Stream<String?> get activeSubtitleId;
  bool? get isLive;
  String? get streamInfo;
  double get bufferSecs;
  set bufferSecs(double value);
  Widget buildVideo({BoxFit fit = BoxFit.contain});
  Future<void> open(String url, {Map<String, String>? headers, String? subtitleUrl});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double v);
  Future<void> setExternalSubtitle(String uri);
  Future<void> disableSubtitles();
  Future<void> setSubtitleTrackById(String id);
  Stream<List<AudioTrackInfo>> get audioTracks;
  Stream<String?> get activeAudioTrackId;
  Future<void> setAudioTrackById(String id);
  Future<void> dispose();
}

/// Factory: Android → ExoStreamPlayer (OkHttp + ExoPlayer), Linux → MpvStreamPlayer (mpv)
StreamPlayer createStreamPlayer({double bufferSecs = 1.0}) {
  if (Platform.isAndroid) {
    return ExoStreamPlayer(bufferSecs: bufferSecs);
  }
  return MpvStreamPlayer(bufferSecs: bufferSecs);
}

// ═══════════════════════════════════════════════════════════════════
//  ANDROID: ExoStreamPlayer (video_player/ExoPlayer — hafif, stabil)
// ═══════════════════════════════════════════════════════════════════
class ExoStreamPlayer extends StreamPlayer {
  ExoStreamPlayer({required this.bufferSecs});

  vp.VideoPlayerController? _controller;
  VoidCallback? _controllerListener;
  int _generation = 0;
  bool _disposed = false;
  double _pendingVolume = 1.0;
  bool? _live;
  String? _lastError;
  String? _streamInfo;
  bool _startedPlaying = false;

  List<SubtitleCue> _cues = const [];
  String? _activeSubtitle;
  List<HlsSubtitleTrack> _hlsTracks = const [];
  HlsSubtitleTrack? _selectedHlsTrack;
  Timer? _hlsSubtitleRefresh;
  Map<String, String>? _headers;
  String? _lastUrl;

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
  Duration _lastPosition = Duration.zero;
  DateTime _lastPositionChange = DateTime.now();
  int _stallRetries = 0;
  static const int _maxStallRetries = 3;

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
        _captureStreamInfo(c);
      }
      if (!v.isPlaying) {
        _safeAdd(_buffering, v.isBuffering);
      }
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

      // ExoPlayer native buffer yonetir (5dk max, live speed control).
      // Flutter tarafinda mudahale yok — native katman daha hizli ve dogru karar verir.
      if (v.isPlaying) {
        _safeAdd(_buffering, false);
      }
    } catch (_) {}
  }

  void _captureStreamInfo(vp.VideoPlayerController c) {
    if (_streamInfo != null) return;
    final size = c.value.size;
    if (size.width > 0 && size.height > 0) {
      _streamInfo = '${size.width.round()}×${size.height.round()}';
    }
  }

  @override
  Future<void> open(String url, {Map<String, String>? headers, String? subtitleUrl}) async {
    final gen = ++_generation;
    _live = null; _lastError = null; _streamInfo = null; _startedPlaying = false;
    _cues = const []; _activeSubtitle = null;
    _safeAdd(_subtitleText, null); _safeAdd(_activeSubtitleId, null);
    _safeAdd(_buffering, true); _safeAdd(_position, Duration.zero); _safeAdd(_duration, Duration.zero);
    _headers = headers; _lastUrl = url;
    _hlsSubtitleRefresh?.cancel(); _hlsSubtitleRefresh = null;
    _stallRetries = 0; _lastPosition = Duration.zero; _lastPositionChange = DateTime.now();

    // Eski controller'ı temizle — ÖNCE durdur, sonra temizle (ses karışmasını önler)
    final old = _controller;
    if (old != null) {
      _controller = null; // Yeni controller oluşturulana kadar null
      try {
        if (_controllerListener != null) { old.removeListener(_controllerListener!); _controllerListener = null; }
        await old.pause();  // DURDUR — unawaited DEĞİL
      } catch (_) {}
      try { await old.dispose(); } catch (_) {}
      // Eski player tamamen kapandı — kısa bekleme (ExoPlayer resource temizliği)
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Android ExoPlayer — sadece 1 UA deneme (hızlı açılış)
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
      _controllerListener = () => _onValueChanged(c!);
      c.addListener(_controllerListener!);
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
        _controllerListener = () => _onValueChanged(c!);
        c.addListener(_controllerListener!);
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

    _controller = c;
    _live = c.value.duration == Duration.zero;

    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      await setExternalSubtitle(subtitleUrl);
    } else {
      unawaited(_discoverHlsSubtitles(url));
    }

    try { await c.setVolume(_pendingVolume); } catch (_) {}
    try { await c.play(); } catch (_) {}
  }

  Future<void> _discoverHlsSubtitles(String url) async {
    final tracks = await HlsSubtitleService.discoverTracks(url, headers: _headers);
    if (_disposed) return;
    if (_lastUrl != url) return;
    _hlsTracks = tracks;
    if (tracks.isNotEmpty) {
      _subtitleTracks.add(tracks.map((t) => t.toInfo()).toList());
    } else {
      _subtitleTracks.add([const SubtitleInfo(id: 'dvb_auto', title: 'Otomatik Altyazı')]);
    }
    _discoverHlsAudioTracks(url);
    HlsSubtitleTrack? pick;
    for (final t in tracks) { if (t.isTurkish) { pick = t; break; } }
    pick ??= tracks.where((t) => t.isDefault || t.isAutoselect).firstOrNull;
    pick ??= tracks.first;
    await setSubtitleTrackById(pick.id);
  }

  Future<void> _discoverHlsAudioTracks(String url) async {
    if (!url.toLowerCase().contains('.m3u8') && !url.contains('/live/')) return;
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers ?? const {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final body = resp.body;
      final tracks = <AudioTrackInfo>[];
      final re = RegExp(r'#EXT-X-MEDIA:TYPE=AUDIO.*?GROUP-ID="([^"]*)".*?NAME="([^"]*)"(?:.*?LANGUAGE="([^"]*)")?(?:.*?DEFAULT=(YES|NO))?(?:.*?URI="([^"]*)")');
      for (final m in re.allMatches(body)) {
        tracks.add(AudioTrackInfo(id: 'audio_${m.group(2)}', title: m.group(2) ?? 'Ses', language: m.group(3), isDefault: m.group(4) == 'YES'));
      }
      if (tracks.isEmpty) tracks.add(const AudioTrackInfo(id: 'audio_default', title: 'Varsayılan Ses'));
      _safeAdd(_audioTracksCtrl, tracks);
      final def = tracks.where((t) => t.isDefault).firstOrNull ?? tracks.first;
      _safeAdd(_activeAudioTrackId, def.id);
    } catch (_) {}
  }

  Future<void> _loadHlsTrack(HlsSubtitleTrack track) async {
    _selectedHlsTrack = track;
    final cues = await HlsSubtitleService.loadTrackCues(track, headers: _headers);
    if (_disposed) return;
    if (!identical(_selectedHlsTrack, track)) return;
    _cues = cues;
    final c = _controller;
    if (c != null) _updateSubtitleAt(c.value.position);
    _hlsSubtitleRefresh?.cancel();
    if (_live == true) {
      _hlsSubtitleRefresh = Timer.periodic(const Duration(seconds: 45), (_) {
        if (_disposed || _selectedHlsTrack == null) return;
        unawaited(_refreshHlsTrack(track));
      });
    }
  }

  Future<void> _refreshHlsTrack(HlsSubtitleTrack track) async {
    final fresh = await HlsSubtitleService.loadTrackCues(track, headers: _headers);
    if (_disposed || !identical(_selectedHlsTrack, track)) return;
    final byStart = <int, SubtitleCue>{};
    for (final c in _cues) { byStart[c.start.inMilliseconds] = c; }
    var changed = false;
    for (final c in fresh) { final k = c.start.inMilliseconds; if (!byStart.containsKey(k)) { byStart[k] = c; changed = true; } }
    if (changed) {
      _cues = byStart.values.toList()..sort((a, b) => a.start.compareTo(b.start));
      final c = _controller;
      if (c != null) _updateSubtitleAt(c.value.position);
    }
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    final c = _controller;
    if (c == null) return const ColoredBox(color: Colors.black);
    return ColoredBox(color: Colors.black, child: vp.VideoPlayer(c));
  }

  @override
  Future<void> play() async { try { await _controller?.play(); } catch (_) {} }
  @override
  Future<void> pause() async { try { await _controller?.pause(); } catch (_) {} }
  @override
  Future<void> seek(Duration position) async { try { await _controller?.seekTo(position); } catch (_) {} }
  @override
  Future<void> setVolume(double v) async { _pendingVolume = v.clamp(0.0, 1.0); try { await _controller?.setVolume(_pendingVolume); } catch (_) {} }

  @override
  Future<void> setExternalSubtitle(String uri) async {
    try {
      final raw = await _fetchSubtitle(uri);
      if (raw == null) return;
      _cues = parseSubtitleCues(raw);
      _activeSubtitle = null;
      final c = _controller;
      if (c != null) _updateSubtitleAt(c.value.position);
    } catch (_) {}
  }

  @override
  Future<void> disableSubtitles() async { _cues = const []; _activeSubtitle = null; _safeAdd(_subtitleText, null); _activeSubtitleId.add('off'); }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    if (id == 'dvb_auto' || id == 'auto_dvb') { _activeSubtitleId.add(id); return; }
    if (id == 'off') { _activeSubtitleId.add(null); _safeAdd(_subtitleText, null); return; }
    for (final t in _hlsTracks) { if (t.id == id) { await _loadHlsTrack(t); _activeSubtitleId.add(id); return; } }
  }

  @override
  Future<void> setAudioTrackById(String id) async { _safeAdd(_activeAudioTrackId, id); }

  Future<String?> _fetchSubtitle(String uri) async {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      final resp = await http.get(Uri.parse(uri), headers: const {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) { var body = resp.body; if (body.startsWith('\uFEFF')) body = body.substring(1); return body; }
      return null;
    }
    if (uri.startsWith('file://')) { final path = uri.replaceFirst('file://', ''); final file = File(path); if (await file.exists()) return await file.readAsString(); }
    return null;
  }

  void _updateSubtitleAt(Duration position) {
    if (_cues.isEmpty) return;
    String? text;
    for (final cue in _cues) { if (position >= cue.start && position <= cue.end) { text = cue.text; break; } }
    if (text != _activeSubtitle) { _activeSubtitle = text; _safeAdd(_subtitleText, text); }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _hlsSubtitleRefresh?.cancel(); _hlsSubtitleRefresh = null;
    final c = _controller; _controller = null;
    if (c != null) { try { if (_controllerListener != null) { c.removeListener(_controllerListener!); _controllerListener = null; } await c.dispose(); } catch (_) {} }
    for (final sc in [_buffering, _error, _playing, _volume, _position, _duration, _completed, _subtitleTracks, _subtitleText, _activeSubtitleId, _audioTracksCtrl, _activeAudioTrackId]) {
      if (!sc.isClosed) await sc.close();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  LINUX: MpvStreamPlayer (media_kit/mpv — güçlü, 120sn cache)
// ═══════════════════════════════════════════════════════════════════
class MpvStreamPlayer extends StreamPlayer {
  MpvStreamPlayer({required this.bufferSecs});

  Player? _player;
  VideoController? _videoController;
  int _generation = 0;
  bool _disposed = false;
  double _pendingVolume = 1.0;
  bool? _live;
  String? _lastError;
  String? _streamInfo;
  bool _startedPlaying = false;

  List<SubtitleCue> _cues = const [];
  String? _activeSubtitle;
  List<HlsSubtitleTrack> _hlsTracks = const [];
  HlsSubtitleTrack? _selectedHlsTrack;
  Timer? _hlsSubtitleRefresh;
  Map<String, String>? _headers;
  String? _lastUrl;

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
  Duration _lastPosition = Duration.zero;
  DateTime _lastPositionChange = DateTime.now();
  int _stallRetries = 0;
  static const int _maxStallRetries = 5;

  StreamSubscription? _subPlaying;
  StreamSubscription? _subBuffering;
  StreamSubscription? _subCompleted;
  StreamSubscription? _subPosition;
  StreamSubscription? _subDuration;
  StreamSubscription? _subSubtitle;

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
    _live = null; _lastError = null; _streamInfo = null; _startedPlaying = false;
    _cues = const []; _activeSubtitle = null;
    _safeAdd(_subtitleText, null); _safeAdd(_activeSubtitleId, null);
    _safeAdd(_buffering, true); _safeAdd(_position, Duration.zero); _safeAdd(_duration, Duration.zero);
    _headers = headers; _lastUrl = url;
    _hlsSubtitleRefresh?.cancel(); _hlsSubtitleRefresh = null;
    _stallRetries = 0; _lastPosition = Duration.zero; _lastPositionChange = DateTime.now();

    _cancelSubscriptions();
    if (_player == null) {
      try { _player = Player(); } catch (e) { _safeAdd(_error, 'Oynatıcı oluşturulamadı: $e'); return; }
    }
    _videoController = VideoController(_player!);

    try {
      final media = Media(url, httpHeaders: headers);
      await _player!.open(media, play: true);
    } catch (e) { _safeAdd(_error, 'Akış açılamadı: $e'); return; }

    _subPlaying = _player!.stream.playing.listen((p) {
      if (_disposed || gen != _generation) return;
      _safeAdd(_playing, p);
      if (p && !_startedPlaying) { _startedPlaying = true; _safeAdd(_buffering, false); _captureStreamInfo(); }
    });
    _subBuffering = _player!.stream.buffering.listen((b) { if (!_disposed && gen == _generation) _safeAdd(_buffering, b); });
    _subCompleted = _player!.stream.completed.listen((_) { if (!_disposed && gen == _generation) _safeAdd(_completed, true); });
    _subPosition = _player!.stream.position.listen((pos) {
      if (_disposed || gen != _generation) return;
      final now = DateTime.now();
      if (now.difference(_lastPositionEmit) >= const Duration(milliseconds: 250)) {
        _lastPositionEmit = now; _safeAdd(_position, pos); _updateSubtitleAt(pos);
      }
      if (_player!.state.playing && pos == _lastPosition && _lastUrl != null) {
        // mpv kendi basina yonetir — seek-forward yapilmaz
      } else if (_player!.state.playing && pos != _lastPosition) {
        _safeAdd(_buffering, false); _lastPosition = pos; _lastPositionChange = DateTime.now(); _stallRetries = 0;
      }
    });
    _subDuration = _player!.stream.duration.listen((d) {
      if (_disposed || gen != _generation) return;
      _safeAdd(_duration, d);
      if (_live == null) _live = d == Duration.zero || d.inSeconds > 86400;
    });
    _subSubtitle = _player!.stream.subtitle.listen((sub) {
      if (_disposed || gen != _generation) return;
      if (sub != null && sub.isNotEmpty) { final text = sub.where((s) => s.trim().isNotEmpty).join('\n'); if (text.trim().isNotEmpty && _activeSubtitle != text) { _activeSubtitle = text; _safeAdd(_subtitleText, text); } }
    });

    try { await _player!.setVolume(_pendingVolume * 100); } catch (_) {}
    if (subtitleUrl != null && subtitleUrl.isNotEmpty) { await setExternalSubtitle(subtitleUrl); } else { unawaited(_discoverHlsSubtitles(url)); }
    await Future.delayed(const Duration(seconds: 1));
    _captureStreamInfo();
  }

  void _cancelSubscriptions() {
    _subPlaying?.cancel(); _subBuffering?.cancel(); _subCompleted?.cancel();
    _subPosition?.cancel(); _subDuration?.cancel(); _subSubtitle?.cancel();
    _subPlaying = _subBuffering = _subCompleted = _subPosition = _subDuration = _subSubtitle = null;
  }

  void _captureStreamInfo() {
    if (_streamInfo != null) return;
    try { final w = _player!.state.width; final h = _player!.state.height; if (w != null && h != null && w > 0 && h > 0) _streamInfo = '${w.round()}×${h.round()}'; } catch (_) {}
  }

  Future<void> _discoverHlsSubtitles(String url) async {
    final tracks = await HlsSubtitleService.discoverTracks(url, headers: _headers);
    if (_disposed || _lastUrl != url) return;
    _hlsTracks = tracks;
    _subtitleTracks.add(tracks.isNotEmpty ? tracks.map((t) => t.toInfo()).toList() : [const SubtitleInfo(id: 'dvb_auto', title: 'Otomatik Altyazı')]);
    _discoverHlsAudioTracks(url);
    HlsSubtitleTrack? pick;
    for (final t in tracks) { if (t.isTurkish) { pick = t; break; } }
    pick ??= tracks.where((t) => t.isDefault || t.isAutoselect).firstOrNull ?? tracks.first;
    await setSubtitleTrackById(pick.id);
  }

  Future<void> _discoverHlsAudioTracks(String url) async {
    if (!url.toLowerCase().contains('.m3u8') && !url.contains('/live/')) return;
    try {
      final resp = await http.get(Uri.parse(url), headers: _headers ?? const {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final tracks = <AudioTrackInfo>[];
      final re = RegExp(r'#EXT-X-MEDIA:TYPE=AUDIO.*?GROUP-ID="([^"]*)".*?NAME="([^"]*)"(?:.*?LANGUAGE="([^"]*)")?(?:.*?DEFAULT=(YES|NO))?(?:.*?URI="([^"]*)")');
      for (final m in re.allMatches(resp.body)) { tracks.add(AudioTrackInfo(id: 'audio_${m.group(2)}', title: m.group(2) ?? 'Ses', language: m.group(3), isDefault: m.group(4) == 'YES')); }
      if (tracks.isEmpty) tracks.add(const AudioTrackInfo(id: 'audio_default', title: 'Varsayılan Ses'));
      _safeAdd(_audioTracksCtrl, tracks);
      _safeAdd(_activeAudioTrackId, (tracks.where((t) => t.isDefault).firstOrNull ?? tracks.first).id);
    } catch (_) {}
  }

  Future<void> _loadHlsTrack(HlsSubtitleTrack track) async {
    _selectedHlsTrack = track;
    final cues = await HlsSubtitleService.loadTrackCues(track, headers: _headers);
    if (_disposed || !identical(_selectedHlsTrack, track)) return;
    _cues = cues; _updateSubtitleAt(_player!.state.position);
    _hlsSubtitleRefresh?.cancel();
    if (_live == true) { _hlsSubtitleRefresh = Timer.periodic(const Duration(seconds: 45), (_) { if (!_disposed && _selectedHlsTrack != null) unawaited(_refreshHlsTrack(track)); }); }
  }

  Future<void> _refreshHlsTrack(HlsSubtitleTrack track) async {
    final fresh = await HlsSubtitleService.loadTrackCues(track, headers: _headers);
    if (_disposed || !identical(_selectedHlsTrack, track)) return;
    final byStart = <int, SubtitleCue>{};
    for (final c in _cues) { byStart[c.start.inMilliseconds] = c; }
    for (final c in fresh) { final k = c.start.inMilliseconds; if (!byStart.containsKey(k)) byStart[k] = c; }
    _cues = byStart.values.toList()..sort((a, b) => a.start.compareTo(b.start));
    _updateSubtitleAt(_player!.state.position);
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    final vc = _videoController;
    if (vc == null) return const ColoredBox(color: Colors.black);
    return ColoredBox(color: Colors.black, child: Video(controller: vc, controls: null));
  }

  @override
  Future<void> play() async { try { await _player!.play(); } catch (_) {} }
  @override
  Future<void> pause() async { try { await _player!.pause(); } catch (_) {} }
  @override
  Future<void> seek(Duration position) async { try { await _player!.seek(position); } catch (_) {} }
  @override
  Future<void> setVolume(double v) async { _pendingVolume = v.clamp(0.0, 1.0); try { await _player!.setVolume(_pendingVolume * 100); } catch (_) {} }

  @override
  Future<void> setExternalSubtitle(String uri) async {
    try {
      final raw = await _fetchSubtitle(uri);
      if (raw == null) return;
      _cues = parseSubtitleCues(raw); _activeSubtitle = null; _updateSubtitleAt(_player!.state.position);
    } catch (_) {}
  }

  @override
  Future<void> disableSubtitles() async { _cues = const []; _activeSubtitle = null; _safeAdd(_subtitleText, null); _activeSubtitleId.add('off'); }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    if (id == 'dvb_auto' || id == 'auto_dvb') { _activeSubtitleId.add(id); return; }
    if (id == 'off') { _activeSubtitleId.add(null); _safeAdd(_subtitleText, null); return; }
    for (final t in _hlsTracks) { if (t.id == id) { await _loadHlsTrack(t); _activeSubtitleId.add(id); return; } }
  }

  @override
  Future<void> setAudioTrackById(String id) async { _safeAdd(_activeAudioTrackId, id); }

  Future<String?> _fetchSubtitle(String uri) async {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      final resp = await http.get(Uri.parse(uri), headers: const {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) { var body = resp.body; if (body.startsWith('\uFEFF')) body = body.substring(1); return body; }
      return null;
    }
    if (uri.startsWith('file://')) { final path = uri.replaceFirst('file://', ''); final file = File(path); if (await file.exists()) return await file.readAsString(); }
    return null;
  }

  void _updateSubtitleAt(Duration position) {
    if (_cues.isEmpty) return;
    String? text;
    for (final cue in _cues) { if (position >= cue.start && position <= cue.end) { text = cue.text; break; } }
    if (text != _activeSubtitle) { _activeSubtitle = text; _safeAdd(_subtitleText, text); }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return; _disposed = true; _generation++;
    _hlsSubtitleRefresh?.cancel(); _hlsSubtitleRefresh = null; _cancelSubscriptions();
    try { await _player!.stop(); } catch (_) {}
    try { await _player!.dispose(); } catch (_) {}
    for (final sc in [_buffering, _error, _playing, _volume, _position, _duration, _completed, _subtitleTracks, _subtitleText, _activeSubtitleId, _audioTracksCtrl, _activeAudioTrackId]) {
      if (!sc.isClosed) await sc.close();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SRT / VTT ayrıştırıcı (her iki motor için ortak)
// ═══════════════════════════════════════════════════════════════════

class SubtitleCue {
  const SubtitleCue(this.start, this.end, this.text);
  final Duration start; final Duration end; final String text;
}

class _SubCue {
  const _SubCue(this.start, this.end, this.text);
  final Duration start; final Duration end; final String text;
}

List<SubtitleCue> parseSubtitleCues(String raw) {
  return _parseSubtitles(raw).map((c) => SubtitleCue(c.start, c.end, c.text)).toList(growable: false);
}

List<_SubCue> _parseSubtitles(String raw) {
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final cues = <_SubCue>[];
  final re = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})');
  for (var i = 0; i < lines.length; i++) {
    final m = re.firstMatch(lines[i]);
    if (m == null) continue;
    final start = _cueTime(m.group(1)!, m.group(2)!, m.group(3)!, m.group(4)!);
    final end = _cueTime(m.group(5)!, m.group(6)!, m.group(7)!, m.group(8)!);
    final textLines = <String>[];
    i++;
    while (i < lines.length && lines[i].trim().isNotEmpty) { textLines.add(lines[i].trim()); i++; }
    if (textLines.isNotEmpty) cues.add(_SubCue(start, end, textLines.join('\n')));
  }
  return cues;
}

Duration _cueTime(String h, String m, String s, String ms) {
  var millis = ms.padRight(3, '0');
  if (millis.length > 3) millis = millis.substring(0, 3);
  return Duration(hours: int.parse(h), minutes: int.parse(m), seconds: int.parse(s), milliseconds: int.parse(millis));
}
