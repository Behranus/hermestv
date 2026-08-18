import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_player/services/hls_subtitle_service.dart';
import 'package:iptv_player/services/stream_player.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart' as mkv;

/// **Linux masaüstü** için oynatıcı motoru: media_kit (libmpv).
///
/// Android'de kullanılan resmi `video_player` (ExoPlayer) eklentisinin Linux
/// uygulaması yoktur — bu yüzden Linux'ta media_kit kullanılır. media_kit,
/// libmpv üzerine kuruludur (IPTV/HLS canlı yayınlarda çok sağlam, tüm yaygın
/// kapsayıcıları çözer).
///
/// **Çökme güvenliği (sistem restartına yol açan AMD GPU sürücü çökmeleri):**
/// - mpv'nin **donanım hızlandırmalı video çözme** (VAAPI/VDPAU) özelliği
///   kapatılır (`hwdec=no`). AMD Radeon sürücülerinde VAAPI, GPU sürücü
///   çökmesine (ekran kararması / sistem restartı) yol açabilir. Yazılım
///   çözme CPU ile yapılır — FHD akıcıdır, 4K'da bile kararlıdır.
/// - Render (Skia/OpenGL) tarafındaki Impeller/Vulkan çökmesi ayrıca
///   `linux/runner/my_application.cc` içinde kapatılmıştır.
///
/// Arayüz [StreamPlayer] ile aynıdır; Android'deki ExoStreamPlayer ile aynı
/// altyazı akışı (HLS parça keşfi + SRT/VTT çözümleme + Türkçe çeviri)
/// kullanılır — ekran üstü altyazı çizimi aynı kalır.
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

  // ---- Altyazı durumu (ExoStreamPlayer ile aynı yaklaşım) ----
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

  Future<void> _initPlayer() async {
    if (_player != null) return;
    final player = mk.Player();
    _player = player;
    _videoController = mkv.VideoController(player);

    // ÇÖKME GÜVENLİĞİ: AMD Radeon sürücülerinde VAAPI donanım çözme GPU
    // sürücü çökmesine (sistem restartı) yol açabilir — yazılım çözmeye geç.
    // (hwdec ayrıca `Media.extras` ile de iletilir — open() içinde.)

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
      // Canlı tespiti: mpv canlıda süre 0 verir (veya değişmez).
      if (d > Duration.zero) _live = false;
      _duration.add(d);
    });
    player.stream.volume.listen((v) {
      if (!_disposed) _volume.add(v);
    });
    player.stream.completed.listen((c) {
      if (!_disposed) _completed.add(c);
    });
    // Çözünürlük bilgisi (HUD): akış açılınca width/height gelir.
    player.stream.width.listen((w) {
      if (!_disposed && w != null && w > 0) _captureStreamInfo();
    });
    player.stream.height.listen((h) {
      if (!_disposed && h != null && h > 0) _captureStreamInfo();
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
    _headers = headers;
    _lastUrl = url;
    _hlsSubtitleRefresh?.cancel();
    _hlsSubtitleRefresh = null;

    await _initPlayer();
    final player = _player!;

    final media = mk.Media(
      url,
      httpHeaders: headers ??
          const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
                'Chrome/120.0 Mobile Safari/537.36',
          },
      // mpv'nin kendi altyazı çizimini kapat: altyazılar uygulama içinde
      // çizilir (Android davranışıyla aynı; çift altyazı olmasın).
      // hwdec=no: donanım çözme kapalı (yazılım çözme — GPU sürücü güvenliği).
      extras: const {'sid': 'no', 'hwdec': 'no'},
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

    // Canlı tespiti: mpv canlı akışta süre bildirmez (0) — hemen kontrol et.
    _live = (_player?.state.duration ?? Duration.zero) == Duration.zero;

    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      await setExternalSubtitle(subtitleUrl);
    } else {
      unawaited(_discoverHlsSubtitles(url));
    }

    try {
      await player.setVolume(_pendingVolume);
    } catch (_) {}
    try {
      await player.play();
    } catch (_) {}
  }

  /// HLS master playlist'ten altyazı parçalarını bulur ve varsayılan olarak
  /// Türkçe parçayı (yoksa ilk parçayı) otomatik seçer. (ExoStreamPlayer ile
  /// aynı — motor bağımsız, sadece HLS playlist ayrıştırması.)
  Future<void> _discoverHlsSubtitles(String url) async {
    if (!url.toLowerCase().endsWith('.m3u8')) return;
    final tracks = await HlsSubtitleService.discoverTracks(url, headers: _headers);
    if (_disposed || tracks.isEmpty) return;
    if (_lastUrl != url) return; // Kanal değiştiyse eski sonucu yoksay.
    _hlsTracks = tracks;
    _subtitleTracks.add(tracks.map((t) => t.toInfo()).toList());

    HlsSubtitleTrack? pick;
    for (final t in tracks) {
      if (t.isTurkish) {
        pick = t;
        break;
      }
    }
    pick ??= tracks.where((t) => t.isDefault || t.isAutoselect).firstOrNull;
    pick ??= tracks.first;
    await setSubtitleTrackById(pick.id);
  }

  Future<void> _loadHlsTrack(HlsSubtitleTrack track) async {
    _selectedHlsTrack = track;
    final cues = await HlsSubtitleService.loadTrackCues(track, headers: _headers);
    if (_disposed) return;
    if (!identical(_selectedHlsTrack, track)) return; // Başka parça seçildi.
    _cues = cues;
    _updateSubtitleAt(_lastPosition);

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
    for (final c in _cues) {
      byStart[c.start.inMilliseconds] = c;
    }
    var changed = false;
    for (final c in fresh) {
      final k = c.start.inMilliseconds;
      if (!byStart.containsKey(k)) {
        byStart[k] = c;
        changed = true;
      }
    }
    if (changed) {
      _cues = byStart.values.toList()..sort((a, b) => a.start.compareTo(b.start));
      _updateSubtitleAt(_lastPosition);
    }
  }

  @override
  Widget buildVideo({BoxFit fit = BoxFit.contain}) {
    final vc = _videoController;
    if (vc == null) return const SizedBox.shrink();
    return mkv.Video(controller: vc, fit: fit);
  }

  @override
  Future<void> play() async {
    try {
      await _player?.play();
    } catch (_) {}
  }

  @override
  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (_) {}
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double v) async {
    _pendingVolume = v.clamp(0.0, 1.0);
    try {
      await _player?.setVolume(_pendingVolume);
    } catch (_) {}
  }

  // ---- Altyazı ----

  @override
  Future<void> setExternalSubtitle(String uri) async {
    try {
      final raw = await _fetchSubtitle(uri);
      if (raw == null) return;
      _cues = parseSubtitleCues(raw);
      _activeSubtitle = null;
      _updateSubtitleAt(_lastPosition);
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
    for (final t in _hlsTracks) {
      if (t.id == id) {
        await _loadHlsTrack(t);
        return;
      }
    }
    // Bilinmeyen id'yi yoksay.
  }

  Future<String?> _fetchSubtitle(String uri) async {
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      final resp = await http
          .get(Uri.parse(uri), headers: const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
                'Chrome/120.0 Mobile Safari/537.36',
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
    _hlsSubtitleRefresh?.cancel();
    _hlsSubtitleRefresh = null;
    final player = _player;
    _player = null;
    _videoController = null;
    if (player != null) {
      try {
        await player.dispose();
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
