import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_player/services/stream_player.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

/// Linux masaüstü oynatıcı: media_kit (libmpv).
class MediaKitStreamPlayer extends StreamPlayer {
  MediaKitStreamPlayer({required this.bufferSecs});

  mk.Player? _player;
  mkv.VideoController? _videoController;
  int _generation = 0;
  bool _disposed = false;
  double _pendingVolume = 1.0;
  bool? _live;
  String? _lastError;
  String? _streamInfo;
  bool _startedPlaying = false;
  Duration _lastPosition = Duration.zero;

  List<SubtitleCue> _cues = const [];
  String? _activeSubtitle;
  List<mk.SubtitleTrack> _nativeSubtitleTracks = const [];

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
  bool? get isLive => _live;
  @override
  String? get streamInfo => _streamInfo;
  @override
  double bufferSecs;

  void _initPlayer() {
    if (_player != null) return;
    final player = mk.Player();
    _player = player;
    _videoController = mkv.VideoController(player);

    player.stream.buffering.listen((b) {
      if (!_disposed) _buffering.add(b);
    });
    player.stream.playing.listen((p) {
      if (_disposed) return;
      if (p && !_startedPlaying) {
        _startedPlaying = true;
        _buffering.add(false);
        _captureStreamInfo();
      }
      _playing.add(p);
    });
    player.stream.error.listen((e) {
      if (_disposed) return;
      if (e != _lastError) {
        _lastError = e;
        _error.add(e);
      }
    });
    player.stream.position.listen((pos) {
      if (_disposed) return;
      _lastPosition = pos;
      _position.add(pos);
      _updateSubtitleAt(pos);
    });
    player.stream.duration.listen((d) {
      if (_disposed) return;
      if (d > Duration.zero) _live = false;
      _duration.add(d);
    });
    player.stream.volume.listen((v) {
      if (!_disposed) _volume.add(v);
    });
    player.stream.completed.listen((c) {
      if (!_disposed) _completed.add(c);
    });
    player.stream.width.listen((w) {
      if (!_disposed && w != null && w > 0) _captureStreamInfo();
    });
    player.stream.height.listen((h) {
      if (!_disposed && h != null && h > 0) _captureStreamInfo();
    });
    player.stream.tracks.listen((tracks) {
      if (_disposed) return;
      final subs = tracks.subtitle
          .where((t) => t.id != 'auto' && t.id != 'no')
          .toList();
      if (subs.isEmpty) return;
      _nativeSubtitleTracks = subs;
      _subtitleTracks.add(subs
          .map((t) => SubtitleInfo(
                id: t.id,
                title: t.title ?? '',
                language: t.language,
              ))
          .toList());
      _activeSubtitleId.add(subs.first.id);
    });
  }

  void _captureStreamInfo() {
    if (_streamInfo != null) return;
    final w = _player?.state.width;
    final h = _player?.state.height;
    if ((w ?? 0) > 0 && (h ?? 0) > 0) {
      _streamInfo = '$w×$h';
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
    _nativeSubtitleTracks = const [];

    _initPlayer();
    final player = _player!;

    // Tamamen saf Media — extras yok, sadece header
    final media = mk.Media(
      url,
      httpHeaders: headers ?? const {
        'User-Agent': 'VLC/3.0.21 LibVLC/3.0.21',
      },
    );

    try {
      await player.open(media);
    } catch (e) {
      if (gen != _generation || _disposed) return;
      _lastError = 'Akış açılamadı: $e';
      _error.add(_lastError!);
      return;
    }
    if (gen != _generation || _disposed) return;

    _live = (_player?.state.duration ?? Duration.zero) == Duration.zero;

    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      await setExternalSubtitle(subtitleUrl);
    }

    try {
      await player.setVolume(_pendingVolume);
    } catch (_) {}
    try {
      await player.play();
    } catch (_) {}
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    final vc = _videoController;
    if (vc == null) return const SizedBox.shrink();
    return mkv.Video(controller: vc, fit: fit);
  }

  @override
  Future<void> play() async {
    try { await _player?.play(); } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try { await _player?.pause(); } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    try { await _player?.seek(position); } catch (_) {}
  }

  @override
  Future<void> setVolume(double v) async {
    _pendingVolume = v.clamp(0.0, 1.0);
    try { await _player?.setVolume(_pendingVolume); } catch (_) {}
  }

  @override
  Future<void> setExternalSubtitle(String uri) async {
    try {
      final raw = await _fetchSubtitle(uri);
      if (raw == null) return;
      _cues = parseSubtitleCues(raw);
      _activeSubtitle = null;
      _updateSubtitleAt(_lastPosition);
    } catch (_) {}
  }

  @override
  Future<void> disableSubtitles() async {
    _cues = const [];
    _activeSubtitle = null;
    _subtitleText.add(null);
    _activeSubtitleId.add('off');
    try {
      await _player?.setSubtitleTrack(const mk.SubtitleTrack('no', null, null));
    } catch (_) {}
  }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    for (final t in _nativeSubtitleTracks) {
      if (t.id == id) {
        try {
          await _player?.setSubtitleTrack(t);
          _activeSubtitleId.add(id);
        } catch (_) {}
        return;
      }
    }
  }

  Future<String?> _fetchSubtitle(String uri) async {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      final resp = await http
          .get(Uri.parse(uri), headers: const {
            'User-Agent': 'VLC/3.0.21 LibVLC/3.0.21',
          })
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
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
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) {
      try { await player.dispose(); } catch (_) {}
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
  }
}
