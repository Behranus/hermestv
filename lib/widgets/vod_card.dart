import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Film/dizi poster kartı: tanıtım görseli, IMDb puanı rozeti ve başlık.
/// Android TV için odak (D-pad) desteği vardır.
class VodCard extends StatefulWidget {
  const VodCard({
    super.key,
    required this.title,
    required this.onTap,
    this.imageUrl,
    this.rating,
    this.subtitle,
    this.autofocus = false,
  });

  final String title;
  final String? imageUrl;
  final String? rating;
  final String? subtitle;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<VodCard> createState() => _VodCardState();
}

class _VodCardState extends State<VodCard> {
  final _focusNode = FocusNode(debugLabel: 'vod-card');

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _focused => _focusNode.hasFocus;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rating = widget.rating;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? colors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _poster(context),
                // Alt karartma: başlığın okunması için.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
                if (rating != null && rating.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            rating,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _poster(BuildContext context) {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) return _placeholder(context);
    return Image.network(
      url,
      fit: BoxFit.cover,
      // Kart boyutu için düşük çözünürlükte çöz → 2GB RAM'li Box'larda
      // yüzlerce posteri bellekten beslemek kasma yapmasın.
      cacheWidth: 300,
      errorBuilder: (_, _, _) => _placeholder(context),
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?';
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: colors.primary),
        ),
      ),
    );
  }
}
