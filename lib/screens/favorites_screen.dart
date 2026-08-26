import 'package:flutter/material.dart';
import 'package:hermestv/l10n/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:hermestv/screens/channel_guide_sheet.dart';
import 'package:hermestv/screens/player_screen.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:hermestv/widgets/channel_list.dart';

/// Favori kanallar ekrani - modern Zorin OS tema
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favorites = state.favoriteChannels;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Ust bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5A623).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  context.watch<LocaleProvider>().loc.favorites,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                ),
                if (favorites.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${favorites.length} kanal',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),

          // Icerik
          Expanded(
            child: favorites.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_border_rounded,
                            size: 72, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('Henuz favori yok',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )),
                        const SizedBox(height: 8),
                        Text(
                          'Kanal listesinde yildiz simgesine basarak\nfavori ekleyebilirsin.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ChannelList(
                    channels: favorites,
                    showGroup: true,
                    isFavorite: state.isFavorite,
                    onToggleFavorite: state.toggleFavorite,
                    onTap: (c, i) {
                      state.setLastPlayed(c);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            channels: favorites,
                            initialIndex: i,
                          ),
                        ),
                      );
                    },
                    nowPlayingOf: (c) => state.nowPlaying(c)?.title,
                    onLongPress: (c) => showChannelGuide(
                      context,
                      channel: c,
                      state: state,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
