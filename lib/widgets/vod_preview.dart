import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iptv_player/services/stream_player.dart';

/// VOD kartında 5 saniye odaklanınca küçük pencerede video preview.
/// Netflix tarzı: kart büyür, küçük oynatıcı açılır.
class VodPreviewOverlay extends StatefulWidget {
  const VodPreviewOverlay({
    super.key,
    required this.url,
    required this.title,
    required this.poster,
    required this.child,
    this.focusNode,
    this.onTap,
    this.delay = const Duration(seconds: 5),
  });

  /// Oynatılacak URL (HLS m3u8 veya mp4).
  final String? url;
  final String title;
  final String? poster;

  /// Kart çocuğu (poster + başlık).
  final Widget child;

  /// Odak düğümü (dışarıdan kontrol edilebilir).
  final FocusNode? focusNode;

  /// Dokunma/tıklama.
  final VoidCallback? onTap;

  /// Preview başlamadan önce bekleme süresi.
  final Duration delay;

  @override
  State<VodPreviewOverlay> createState() => _VodPreviewOverlayState();
}

class _VodPreviewOverlayState extends State<VodPreviewOverlay>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focus;
  Timer? _previewTimer;
  bool _showPreview = false;
  StreamPlayer? _player;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _disposePlayer();
    if (widget.focusNode == null) {
      _focus.dispose();
    } else {
      _focus.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focus.hasFocus;
    if (hasFocus && !_hasFocus) {
      // Odak geldi → timer başlat
      _hasFocus = true;
      _startPreviewTimer();
    } else if (!hasFocus && _hasFocus) {
      // Odak gitti → preview'ı kapat
      _hasFocus = false;
      _cancelPreview();
    }
  }

  void _startPreviewTimer() {
    _previewTimer?.cancel();
    if (widget.url == null || widget.url!.isEmpty) return;
    _previewTimer = Timer(widget.delay, () {
      if (mounted && _hasFocus) {
        _startPreview();
      }
    });
  }

  void _cancelPreview() {
    _previewTimer?.cancel();
    if (_showPreview) {
      _disposePlayer();
      if (mounted) setState(() => _showPreview = false);
    }
  }

  void _startPreview() {
    if (widget.url == null || widget.url!.isEmpty) return;
    _disposePlayer();
    _player = createStreamPlayer(bufferSecs: 0.5);
    _player!.open(widget.url!);
    if (mounted) setState(() => _showPreview = true);
  }

  void _disposePlayer() {
    if (_player != null) {
      unawaited(_player!.dispose());
      _player = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hasFocus ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              // Preview overlay
              if (_showPreview && _player != null)
                Positioned.fill(
                  child: _PreviewPlayer(player: _player!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Küçük video oynatıcı overlay'i.
class _PreviewPlayer extends StatelessWidget {
  const _PreviewPlayer({required this.player});
  final StreamPlayer player;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 320,
              height: 180,
              child: player.buildVideo(fit: BoxFit.cover),
            ),
          ),
          // Play indicator
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white54, size: 36),
          ),
          // Gradient overlay
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black38, Colors.transparent, Colors.black54],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
