import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/screens/channel_guide_sheet.dart';
import 'package:hermestv/screens/player_screen.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:hermestv/widgets/channel_list.dart';
import 'package:provider/provider.dart';

/// Kanal listesi ana ekranı: kategorili grup + arama + liste.
///
/// Gruplar:
/// - Premium en üstte (varsa)
/// - Sonra alfabetik diğer gruplar
/// - Sağ tuş: kategoride iken bir üst kategoriye geç (kanal kapanmaz)
/// - OK tuşu: arama modunu açar
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key, this.onGoToSetup});

  final VoidCallback? onGoToSetup;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  bool _searchMode = false;
  late final FocusNode _searchFocus;

  @override
  void initState() {
    super.initState();
    _searchFocus = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.goBack ||
                event.logicalKey == LogicalKeyboardKey.escape)) {
          node.unfocus();
          if (mounted) setState(() => _searchMode = false);
          SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _openPlayer(BuildContext context, AppState state, int index) {
    final filtered = state.filteredChannels;
    if (index < 0 || index >= filtered.length) return;
    final channel = filtered[index];
    state.setLastPlayed(channel);
    // Tüm kanalları gönder — panelde kategoriler arası geçiş için
    final allChannels = state.channels;
    final allIndex = allChannels.indexOf(channel);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channels: allChannels,
          initialIndex: allIndex >= 0 ? allIndex : 0,
        ),
      ),
    );
  }

  /// Sağ tuş: kategorideyken bir üst kategoriye geç.
  void _onRightArrow(AppState state) {
    if (state.selectedGroup != 'all') {
      state.setGroup('all');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kanallar'),
        actions: [
          if (state.hasChannels) ...[
            // Arama ikonu — sadece OK ile aktif olur
            IconButton(
              tooltip: 'Ara (OK tuşu)',
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() => _searchMode = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocus.requestFocus();
                  SystemChannels.textInput.invokeMethod<void>('TextInput.show');
                });
              },
            ),
            IconButton(
              tooltip: 'Listeyi temizle',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => state.clearPlaylist(),
            ),
          ],
        ],
        bottom: _searchMode && state.hasChannels
            ? PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: TextField(
                    focusNode: _searchFocus,
                    onChanged: state.setQuery,
                    onSubmitted: (_) => _searchFocus.unfocus(),
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
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (state.loadProgress > 0) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${state.loadProgress} kanal yüklendi…',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        if (state.error != null && !state.hasChannels) {
          return EmptyState(
            icon: Icons.error_outline,
            title: 'Playlist yüklenemedi',
            subtitle: state.error,
            actionLabel: 'Kaynak Ekle',
            onAction: widget.onGoToSetup,
          );
        }
        if (!state.hasChannels) {
          return EmptyState(
            icon: Icons.live_tv_outlined,
            title: 'Henüz kanal eklenmedi',
            subtitle: "Playlist URL'si, Xtream Codes hesabı, cihazdan M3U dosyası,\n"
                'internetteki test yayınları veya ücretsiz ve yasal kanallar\n'
                '— hepsi tek ekranda.',
            actionLabel: 'Kaynak Ekle',
            onAction: widget.onGoToSetup,
          );
        }

        final channels = state.filteredChannels;
        return LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          if (wide) {
            return Row(
              children: [
                _GroupSidebar(
                  state: state,
                  width: 240,
                  onRightArrow: () => _onRightArrow(state),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _channelList(context, state, channels),
                ),
              ],
            );
          }
          return Column(
            children: [
              _GroupChips(
                state: state,
                onRightArrow: () => _onRightArrow(state),
              ),
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
        subtitle: 'Grup filtresini değiştirmeyi deneyin.',
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

// ==================== Grup Çipleri (mobil) ====================

class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.state, required this.onRightArrow});

  final AppState state;
  final VoidCallback onRightArrow;

  @override
  Widget build(BuildContext context) {
    final groups = state.sortedGroups;
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
          final isPremium = g.toLowerCase().contains('premium');
          return Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowRight) {
                onRightArrow();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPremium) ...[
                    const Icon(Icons.workspace_premium, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                  ],
                  Text(i == 0 ? 'Tümü' : g),
                ],
              ),
              selected: selected,
              onSelected: (_) => state.setGroup(g),
            ),
          );
        },
      ),
    );
  }
}

// ==================== Grup Kenar Çubuğu (geniş ekran) ====================

class _GroupSidebar extends StatelessWidget {
  const _GroupSidebar({
    required this.state,
    required this.width,
    required this.onRightArrow,
  });

  final AppState state;
  final double width;
  final VoidCallback onRightArrow;

  @override
  Widget build(BuildContext context) {
    final groups = state.sortedGroups;
    return SizedBox(
      width: width,
      child: ListView.builder(
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final g = groups[i];
          final selected = state.selectedGroup == g;
          final isPremium = g.toLowerCase().contains('premium');
          return ListTile(
            autofocus: i == 0 && !selected,
            selected: selected,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            leading: isPremium
                ? const Icon(Icons.workspace_premium, color: Colors.amber, size: 20)
                : (i == 0 ? const Icon(Icons.public, size: 20) : null),
            title: Text(
              i == 0 ? 'Tümü' : g,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: selected && state.selectedGroup != 'all'
                ? const Icon(Icons.arrow_forward, size: 18)
                : null,
            onTap: () => state.setGroup(g),
          );
        },
      ),
    );
  }
}
