import 'package:flutter/material.dart';
import 'package:hermestv/l10n/app_localizations.dart';
import 'package:hermestv/l10n/locale_provider.dart';
import 'package:hermestv/screens/channels_screen.dart';
import 'package:hermestv/screens/donate_screen.dart';
import 'package:hermestv/screens/favorites_screen.dart';
import 'package:hermestv/screens/setup_screen.dart';
import 'package:hermestv/screens/vod_screen.dart';
import 'package:provider/provider.dart';

/// Ana kabuk: geniş ekranda (TV/Box) solda NavigationRail,
/// dar ekranda (telefon) altta NavigationBar.
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

    final titles = [loc.channels, loc.vod, loc.favorites, loc.donate, loc.setup];
    final icons = [Icons.live_tv, Icons.movie, Icons.star, Icons.favorite, Icons.settings];

    final placeholders = List<Widget>.generate(5, (i) {
      if (!_visited.contains(i)) return const SizedBox.shrink();
      return switch (i) {
        0 => ChannelsScreen(onGoToSetup: () => _select(4)),
        1 => VodScreen(onGoToSetup: () => _select(4)),
        2 => const FavoritesScreen(),
        3 => const DonateScreen(),
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
              // ─── Sol Navigation Rail ───
              SizedBox(
                width: 88,
                child: Column(
                  children: [
                    // Üst kısım: Logo + Dil seçici
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.live_tv, color: Colors.white, size: 26),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'hermestv',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // ─── Dil seçici (kompakt) ───
                          _CompactLangSelector(locale: locale),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Nav items
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: _select,
                        labelType: NavigationRailLabelType.all,
                        minWidth: 88,
                        groupAlignment: -0.5,
                        leading: const SizedBox.shrink(),
                        destinations: [
                          for (var i = 0; i < titles.length; i++)
                            NavigationRailDestination(
                              icon: Icon(icons[i]),
                              selectedIcon: Icon(icons[i]),
                              label: Text(titles[i]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      }

      // ─── Dar ekran (mobil) ───
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          destinations: [
            for (var i = 0; i < titles.length; i++)
              NavigationDestination(
                icon: Icon(icons[i]),
                selectedIcon: Icon(icons[i]),
                label: titles[i],
              ),
          ],
        ),
      );
    });
  }
}

/// Kompakt dil seçici — NavigationRail altında国旗+dropdown.
class _CompactLangSelector extends StatelessWidget {
  const _CompactLangSelector({required this.locale});

  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final flag = locale.lang == 'tr' ? '🇹🇷' : locale.lang == 'ku' ? '🏴' : '🇬🇧';

    return PopupMenuButton<String>(
      onSelected: (v) => locale.setLocale(v),
      tooltip: locale.loc.language,
      offset: const Offset(48, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 14, color: colors.onSurfaceVariant),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'tr', child: Text(locale.loc.turkish)),
        PopupMenuItem(value: 'en', child: Text(locale.loc.english)),
        PopupMenuItem(value: 'ku', child: Text(locale.loc.kurdish)),
      ],
    );
  }
}
