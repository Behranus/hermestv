import 'package:flutter/material.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/screens/channel_guide_sheet.dart';
import 'package:iptv_player/screens/player_screen.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:iptv_player/widgets/channel_list.dart';
import 'package:provider/provider.dart';

/// Kanal listesi ana ekranı: grup seçimi + arama + liste.
class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key, this.onGoToSetup});

  /// Kanal yokken "Kaynak Ekle" ile Kurulum sekmesine geçmek için.
  final VoidCallback? onGoToSetup;

  void _openPlayer(BuildContext context, AppState state, int index) {
    final channels = state.filteredChannels;
    if (index < 0 || index >= channels.length) return;
    final channel = channels[index];
    state.setLastPlayed(channel);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(channels: channels, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanallar'),
        actions: [
          if (state.hasChannels)
            IconButton(
              tooltip: 'Listeyi temizle',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => state.clearPlaylist(),
            ),
        ],
        bottom: state.hasChannels
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    onChanged: state.setQuery,
                    decoration: InputDecoration(
                      hintText: 'Kanal ara…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: state.query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => state.setQuery(''),
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Builder(builder: (context) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null && !state.hasChannels) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Playlist yüklenemedi',
            subtitle: state.error,
            actionLabel: 'Kaynak Ekle',
            onAction: onGoToSetup,
          );
        }
        if (!state.hasChannels) {
          return EmptyState(
            icon: Icons.live_tv_outlined,
            title: 'Henüz kanal eklenmedi',
            subtitle: 'Playlist URL\'si, Xtream Codes hesabı, cihazdan M3U dosyası,\n'
                'internetteki test yayınları veya ücretsiz ve yasal kanallar\n'
                '— hepsi tek ekranda.',
            actionLabel: 'Kaynak Ekle',
            onAction: onGoToSetup,
          );
        }

        final channels = state.filteredChannels;
        return LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          if (wide) {
            return Row(
              children: [
                _GroupSidebar(state: state, width: 240),
                const VerticalDivider(width: 1),
                Expanded(child: _channelList(context, state, channels)),
              ],
            );
          }
          return Column(
            children: [
              _GroupChips(state: state),
              Expanded(child: _channelList(context, state, channels)),
            ],
          );
        });
      }),
    );
  }

  Widget _channelList(BuildContext context, AppState state, List<Channel> channels) {
    if (channels.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Sonuç bulunamadı',
        subtitle: 'Arama veya grup filtresini değiştirmeyi deneyin.',
      );
    }
    return ChannelList(
      channels: channels,
      showGroup: state.selectedGroup == 'all',
      isFavorite: state.isFavorite,
      onToggleFavorite: state.toggleFavorite,
      onTap: (c, i) => _openPlayer(context, state, i),
      nowPlayingOf: (c) => state.nowPlaying(c)?.title,
      onLongPress: (c) => showChannelGuide(context, channel: c, state: state),
    );
  }
}

class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final groups = state.groups;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final g = groups[i];
          final selected = state.selectedGroup == g;
          return ChoiceChip(
            label: Text(i == 0 ? 'Tümü' : g),
            selected: selected,
            onSelected: (_) => state.setGroup(g),
          );
        },
      ),
    );
  }
}

class _GroupSidebar extends StatelessWidget {
  const _GroupSidebar({required this.state, required this.width});

  final AppState state;
  final double width;

  @override
  Widget build(BuildContext context) {
    final groups = state.groups;
    return SizedBox(
      width: width,
      child: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          final selected = state.selectedGroup == g;
          return ListTile(
            autofocus: i == 0 && !selected,
            selected: selected,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            title: Text(i == 0 ? 'Tümü' : g, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => state.setGroup(g),
          );
        },
      ),
    );
  }
}
