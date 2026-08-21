import 'package:flutter/material.dart';
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/widgets/channel_tile.dart';

/// Paylaşılan kaydırılabilir kanal listesi.
class ChannelList extends StatelessWidget {
  const ChannelList({
    super.key,
    required this.channels,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    this.showGroup = false,
    this.nowPlayingOf,
    this.onLongPress,
  });

  final List<Channel> channels;
  final bool Function(Channel) isFavorite;
  final void Function(Channel, int) onTap;
  final void Function(Channel) onToggleFavorite;
  final bool showGroup;

  /// Kanalın şu an oynayan programını döndürür (EPG yoksa null).
  final String? Function(Channel)? nowPlayingOf;

  /// Kanala uzun basıldığında (EPG rehberi).
  final void Function(Channel)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: channels.length,
      itemBuilder: (context, i) {
        final c = channels[i];
        return ChannelTile(
          channel: c,
          autofocus: i == 0,
          showGroup: showGroup,
          isFavorite: isFavorite(c),
          onTap: () => onTap(c, i),
          onToggleFavorite: () => onToggleFavorite(c),
          nowPlaying: nowPlayingOf?.call(c),
          onLongPress: onLongPress == null ? null : () => onLongPress!(c),
        );
      },
    );
  }
}

/// Kanal listesi yoksa gösterilecek boş durum.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: colors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
