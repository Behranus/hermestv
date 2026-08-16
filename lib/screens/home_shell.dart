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
                leading: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.live_tv, size: 32),
                ),
                destinations: [
                  for (var i = 0; i < _titles.length; i++)
                    NavigationRailDestination(
                      icon: Icon(_icons[i]),
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
                label: _titles[i],
              ),
          ],
        ),
      );
    });
  }
}
