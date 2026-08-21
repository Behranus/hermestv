import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermestv/models/channel.dart';

/// Kanal listesi satırı. Android TV / Box uzaktan kumandası (D-pad)
/// odak navigasyonu için [Focus] kullanır.
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

  /// EPG'den şu an oynayan program (varsa, satırda gösterilir).
  final String? nowPlaying;

  /// Uzun basma (örn. program rehberini açmak için).
  final VoidCallback? onLongPress;

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  final _focusNode = FocusNode(debugLabel: 'channel-tile');

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
    final nowPlaying = widget.nowPlaying;

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _focused ? colors.primaryContainer.withValues(alpha: 0.45) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? colors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _Logo(channel: widget.channel),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: _focused ? FontWeight.bold : FontWeight.w500,
                          color: _focused ? colors.onPrimaryContainer : colors.onSurface,
                        ),
                      ),
                      if (widget.showGroup || widget.channel.group != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.channel.displayGroup,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (nowPlaying != null && nowPlaying.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.schedule, size: 13, color: colors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                nowPlaying,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onToggleFavorite,
                  tooltip: widget.isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  icon: Icon(
                    widget.isFavorite ? Icons.star : Icons.star_border,
                    color: widget.isFavorite ? Colors.amber : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.play_circle_outline, color: colors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kanal logosu; yoksa/hatalıysa baş harfli renkli daire gösterir.
class _Logo extends StatelessWidget {
  const _Logo({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final logo = channel.logo;
    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          logo,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          // Küçük boyutta çöz → 2GB RAM'li Box'larda bellek şişmesin.
          cacheWidth: 88,
          errorBuilder: (_, _, _) => _fallback(context),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _fallback(context),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?';
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        initial,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.primary),
      ),
    );
  }
}
