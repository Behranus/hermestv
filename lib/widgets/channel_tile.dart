import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermestv/models/channel.dart';

/// Modern kanal tile - TiviMate tarzi minimal tasarim
/// Android TV / Box uzaktan kumandasi (D-pad) navigasyonu destekler
class ChannelTile extends StatefulWidget {
  const ChannelTile({
    super.key,
    required this.channel,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.autofocus = false,
    this.showGroup = false,
    this.nowPlaying,
    this.onLongPress,
  });

  final Channel channel;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final bool autofocus;
  final bool showGroup;
  final String? nowPlaying;
  final VoidCallback? onLongPress;

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  final _focusNode = FocusNode(debugLabel: 'channel-tile');
  bool _hovered = false;

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
    final ch = widget.channel;
    final focused = _focusNode.hasFocus;
    final highlighted = focused || _hovered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: highlighted
                    ? colors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused
                      ? colors.primary.withValues(alpha: 0.6)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Kanal logosi
                  _ChannelAvatar(channel: ch, size: 44),
                  const SizedBox(width: 12),

                  // Kanal bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: focused ? FontWeight.w700 : FontWeight.w500,
                            color: highlighted
                                ? colors.onSurface
                                : colors.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (widget.nowPlaying != null && widget.nowPlaying!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.play_circle_outline,
                                  size: 13, color: colors.primary.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.nowPlaying!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11, color: colors.primary.withValues(alpha: 0.8)),
                                ),
                              ),
                            ],
                          )
                        else if (widget.showGroup && ch.group != null)
                          Text(
                            ch.displayGroup,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Favori yildizi
                  GestureDetector(
                    onTap: widget.onToggleFavorite,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        widget.isFavorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 20,
                        color: widget.isFavorite
                            ? const Color(0xFFF5A623)
                            : colors.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
                  ),

                  // Oynat ikonu
                  if (highlighted)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 24,
                        color: colors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kanal logosi; yoksa hataliysa bas harfli renkli kare gosterir
class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.channel, this.size = 44});
  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final logo = channel.logo;

    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.network(
          logo,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: (size * 2).round(),
          errorBuilder: (_, __, ___) => _fallback(colors),
          loadingBuilder: (_, child, p) => p == null ? child : _fallback(colors),
        ),
      );
    }
    return _fallback(colors);
  }

  Widget _fallback(ColorScheme colors) {
    final initial = channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.3),
            colors.primary.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}
