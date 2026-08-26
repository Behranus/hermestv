import 'package:flutter/material.dart';
import 'package:hermestv/l10n/app_localizations.dart';
import 'package:hermestv/l10n/locale_provider.dart';
import 'package:hermestv/screens/channels_screen.dart';
import 'package:hermestv/screens/donate_screen.dart';
import 'package:hermestv/screens/favorites_screen.dart';
import 'package:hermestv/screens/setup_screen.dart';
import 'package:hermestv/screens/vod_screen.dart';
import 'package:hermestv/screens/watchlist_screen.dart';
import 'package:provider/provider.dart';

/// Ana kabuk: Zorin OS tarzı modern navigasyon.
/// Geniş ekranda (TV/Box) sol sidebar, dar ekranda (telefon) alt bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _visited = {0};

  void _select(int i) {
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locale = context.watch<LocaleProvider>();
    final loc = locale.loc;

    final titles = [loc.channels, loc.vod, loc.favorites, 'Listem', loc.donate, loc.setup];
    final icons = [Icons.live_tv, Icons.movie, Icons.star, Icons.bookmark, Icons.favorite, Icons.settings];
    final selectedIcons = [Icons.live_tv_rounded, Icons.movie_rounded, Icons.star_rounded, Icons.bookmark_rounded, Icons.favorite_rounded, Icons.settings_rounded];

    final placeholders = List<Widget>.generate(6, (i) {
      if (!_visited.contains(i)) return const SizedBox.shrink();
      return switch (i) {
        0 => ChannelsScreen(onGoToSetup: () => _select(5)),
        1 => VodScreen(onGoToSetup: () => _select(5)),
        2 => const FavoritesScreen(),
        3 => const WatchlistScreen(),
        4 => const DonateScreen(),
        _ => const SetupScreen(),
      };
    });
    final body = IndexedStack(index: _index, children: placeholders);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;

      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              // ─── Sol Sidebar ───
              _ZorinSidebar(
                titles: titles,
                icons: icons,
                selectedIcons: selectedIcons,
                selectedIndex: _index,
                onSelect: _select,
                locale: locale,
              ),
              // Dikey ayırıcı
              Container(
                width: 1,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              ),
              // Ana içerik
              Expanded(child: body),
            ],
          ),
        );
      }

      // ─── Dar ekran (mobil) ───
      return Scaffold(
        body: body,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colors.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            destinations: [
              for (var i = 0; i < titles.length; i++)
                NavigationDestination(
                  icon: Icon(icons[i]),
                  selectedIcon: Icon(selectedIcons[i]),
                  label: titles[i],
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// Zorin OS tarzı modern sidebar.
class _ZorinSidebar extends StatelessWidget {
  const _ZorinSidebar({
    required this.titles,
    required this.icons,
    required this.selectedIcons,
    required this.selectedIndex,
    required this.onSelect,
    required this.locale,
  });

  final List<String> titles;
  final List<IconData> icons;
  final List<IconData> selectedIcons;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lang = locale.lang;
    final flag = lang == 'tr' ? '🇹🇷' : lang == 'ku' ? '🟡🔴🟢' : '🇬🇧';

    return Container(
      width: 88,
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          // ── Logo Alanı ──
          const SizedBox(height: 20),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3C8AFF), Color(0xFF6C5CE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3C8AFF).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'HTV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Dil seçici
          PopupMenuButton<String>(
            offset: const Offset(52, 0),
            onSelected: (v) => locale.setLocale(v),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'tr', child: Text('🇹🇷 Türkçe')),
              const PopupMenuItem(value: 'en', child: Text('🇬🇧 English')),
              const PopupMenuItem(value: 'ku', child: Text('🟤🟢🟡 Kurdî')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: colors.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(flag, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down, size: 14, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: colors.outline.withValues(alpha: 0.2)),
          const SizedBox(height: 8),

          // ── Nav Items ──
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: titles.length,
              itemBuilder: (context, i) {
                final selected = selectedIndex == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Material(
                    color: selected
                        ? colors.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => onSelect(i),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              selected ? selectedIcons[i] : icons[i],
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                titles[i],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  color: selected
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (selected)
                              Container(
                                width: 4,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Alt bilgi
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'v2.1.0',
              style: TextStyle(
                fontSize: 11,
                color: colors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
