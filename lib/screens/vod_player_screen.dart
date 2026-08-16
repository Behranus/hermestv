import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/services/stream_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tek bir medya (film/bölüm) için kaydırıcılı, ileri/geri sarmalı oynatıcı.
/// **ExoPlayer** (resmi video_player) motorunu kullanır.
class VodPlayerScreen extends StatefulWidget {
  const VodPlayerScreen({super.key, required this.url, required this.title});

  final String url;
  final String title;

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

  @override
  void initState() {
    super.initState();
    // Film/dizi için daha büyük tampon → akıcı oynatma, az yeniden yükleme.
    _player = createStreamPlayer(bufferSecs: 2.0);
    _subscribe();
    WakelockPlus.enable();
    try {
      unawaited(_player.open(widget.url));
    } catch (e) {
      _error = 'Akış açılamadı: $e';
    }
    _scheduleOverlayHide();
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    WakelockPlus.disable();
    unawaited(_player.dispose());
    super.dispose();
  }

  void _subscribe() {
    _player.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    });
    _player.error.listen((e) {
      if (mounted) setState(() => _error = e);
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
      if (mounted) setState(() => _duration = d);
    });
    // Ekran üstü altyazı (SRT/VTT).
    _player.subtitleText.listen((text) {
      if (mounted) setState(() => _subtitleText = text);
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
