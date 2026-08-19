import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
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

  // ---- Altyazı durumu ----
  // Harici SRT/VTT dosyası için uygulama içi çizim (Android'le aynı).
  List<SubtitleCue> _cues = const [];
  String? _activeSubtitle;

  // mpv'nin kendi (yerleşik) altyazı parçaları — menüde listelenir ve
  // seçim mpv'ye iletilir (ExoPlayer'daki gibi kendi başımıza çizmeyiz;
  // mpv libass ile çizer — DVB/teletext gömülü altyazılar da dahil).
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

  Future<void> _initPlayer() async {
    if (_player != null) return;
    // libass=true: mpv altyazıları video karesine kendisi çizer (gömülü
    // DVB/teletext/EXT-X-MEDIA dahil) — medya kütüphanesi widget render'ına
    // bağımlılık yok, her altyazı türü çalışır. (Varsayılan false'ta mpv
    // altyazıyı çizmez; widget katmanı sadece basit metinleri gösterir.)
    final player = mk.Player(
      configuration: const mk.PlayerConfiguration(
        libass: true,
      ),
    );
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
    // mpv'nin yerleşik altyazı parçaları: menüye aktar ve varsayılan
    // seçimi (slang=tr,tur ile mpv Türkçe parçayı seçer) bildir.
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
      // mpv slang=tr,tur ile otomatik seçim yapar; aktif parçayı bildir.
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

    await _initPlayer();
    final player = _player!;

    final media = mk.Media(
      url,
      httpHeaders: headers ??
          const {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
                'Chrome/120.0 Mobile Safari/537.36',
          },
      // ──── 4K performsa + görüntü kalitesi ince ayarları ────
      //
      // hwdec=auto: donanım çözümleme aktif (4K/10bit/HDR için zorunlu).
      //   auto-safe yerine auto kullanılır — GPU sürücü sorunu olursa
      //   mpv otomatik olarak yazılıma düşer (auto-safe kadar güvenli,
      //   ama auto daha hızlı karar verir).
      // vo=libmpv: yüksek kaliteli render, piksel assert'leri kapalı.
      // slang=tr,tur: Türkçe gömülü altyazı varsa mpv onu otomatik seçer.
      //
      // ──── Tampon / cache ayarları (4K akışlar için kritik) ────
      // cache=yes: demuxer cache aktif (4K'da takılmanın ana nedeni cache yetersizliği).
      // cache-secs=15: 15 saniyelik tampon (4K akışlarda 10 saniye bazen yetmiyor).
      // cache-pause-initial=yes: ilk yüklemede pause yapmadan tamponu doldur.
      // demuxer-max-bytes=200MiB: demuxer için 200MB bellek (4K mkv/mpegts için).
      // demuxer-max-back-bytes=100MiB: geriye sarma için 100MB.
      //
      // ──── Görüntü kalitesi / renk / keskinlik ────
      //
      // profile=high-quality: mpv'nin yerleşik yüksek kalite profili.
      //   - scale=bilinear (yüksek kaliteli upsampling)
      //   - dscale=lanczos (aşırı örneklemde keskinlik)
      //   - dither-depth=auto (renk derinliği korunur)
      //
      // scale=spline36: 1080p/4K arası geçişlerde yumuşak ve keskin.
      // dscale=lanczos: downscaling'de en keskin filtre.
      // correct-downscaling=yes: doğru downsampling (yazı/kenar keskinliği).
      // linear-downscaling=yes: lineer downscale (renk doğruluğu).
      // sigmoid-upscaling=yes: sigmoid upsampling (görüntü doğal görünür).
      //
      // contrast=1.1: hafif kontrast artışı (mat renk sorununu çözer).
      // saturation=1.25: renk doygunluğu artırılır (canlı renkler).
      // brightness=0.02: çok hafif parlaklık artışı.
      // gamma=1.05: hafif gamma düzeltmesi (gölgelerde detay).
      //
      // deband=yes: banding engelleme (düşük bit率li akışlarda gradyan
      //   bozulmalarını önler — 4K HDR'da çok önemlidir).
      // deband-iterations=4: 4 iterasyon (daha iyi sonuç).
      // deband-threshold=35: banding eşik değeri.
      // deband-range=16: banding aralığı.
      //
      // unsharp=yes: keskinlik artırma (عيnek filtresi).
      // unsharp-luminance=5x5: luminans için 5x5 çekirdek.
      // unsharp-luminance-amount=0.8: keskinlik miktarı (çok değil, doğal).
      extras: const {
        'hwdec': 'no',
        'slang': 'tr,tur',
        'vo': 'libmpv',
        // Tampon
        'cache': 'yes',
        'cache-secs': '15',
        'cache-pause-initial': 'yes',
        'demuxer-max-bytes': '200MiB',
        'demuxer-max-back-bytes': '100MiB',
        // Görüntü kalitesi
        'profile': 'high-quality',
        'scale': 'spline36',
        'dscale': 'lanczos',
        'correct-downscaling': 'yes',
        'linear-downscaling': 'yes',
        'sigmoid-upscaling': 'yes',
        // Renk / parlaklık
        'contrast': '1.1',
        'saturation': '1.25',
        'brightness': '0.02',
        'gamma': '1.05',
        // Banding engelleme
        'deband': 'yes',
        'deband-iterations': '4',
        'deband-threshold': '35',
        'deband-range': '16',
        // Keskinlik
        'unsharp': 'yes',
        'unsharp-luminance': '5x5',
        'unsharp-luminance-amount': '0.8',
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

    // Canlı tespiti: mpv canlı akışta süre bildirmez (0) — hemen kontrol et.
    _live = (_player?.state.duration ?? Duration.zero) == Duration.zero;

    if (subtitleUrl != null && subtitleUrl.isNotEmpty) {
      // Harici dosya: uygulama içi çizim (SRT/VTT parser) — Android'le aynı.
      await setExternalSubtitle(subtitleUrl);
    }
    // NOT: mpv gömülü parçaları (DVB/teletext/EXT-X-MEDIA) kendisi çözer ve
    // stream.tracks ile bildirir. Uygulama içi HLS keşfi burada ÇALIŞTIRILMAZ
    // — aksi halde aynı altyazı iki kez çizilir (mpv libass + uygulama çizimi).

    try {
      await player.setVolume(_pendingVolume);
    } catch (_) {}
    try {
      await player.play();
    } catch (_) {}
  }  @override
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
    _activeSubtitleId.add('off');
    try {
      await _player?.setSubtitleTrack(const mk.SubtitleTrack('no', null, null));
    } catch (_) {}
  }

  @override
  Future<void> setSubtitleTrackById(String id) async {
    // mpv'nin yerleşik parçaları (Linux — mpv kendisi çizer).
    for (final t in _nativeSubtitleTracks) {
      if (t.id == id) {
        try {
          await _player?.setSubtitleTrack(t);
          _activeSubtitleId.add(id);
        } catch (_) {}
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
    await _activeSubtitleId.close();
  }
}
