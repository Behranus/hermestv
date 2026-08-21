import 'package:flutter/material.dart';
import 'package:hermestv/screens/channel_guide_sheet.dart';
import 'package:hermestv/screens/player_screen.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:hermestv/widgets/channel_list.dart';
import 'package:provider/provider.dart';

/// Favori kanallar ekranı.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final favorites = state.favoriteChannels;

    return Scaffold(
      appBar: AppBar(title: const Text('Favoriler')),
      body: favorites.isEmpty
          ? const EmptyState(
              icon: Icons.star_border,
              title: 'Henüz favori yok',
              subtitle: 'Kanal listesinde yıldız simgesine dokunarak favori ekleyebilirsin.',
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
                    builder: (_) => PlayerScreen(channels: favorites, initialIndex: i),
                  ),
                );
              },
              nowPlayingOf: (c) => state.nowPlaying(c)?.title,
              onLongPress: (c) => showChannelGuide(context, channel: c, state: state),
            ),
    );
  }
}
