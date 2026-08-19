import 'dart:async';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/screens/subtitle_search_screen.dart';
import 'package:iptv_player/services/resume_service.dart';
import 'package:iptv_player/services/stream_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tek bir medya (film/bölüm) için kaydırıcılı, ileri/geri sarmalı oynatıcı.
/// **ExoPlayer** (resmi video_player) motorunu kullanır.
/// Kaldığın yerden devam: izleme kaydı otomatik kaydedilir.
class VodPlayerScreen extends StatefulWidget {
  const VodPlayerScreen({
    super.key,
    required this.url,
    required this.title,
    this.mediaId,
    this.poster,
    this.isMovie = true,
    this.resumePosition,
  });

  final String url;
  final String title;

  /// VOD media ID'si (resume için gerekli).
  final int? mediaId;
  final String? poster;
  final bool isMovie;

  /// Devam edilecek konum (sıfırdan başlamıyorsa).
  final Duration? resumePosition;

  @override
  State<VodPlayerScreen> createState() => _VodPlayerScreenState();
}

class _VodPlayerScreenState extends State<VodPlayerScreen> {
  late final StreamPlayer _player;

  bool _buffering = true;
  String? _error;
  bool _overlayVisible = true;
  Timer? _overlayTimer;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _dragging = false;
  double _dragValue = 0;
  DateTime _lastPositionAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _subtitleText;
  List<SubtitleInfo> _subtitleTracks = [];
  String? _activeSubtitleId;

  /// Denenecek adaylar: ilk aday ana URL; Xtream filmleri açılmazsa
  /// aynı kimlikle diğer uzantılar (m3u8 ↔ mp4/mkv) otomatik denenir.
  late final List<String> _candidates;
  int _candidateIndex = 0;

  /// Resume için zamanlayıcı: her 10 saniyede bir konumu kaydet.
  Timer? _resumeTimer;
  bool _resumeApplied = false;

  /// URL'nin son uzantısını değiştirerek yedek adaylar üretir.
  /// Örn. `{base}/movie/u/p/123.m3u8` → ayrıca .mp4 ve .mkv denenir.
  static List<String> _alternates(String url) {
    final dot = url.lastIndexOf('.');
    final slash = url.lastIndexOf('/');
    if (dot <= slash || dot == url.length - 1) return const [];
    final base = url.substring(0, dot + 1);
    final cur = url.substring(dot + 1).toLowerCase();
    const known = ['m3u8', 'mp4', 'mkv', 'avi', 'mov', 'webm'];
    final alts = <String>[];
    for (final e in known) {
      if (e != cur) alts.add('$base$e');
    }
    return alts;
  }

  @override
  void initState() {
    super.initState();
    // Film/dizi için daha büyük tampon → akıcı oynatma, az yeniden yükleme.
    _player = createStreamPlayer(bufferSecs: 2.0);
    _subscribe();
    WakelockPlus.enable();
    _candidates = [widget.url, ..._alternates(widget.url)];
    _openCandidate();
    _scheduleOverlayHide();
    // Resume: her 10 saniyede bir konumu kaydet.
    _resumeTimer = Timer.periodic(const Duration(seconds: 10), (_) => _saveResume());
  }

  /// Sıradaki adayı açar; hepsi başarısız olursa hata gösterilir.
  void _openCandidate() {
    if (_candidateIndex >= _candidates.length) return;
    final url = _candidates[_candidateIndex];
    setState(() {
      _buffering = true;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    try {
      unawaited(_player.open(url));
    } catch (e) {
      _nextCandidate('Akış açılamadı: $e');
    }
  }

  /// Hata olursa sıradaki yedek uzantıyı dener; biterse hatayı gösterir.
  void _nextCandidate(String message) {
    if (!mounted) return;
    _candidateIndex++;
    if (_candidateIndex < _candidates.length) {
      _openCandidate();
    } else {
      setState(() => _error = message);
    }
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _resumeTimer?.cancel();
    _saveResume(); // Çıkarken son konumu kaydet.
    WakelockPlus.disable();
    unawaited(_player.dispose());
    super.dispose();
  }

  /// Mevcut izleme konumunu disk'e kaydet.
  void _saveResume() {
    if (widget.mediaId == null) return;
    if (_position.inSeconds < 3) return; // Çok kısaysa kaydetme.
    if (_duration.inSeconds == 0) return;
    ResumeService.save(ResumeRecord(
      id: widget.mediaId!,
      title: widget.title,
      poster: widget.poster,
      url: widget.url,
      position: _position,
      duration: _duration,
      isMovie: widget.isMovie,
      watchedAt: DateTime.now(),
    ));
  }

  void _subscribe() {
    _player.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    });
    _player.error.listen((e) {
      if (!mounted) return;
      if (!_playing && _candidateIndex < _candidates.length) {
        _nextCandidate(e);
      } else {
        setState(() => _error = e);
      }
    });
    _player.playing.listen((p) {
      if (mounted) setState(() => _playing = p);
    });
    // Saniyede en fazla ~5 kez güncelle (her karede setState → takılma).
    _player.position.listen((p) {
      if (!mounted || _dragging) return;
      if (!_overlayVisible) return;
      final now = DateTime.now();
      if (now.difference(_lastPositionAt) < const Duration(milliseconds: 200)) return;
      _lastPositionAt = now;
      setState(() => _position = p);
    });
    _player.duration.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
      // Resume: süre belli olduğunda kaydedilmiş konuma atla.
      if (!_resumeApplied && widget.resumePosition != null &&
          widget.resumePosition!.inSeconds > 5 &&
          d.inSeconds > 0 && _position.inSeconds < 3) {
        _resumeApplied = true;
        _player.seek(widget.resumePosition!);
        setState(() => _position = widget.resumePosition!);
      }
    });
    // Ekran üstü altyazı (SRT/VTT).
    _player.subtitleText.listen((text) {
      if (mounted) setState(() => _subtitleText = text);
    });
    // HLS akışındaki gömülü altyazı parçaları (menü için).
    _player.subtitleTracks.listen((tracks) {
      if (mounted) setState(() => _subtitleTracks = tracks);
    });
    // Otomatik seçilen parça (örn. Türkçe) menüde işaretli gelsin.
    _player.activeSubtitleId.listen((id) {
      if (mounted && id != null) setState(() => _activeSubtitleId = id);
    });
    _player.completed.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _overlayVisible && !_buffering && _error == null) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
    if (_overlayVisible) _scheduleOverlayHide();
  }

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    _scheduleOverlayHide();
  }

  Future<void> _showSubtitlesMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _VodSubtitlesSheet(
        tracks: _subtitleTracks,
        activeId: _activeSubtitleId,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == 'off') {
      await _player.disableSubtitles();
      setState(() => _activeSubtitleId = 'off');
    } else if (selected == 'file') {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub'],
      );
      if (result.isEmpty || !mounted) return;
      final path = result.first.path;
      if (path == null) return;
      await _player.setExternalSubtitle('file://$path');
      setState(() => _activeSubtitleId = 'file://$path');
    } else if (selected == 'opensubtitles') {
      // OpenSubtitles arama sayfasına git
      if (!mounted) return;
      final result = await Navigator.of(context).push<SubtitleDownloadResult>(
        MaterialPageRoute(
          builder: (_) => SubtitleSearchScreen(movieName: widget.title),
        ),
      );
      if (result != null && mounted) {
        // SRT içediğini dosyaya yaz ve yükle
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/subtitle_open.${result.format.toLowerCase()}');
        await file.writeAsString(result.content);
        await _player.setExternalSubtitle('file://${file.path}');
        setState(() => _activeSubtitleId = 'file://${file.path}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${result.fileName} yüklendi')),
          );
        }
      }
    } else {
      // HLS gömülü parça seçimi.
      await _player.setSubtitleTrackById(selected);
      setState(() => _activeSubtitleId = selected);
    }
  }

  Future<void> _seekBy(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);
    await _player.seek(clamped);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _seekBy(10);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space) {
      _toggleOverlay();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = _duration.inMilliseconds.toDouble();
    final positionMs = _position.inMilliseconds.toDouble();
    final sliderValue = _dragging
        ? _dragValue
        : (durationMs > 0 ? positionMs.clamp(0, durationMs).toDouble() : 0.0);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleOverlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _player.buildVideo(fit: BoxFit.contain),
              // Ekran üstü altyazı (SRT/VTT dosyası yüklendiyse).
              if (_subtitleText != null && _subtitleText!.isNotEmpty)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 70,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _subtitleText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.3,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_buffering && _error == null)
                const ColoredBox(
                  color: Colors.black54,
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                ColoredBox(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
                        const SizedBox(height: 12),
                        const Text('Akış açılamadı', style: TextStyle(color: Colors.white, fontSize: 18)),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Geri'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_overlayVisible && _error == null)
                Column(
                  children: [
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              tooltip: 'Geri',
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Altyazı menüsü (HLS gömülü parçalar + dosyadan yükleme).
                            IconButton(
                              onPressed: _showSubtitlesMenu,
                              tooltip: 'Altyazılar',
                              icon: Icon(
                                _activeSubtitleId != null && _activeSubtitleId != 'off'
                                    ? Icons.subtitles
                                    : Icons.subtitles_off,
                                color: _activeSubtitleId != null &&
                                        _activeSubtitleId != 'off'
                                    ? Colors.amber
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Kontrol çubuğu
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Zaman çubuğu
                            Slider(
                              value: sliderValue,
                              max: durationMs > 0 ? durationMs : 1,
                              onChangeStart: (_) => setState(() => _dragging = true),
                              onChanged: (v) => setState(() => _dragValue = v),
                              onChangeEnd: (v) async {
                                setState(() {
                                  _dragging = false;
                                  _position = Duration(milliseconds: v.round());
                                });
                                await _player.seek(Duration(milliseconds: v.round()));
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  Text(
                                    _fmt(_dragging
                                        ? Duration(milliseconds: _dragValue.round())
                                        : _position),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _fmt(_duration),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  onPressed: () => _seekBy(-10),
                                  tooltip: '-10 sn',
                                  icon: const Icon(Icons.replay_10, color: Colors.white, size: 34),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: _togglePlay,
                                  tooltip: _playing ? 'Duraklat' : 'Oynat',
                                  iconSize: 52,
                                  icon: Icon(
                                    _playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  onPressed: () => _seekBy(10),
                                  tooltip: '+10 sn',
                                  icon: const Icon(Icons.forward_10, color: Colors.white, size: 34),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// VOD altyazı seçim sayfası (HLS gömülü parçalar + dosyadan yükleme).
class _VodSubtitlesSheet extends StatelessWidget {
  const _VodSubtitlesSheet({required this.tracks, required this.activeId});

  final List<SubtitleInfo> tracks;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStreamTracks = tracks.isNotEmpty;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Altyazılar', style: theme.textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.subtitles_off),
            title: const Text('Kapalı'),
            trailing: activeId == null || activeId == 'off'
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () => Navigator.of(context).pop('off'),
          ),
          if (hasStreamTracks) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Akış altyazıları', style: theme.textTheme.labelLarge),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tracks.length,
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  final label = [t.title, t.language]
                      .whereType<String>()
                      .where((s) => s.isNotEmpty)
                      .join(' • ');
                  return ListTile(
                    leading: const Icon(Icons.subtitles),
                    title: Text(label.isEmpty ? 'Parça ${i + 1}' : label),
                    trailing: activeId == t.id
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => Navigator.of(context).pop(t.id),
                  );
                },
              ),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language, color: Colors.amber),
            title: const Text('OpenSubtitles\'da ara'),
            subtitle: const Text('İnternette altyazı bul ve yükle'),
            onTap: () => Navigator.of(context).pop('opensubtitles'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Dosyadan altyazı yükle'),
            subtitle: const Text('SRT, VTT, ASS, SSA, SUB'),
            onTap: () => Navigator.of(context).pop('file'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
