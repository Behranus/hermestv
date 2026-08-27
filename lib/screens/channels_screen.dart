import 'package:flutter/material.dart';
import 'package:hermestv/l10n/app_localizations.dart';
import 'package:hermestv/l10n/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/screens/channel_guide_sheet.dart';
import 'package:hermestv/screens/player_screen.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:hermestv/widgets/channel_list.dart';

/// TiviMate tarzı kanal ekranı:
/// - Sol panel: Kategori listesi
/// - Orta panel: Kanal listesi
/// - Sağ panel: EPG bilgisi (seçili kanalda)
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key, this.onGoToSetup});
  final VoidCallback? onGoToSetup;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  bool _searchMode = false;
  late final FocusNode _searchFocus;
  Channel? _selectedChannel;

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final channels = state.filteredChannels;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Column(
        children: [
          // ── Üst Bar: Arama + Başlık ──
          _ChannelsTopBar(
            state: state,
            searchMode: _searchMode,
            searchFocus: _searchFocus,
            onSearchToggle: () {
              setState(() => _searchMode = !_searchMode);
              if (_searchMode) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _searchFocus.requestFocus();
                  SystemChannels.textInput.invokeMethod<void>('TextInput.show');
                });
              }
            },
            onDeletePlaylist: () => state.clearPlaylist(),
            onGoToSetup: widget.onGoToSetup,
          ),

          // ── Ana İçerik: TiviMate 3-Panel ──
          Expanded(
            child: _buildBody(state, channels, theme, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppState state, List<Channel> channels, ThemeData theme, ColorScheme colors) {
    if (state.isLoading) {
      return _buildLoading(theme, colors, state);
    }
    if (state.error != null && !state.hasChannels) {
      return _buildEmpty(theme, colors, 'Playlist yuklenemedi', state.error, widget.onGoToSetup);
    }
    if (!state.hasChannels) {
      return _buildEmpty(theme, colors, 'Henuz kanal eklenmedi',
          'Playlist URL, Xtream Codes, test yayinlari veya ucretsiz kanallar', widget.onGoToSetup);
    }

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      if (wide) {
        // TiviMate 3-panel: Kategori | Kanallar | EPG
        return _TiviMateWideLayout(
          state: state,
          channels: channels,
          selectedChannel: _selectedChannel,
          onChannelSelect: (c) => setState(() => _selectedChannel = c),
          onChannelPlay: (c, i) => _openPlayer(context, state, i),
        );
      }
      // Mobil: Kategoriler üstte, kanallar alta
      return Column(
        children: [
          _CategoryChipsBar(state: state),
          Expanded(
            child: _ChannelListPanel(
              channels: channels,
              state: state,
              onTap: (c, i) => _openPlayer(context, state, i),
              onSelect: (c) => setState(() => _selectedChannel = c),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildLoading(ThemeData theme, ColorScheme colors, AppState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (state.loadProgress > 0) ...[
            const SizedBox(height: 20),
            Text(
              '${state.loadProgress} kanal yukleniyor...',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: state.loadProgress > 0 ? null : 0,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme, ColorScheme colors, String title, String? subtitle, VoidCallback? onAction) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv_outlined, size: 72, color: colors.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(color: colors.onSurfaceVariant), textAlign: TextAlign.center),
            ],
            if (onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: const Text('Kaynak Ekle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Üst Bar ──────────────────────────────────────────
class _ChannelsTopBar extends StatelessWidget {
  const _ChannelsTopBar({
    required this.state,
    required this.searchMode,
    required this.searchFocus,
    required this.onSearchToggle,
    required this.onDeletePlaylist,
    this.onGoToSetup,
  });

  final AppState state;
  final bool searchMode;
  final FocusNode searchFocus;
  final VoidCallback onSearchToggle;
  final VoidCallback onDeletePlaylist;
  final VoidCallback? onGoToSetup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loc = context.watch<LocaleProvider>().loc;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: searchMode && state.hasChannels
          ? Row(
              children: [
                IconButton(
                  onPressed: onSearchToggle,
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    focusNode: searchFocus,
                    onChanged: state.setQuery,
                    onSubmitted: (_) => searchFocus.unfocus(),
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Kanal ara...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: state.query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => state.setQuery(''),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.live_tv, color: colors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  loc.channels,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                ),
                if (state.hasChannels) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${state.filteredChannels.length} kanal',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                  ),
                ],
                const Spacer(),
                if (state.hasChannels) ...[
                  _NavIconButton(
                    icon: Icons.search,
                    tooltip: 'Ara',
                    onTap: onSearchToggle,
                  ),
                  const SizedBox(width: 4),
                  _NavIconButton(
                    icon: Icons.refresh,
                    tooltip: 'Yenile',
                    onTap: state.loadVod,
                  ),
                  const SizedBox(width: 4),
                  _NavIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Temizle',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Listeyi Temizle'),
                          content: const Text('Tum kanallar silinecek. Emin misin?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
                            FilledButton(
                              onPressed: () { onDeletePlaylist(); Navigator.pop(ctx); },
                              style: FilledButton.styleFrom(backgroundColor: colors.error),
                              child: const Text('Temizle'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
    );
  }
}

// ─── TiviMate Geniş Ekran (3 Panel) ──────────────────
class _TiviMateWideLayout extends StatefulWidget {
  const _TiviMateWideLayout({
    required this.state,
    required this.channels,
    required this.selectedChannel,
    required this.onChannelSelect,
    required this.onChannelPlay,
  });

  final AppState state;
  final List<Channel> channels;
  final Channel? selectedChannel;
  final ValueChanged<Channel> onChannelSelect;
  final Function(Channel, int) onChannelPlay;

  @override
  State<_TiviMateWideLayout> createState() => _TiviMateWideLayoutState();
}

class _TiviMateWideLayoutState extends State<_TiviMateWideLayout> {
  int _focusedPanel = 1; // 0=kategori, 1=kanal, 2=epg

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = widget.state;
    final channels = widget.channels;

    return Row(
      children: [
        // ── Sol Panel: Kategoriler ──
        SizedBox(
          width: 220,
          child: _CategoriesPanel(state: state),
        ),

        // Ayirici
        Container(
          width: 1,
          color: colors.outline.withValues(alpha: 0.2),
        ),

        // ── Orta Panel: Kanal Listesi ──
        Expanded(
          flex: 3,
          child: _ChannelListPanel(
            channels: channels,
            state: state,
            onTap: (c, i) => widget.onChannelPlay(c, i),
            onSelect: (c) => widget.onChannelSelect(c),
          ),
        ),

        // Ayirici
        Container(
          width: 1,
          color: colors.outline.withValues(alpha: 0.2),
        ),

        // ── Sag Panel: EPG / Kanal Bilgisi ──
        SizedBox(
          width: 320,
          child: _EpgSidePanel(
            channel: widget.selectedChannel ?? (channels.isNotEmpty ? channels.first : null),
            state: state,
          ),
        ),
      ],
    );
  }
}

// ─── Kategoriler Paneli ──────────────────────────────
class _CategoriesPanel extends StatelessWidget {
  const _CategoriesPanel({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groups = state.sortedGroups;

    return Container(
      color: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Kategoriler',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colors.onSurfaceVariant,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final g = groups[i];
                final selected = state.selectedGroup == g;
                final isPremium = g.toLowerCase().contains('premium');
                final isTurkish = g.toLowerCase().contains('turk') ||
                    g.toLowerCase().contains('tr') ||
                    g.toLowerCase().contains('turkey');
                final isKurdish = g.toLowerCase().contains('kurd');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Material(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => state.setGroup(g),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            // Renkli nokta
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isPremium
                                    ? Colors.amber
                                    : isTurkish
                                        ? colors.primary
                                        : isKurdish
                                            ? const Color(0xFFE54D6E)
                                            : colors.onSurfaceVariant.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                i == 0 ? 'Tum Kanallar' : g,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  color: selected ? colors.primary : colors.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selected)
                              Icon(Icons.chevron_right, size: 16, color: colors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Kanal Listesi Paneli ────────────────────────────
class _ChannelListPanel extends StatelessWidget {
  const _ChannelListPanel({
    required this.channels,
    required this.state,
    required this.onTap,
    required this.onSelect,
  });

  final List<Channel> channels;
  final AppState state;
  final Function(Channel, int) onTap;
  final ValueChanged<Channel> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (channels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Sonuc bulunamadi', style: TextStyle(color: colors.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Kategori filtresini degistirmeyi deneyin',
                style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: channels.length,
      itemBuilder: (context, i) {
        final c = channels[i];
        final isFav = state.isFavorite(c);
        final nowPlay = state.nowPlaying(c)?.title;

        return _ModernChannelTile(
          channel: c,
          index: i + 1,
          isFavorite: isFav,
          nowPlaying: nowPlay,
          autofocus: i == 0,
          showGroup: state.selectedGroup == 'all',
          onTap: () => onTap(c, i),
          onFavorite: () => state.toggleFavorite(c),
          onLongPress: () => showChannelGuide(context, channel: c, state: state),
        );
      },
    );
  }
}

// ─── EPG Yan Paneli ──────────────────────────────────
class _EpgSidePanel extends StatelessWidget {
  const _EpgSidePanel({required this.channel, required this.state});
  final Channel? channel;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    if (channel == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv, size: 48, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Kanal Secin', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
          ],
        ),
      );
    }

    final ch = channel!;
    final epg = state.nowPlaying(ch);

    return Container(
      color: colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kanal bilgisi basligi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo + isim
                Row(
                  children: [
                    if (ch.logo != null && ch.logo!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          ch.logo!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          cacheWidth: 96,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.tv, color: colors.primary, size: 24),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            ch.name.isNotEmpty ? ch.name[0].toUpperCase() : '?',
                            style: TextStyle(color: colors.primary, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ch.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (ch.group != null && ch.group!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              ch.displayGroup,
                              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // EPG Bilgisi
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Simdi
                _EpgSection(
                  title: 'Simdi',
                  icon: Icons.play_circle_filled,
                  color: colors.primary,
                  content: (epg?.title ?? '').isNotEmpty ? (epg?.title ?? '') : 'Bilgi yok',
                ),

                const SizedBox(height: 16),

                // Simdi oynuyor
                if (ch.group != null) ...[
                  _EpgSection(
                    title: 'Kategori',
                    icon: Icons.category,
                    color: colors.tertiary,
                    content: ch.displayGroup,
                  ),
                ],

                const SizedBox(height: 16),

                // Kanal bilgileri
                _EpgSection(
                  title: 'Kanal Bilgisi',
                  icon: Icons.info_outline,
                  color: colors.onSurfaceVariant,
                  content: 'Grup: ${ch.displayGroup}\nKanal: ${ch.name}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpgSection extends StatelessWidget {
  const _EpgSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String content;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            content,
            style: TextStyle(fontSize: 13, color: colors.onSurface, height: 1.4),
          ),
        ),
      ],
    );
  }
}

// ─── Mobil Kategori Cipleri ──────────────────────────
class _CategoryChipsBar extends StatelessWidget {
  const _CategoryChipsBar({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groups = state.sortedGroups;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final g = groups[i];
          final selected = state.selectedGroup == g;
          return ChoiceChip(
            label: Text(i == 0 ? 'Tum' : g, style: TextStyle(fontSize: 12)),
            selected: selected,
            onSelected: (_) => state.setGroup(g),
            selectedColor: colors.primary.withValues(alpha: 0.2),
          );
        },
      ),
    );
  }
}

// ─── Modern Kanal Tile ───────────────────────────────
class _ModernChannelTile extends StatefulWidget {
  const _ModernChannelTile({
    required this.channel,
    required this.index,
    required this.isFavorite,
    required this.onTap,
    required this.onFavorite,
    this.nowPlaying,
    this.autofocus = false,
    this.showGroup = false,
    this.onLongPress,
  });

  final Channel channel;
  final int index;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavorite;
  final String? nowPlaying;
  final bool autofocus;
  final bool showGroup;
  final VoidCallback? onLongPress;

  @override
  State<_ModernChannelTile> createState() => _ModernChannelTileState();
}

class _ModernChannelTileState extends State<_ModernChannelTile> {
  final _focusNode = FocusNode();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ch = widget.channel;
    final focused = _focusNode.hasFocus;
    final highlighted = focused || _hovered;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  // Kanal numarası
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${widget.index}',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Kanal logosu
                  _ChannelAvatar(channel: ch, size: 40),
                  const SizedBox(width: 10),

                  // Kanal bilgileri
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ch.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: focused ? FontWeight.w600 : FontWeight.w500,
                            color: highlighted ? colors.onSurface : colors.onSurface.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (widget.nowPlaying != null && widget.nowPlaying!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.play_circle_outline, size: 12, color: colors.primary.withValues(alpha: 0.7)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.nowPlaying!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: colors.primary.withValues(alpha: 0.8)),
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

                  // Favori
                  GestureDetector(
                    onTap: widget.onFavorite,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 18,
                        color: widget.isFavorite
                            ? colors.tertiary
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
                        size: 22,
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

// ─── Kanal Avatar ────────────────────────────────────
class _ChannelAvatar extends StatelessWidget {
  const _ChannelAvatar({required this.channel, this.size = 40});
  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final logo = channel.logo;

    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
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
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}

// ─── Ortak Buton ─────────────────────────────────────
class _NavIconButton extends StatefulWidget {
  const _NavIconButton({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _hovered ? colors.surfaceContainerHighest.withValues(alpha: 0.6) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon, size: 20, color: colors.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
