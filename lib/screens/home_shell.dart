import 'package:flutter/material.dart';
import 'package:iptv_player/screens/channels_screen.dart';
import 'package:iptv_player/screens/favorites_screen.dart';
import 'package:iptv_player/screens/setup_screen.dart';
import 'package:iptv_player/screens/vod_screen.dart';

/// Ana kabuk: geniş ekranda (TV/Box) solda NavigationRail,
/// dar ekranda (telefon) altta NavigationBar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Kanallar', 'VOD', 'Favoriler', 'Kurulum'];
  static const _icons = [Icons.live_tv, Icons.movie, Icons.star, Icons.settings];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final body = IndexedStack(
        index: _index,
        children: [
          ChannelsScreen(onGoToSetup: () => setState(() => _index = 3)),
          VodScreen(onGoToSetup: () => setState(() => _index = 3)),
          const FavoritesScreen(),
          const SetupScreen(),
        ],
      );

      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                minWidth: 88,
                groupAlignment: -0.7,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
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
                      const SizedBox(height: 6),
                      Text(
                        'bbtv',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: [
                  for (var i = 0; i < _titles.length; i++)
                    NavigationRailDestination(
                      icon: Icon(_icons[i]),
                      selectedIcon: Icon(_icons[i]),
                      label: Text(_titles[i]),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      }

      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (var i = 0; i < _titles.length; i++)
              NavigationDestination(
                icon: Icon(_icons[i]),
                selectedIcon: Icon(_icons[i]),
                label: _titles[i],
              ),
          ],
        ),
      );
    });
  }
}
