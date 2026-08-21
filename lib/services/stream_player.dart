import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hermestv/services/hls_subtitle_service.dart';
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

/// Oynatıcı motoru soyutlaması — media_kit (ExoPlayer/libmpv) ile tam ses/altyazı track desteği.
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

/// media_kit tabanlı oynatıcı — Android'de ExoPlayer, Linux'ta libmpv.
/// Tam ses ve altyazı track desteği.
StreamPlayer createStreamPlayer({double bufferSecs = 1.0}) {
  return MediaKitStreamPlayer(bufferSecs: bufferSecs);
}

class MediaKitStreamPlayer extends StreamPlayer {
  MediaKitStreamPlayer({this.bufferSecs = 1.0});

  Player? _player;
  VideoController? _vc;
  int _gen = 0;
  bool _disposed = false;
  bool _started = false;
  String? _lastError;
  String? _lastUrl;
  Map<String, String>? _headers;
  bool? _live;

  // Stream controllers
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

  // Altyazı
  List<SubtitleCue> _cues = const [];
  String? _activeSub;
  List<HlsSubtitleTrack> _hlsTracks = const [];
  HlsSubtitleTrack? _selHlsTrack;
  Timer? _hlsRefresh;

  // Ses
  String? _activeAudioId;

  @override Stream<bool> get buffering => _buffering.stream;
  @override Stream<String> get error => _error.stream;
  @override Stream<bool> get playing => _playing.stream;
  @override Stream<double> get volume => _volume.stream;
  @override Stream<Duration> get position => _position.stream;
  @override Stream<Duration> get duration => _duration.stream;
  @override Stream<bool> get completed => _completed.stream;
  @override Stream<List<SubtitleInfo>> get subtitleTracks => _subtitleTracks.stream;
  @override Stream<String?> get subtitleText => _subtitleText.stream;
  @override Stream<String?> get activeSubtitleId => _activeSubtitleId.stream;
  @override Stream<List<AudioTrackInfo>> get audioTracks => _audioTracksCtrl.stream;
  @override Stream<String?> get activeAudioTrackId => _activeAudioTrackId.stream;
  @override bool? get isLive => _live;
  @override String? get streamInfo => null;
  @override double bufferSecs;

  void _add<T>(StreamController<T> sc, T v) {
    if (_disposed || sc.isClosed) return;
    try { sc.add(v); } catch (_) {}
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    final vc = _vc;
    if (vc == null) return const ColoredBox(color: Colors.black);
    return Video(controller: vc, fit: fit);
  }

  @override
  Future<void> open(String url, {Map<String, String>? headers, String? subtitleUrl}) async {
    _gen++;
    final gen = _gen;
    _lastUrl = url;
    _headers = headers;
    _started = false;
    _lastError = null;
    _cues = const [];
    _activeSub = null;
    _hlsTracks = const [];
    _selHlsTrack = null;
    _hlsRefresh?.cancel();
    _add(_buffering, true);
    _add(_error, '');
    _add(_subtitleText, null);
    _add(_activeSubtitleId, null);
    _add(_audioTracksCtrl, <AudioTrackInfo>[]);

    final old = _player;
    _player = null;
    _vc = null;

    final player = Player();
    if (gen != _gen || _disposed) { await player.dispose(); return; }
    _player = player;
    _vc = VideoController(player);

    // Stream listeners
    player.stream.playing.listen((p) {
      if (gen != _gen || _disposed) return;
      _add(_playing, p);
      if (p && !_started) { _started = true; _add(_buffering, false); }
    });
    player.stream.completed.listen((c) { if (gen != _gen) return; if (c) _add(_completed, true); });
    player.stream.volume.listen((v) { if (gen != _gen) return; _add(_volume, v / 100.0); });
    player.stream.position.listen((p) {
      if (gen != _gen || _disposed) return;
      _add(_position, p);
      _updateSubtitle(p);
    });
    player.stream.duration.listen((d) {
      if (gen != _gen || _disposed) return;
      _add(_duration, d);
      _live = d == Duration.zero;
    });
    player.stream.buffering.listen((b) { if (gen != _gen) return; _add(_buffering, b); });

    if (old != null) { try { await old.dispose(); } catch (_) {} }

    try {
      await player.open(Media(url, httpHeaders: headers != null && headers.isNotEmpty ? headers : null));
      if (gen != _gen || _disposed) return;

      // Keşfet: ses + altyazı track'leri
      _discoverNativeTracks();
      _discoverHlsSubtitle(url);

      // Harici altyazı
      if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
        await setExternalSubtitle(subtitleUrl);
      }

      try { await player.play(); } catch (_) {}
    } catch (e) {
      if (gen != _gen || _disposed) return;
      _lastError = 'Akış açılamadı: $e';
      _add(_error, _lastError!);
    }
  }

  /// media_kit player'dan native ses ve altyazı track'lerini keşfet
  void _discoverNativeTracks() {
    final p = _player;
    if (p == null) return;
    try {
      // Ses track'leri
      final audios = p.state.tracks.audio;
      final aTracks = <AudioTrackInfo>[];
      for (var i = 0; i < audios.length; i++) {
        final a = audios[i];
        aTracks.add(AudioTrackInfo(
          id: 'audio_$i',
          title: a.title ?? a.id ?? 'Ses ${i + 1}',
          language: a.language,
          isDefault: i == 0,
        ));
      }
      if (aTracks.isEmpty) {
        aTracks.add(const AudioTrackInfo(id: 'audio_default', title: 'Varsayılan'));
      }
      _add(_audioTracksCtrl, aTracks);
      if (aTracks.isNotEmpty) {
        _activeAudioId = aTracks.first.id;
        _add(_activeAudioTrackId, aTracks.first.id);
      }

      // Altyazı track'leri (gömülü)
      final subs = p.state.tracks.subtitle;
      final sTracks = <SubtitleInfo>[];
      for (var i = 0; i < subs.length; i++) {
        final s = subs[i];
        sTracks.add(SubtitleInfo(
          id: 'sub_$i',
          title: s.title ?? s.id ?? 'Altyazı ${i + 1}',
          language: s.language,
        ));
      }
      if (sTracks.isNotEmpty) {
        _add(_subtitleTracks, sTracks);
      }
    } catch (_) {}
  }

  /// HLS master playlist'ten altyazı parçalarını keşfet
  void _discoverHlsSubtitle(String url) {
    final lower = url.toLowerCase();
    if (!lower.contains('.m3u8') && !lower.contains('/live/') && !lower.contains('/movie/') && !lower.contains('/series/')) return;
    unawaited(_discoverHlsSubtitleAsync(url));
  }

  Future<void> _discoverHlsSubtitleAsync(String url) async {
    try {
      final tracks = await HlsSubtitleService.discoverTracks(url, headers: _headers);
      if (_disposed || tracks.isEmpty || _lastUrl != url) return;
      _hlsTracks = tracks;
      _add(_subtitleTracks, tracks.map((t) => t.toInfo()).toList());

      // Varsayılan: Türkçe
      HlsSubtitleTrack? pick;
      for (final t in tracks) { if (t.isTurkish) { pick = t; break; } }
      pick ??= tracks.where((t) => t.isDefault || t.isAutoselect).firstOrNull;
      pick ??= tracks.first;
      await setSubtitleTrackById(pick.id);
    } catch (_) {}
  }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    // HLS track
    for (final t in _hlsTracks) {
      if (t.id == id) {
        await _loadHlsTrack(t);
        _add(_activeSubtitleId, id);
        return;
      }
    }
    // Native subtitle track
    final p = _player;
    if (p == null) return;
    try {
      final subs = p.state.tracks.subtitle;
      final idx = int.tryParse(id.replaceFirst('sub_', ''));
      if (idx != null && idx < subs.length) {
        await p.setSubtitleTrack(subs[idx]);
        _add(_activeSubtitleId, id);
      }
    } catch (_) {}
  }

  Future<void> _loadHlsTrack(HlsSubtitleTrack track) async {
    _selHlsTrack = track;
    final cues = await HlsSubtitleService.loadTrackCues(track, headers: _headers);
    if (_disposed || !identical(_selHlsTrack, track)) return;
    _cues = cues;
    final p = _player;
    if (p != null) _updateSubtitle(p.state.position);

    _hlsRefresh?.cancel();
    if (_live == true) {
      _hlsRefresh = Timer.periodic(const Duration(seconds: 45), (_) {
        if (_disposed || _selHlsTrack == null) return;
        unawaited(_refreshHls(track));
      });
    }
  }

  Future<void> _refreshHls(HlsSubtitleTrack track) async {
    final fresh = await HlsSubtitleService.loadTrackCues(track, headers: _headers);
    if (_disposed || !identical(_selHlsTrack, track)) return;
    final map = <int, SubtitleCue>{};
    for (final c in _cues) { map[c.start.inMilliseconds] = c; }
    var changed = false;
    for (final c in fresh) {
      final k = c.start.inMilliseconds;
      if (!map.containsKey(k)) { map[k] = c; changed = true; }
    }
    if (changed) {
      _cues = map.values.toList()..sort((a, b) => a.start.compareTo(b.start));
      final p = _player;
      if (p != null) _updateSubtitle(p.state.position);
    }
  }

  @override
  Future<void> setAudioTrackById(String id) async {
    final p = _player;
    if (p == null) return;
    try {
      final audios = p.state.tracks.audio;
      final idx = int.tryParse(id.replaceFirst('audio_', ''));
      if (idx != null && idx < audios.length) {
        await p.setAudioTrack(audios[idx]);
        _activeAudioId = id;
        _add(_activeAudioTrackId, id);
      }
    } catch (_) {}
  }

  @override
  Future<void> setExternalSubtitle(String uri) async {
    try {
      final raw = await _fetchSub(uri);
      if (raw == null) return;
      _cues = parseSubtitleCues(raw);
      _activeSub = null;
      final p = _player;
      if (p != null) _updateSubtitle(p.state.position);
    } catch (_) {}
  }

  @override
  Future<void> disableSubtitles() async {
    _cues = const [];
    _activeSub = null;
    _add(_subtitleText, null);
    _add(_activeSubtitleId, 'off');
  }

  Future<String?> _fetchSub(String uri) async {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      final resp = await http.get(Uri.parse(uri), headers: const {'User-Agent': 'Mozilla/5.0'}).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        var body = resp.body;
        if (body.startsWith('\uFEFF')) body = body.substring(1);
        return body;
      }
    }
    if (uri.startsWith('file://')) {
      final f = File(uri.replaceFirst('file://', ''));
      if (await f.exists()) return await f.readAsString();
    }
    return null;
  }

  void _updateSubtitle(Duration pos) {
    if (_cues.isEmpty) return;
    String? text;
    for (final c in _cues) {
      if (pos >= c.start && pos <= c.end) { text = c.text; break; }
    }
    if (text != _activeSub) { _activeSub = text; _add(_subtitleText, text); }
  }

  @override Future<void> play() async { try { await _player?.play(); } catch (_) {} }
  @override Future<void> pause() async { try { await _player?.pause(); } catch (_) {} }
  @override Future<void> seek(Duration pos) async { try { await _player?.seek(pos); } catch (_) {} }
  @override Future<void> setVolume(double v) async { try { await _player?.setVolume(v * 100.0); } catch (_) {} _add(_volume, v); }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _gen++;
    _hlsRefresh?.cancel();
    final p = _player;
    _player = null;
    _vc = null;
    if (p != null) { try { await p.dispose(); } catch (_) {} }
    for (final sc in [_buffering, _error, _playing, _volume, _position, _duration, _completed, _subtitleTracks, _subtitleText, _activeSubtitleId, _audioTracksCtrl, _activeAudioTrackId]) {
      if (!sc.isClosed) await sc.close();
    }
  }
}

// ==================== Altyazı Parser ====================

class SubtitleCue {
  SubtitleCue(this.start, this.end, this.text);
  final Duration start;
  final Duration end;
  final String text;
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
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      textLines.add(lines[i].trim());
      i++;
    }
    if (textLines.isNotEmpty) cues.add(_SubCue(start, end, textLines.join('\n')));
  }
  return cues;
}

Duration _cueTime(String h, String m, String s, String ms) {
  var millis = ms.padRight(3, '0');
  if (millis.length > 3) millis = millis.substring(0, 3);
  return Duration(hours: int.parse(h), minutes: int.parse(m), seconds: int.parse(s), milliseconds: int.parse(millis));
}

class _SubCue {
  _SubCue(this.start, this.end, this.text);
  final Duration start;
  final Duration end;
  final String text;
}
