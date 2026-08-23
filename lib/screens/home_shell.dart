import 'package:flutter/material.dart';
import 'package:hermestv/screens/channels_screen.dart';
import 'package:hermestv/screens/donate_screen.dart';
import 'package:hermestv/screens/favorites_screen.dart';
import 'package:hermestv/screens/setup_screen.dart';
import 'package:hermestv/screens/vod_screen.dart';

/// Ana kabuk: geniş ekranda (TV/Box) solda NavigationRail,
/// dar ekranda (telefon) altta NavigationBar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Ziyaret edilen sekmeler (durum korunur). Açılışta yalnızca Kanallar
  /// kurulur; VOD/Kurulum gibi ağır sekmeler ilk kez açılınca yüklenir.
  /// (4 sekmeyi birden IndexedStack'te kurmak 2GB RAM'li Box'larda açılışı
  /// ağırlaştırıyordu — VOD posteri ve Kurulum ağı aynı anda yükleniyordu.)
  final Set<int> _visited = {0};

  static const _titles = ['Kanallar', 'VOD', 'Favoriler', 'Destek', 'Kurulum'];
  static const _icons = [Icons.live_tv, Icons.movie, Icons.star, Icons.favorite, Icons.settings];

  void _select(int i) {
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      // Yalnızca ziyaret edilen sekmeler kurulur; diğerleri boş tutulur.
      // IndexedStack çocukların hepsini kurduğu için ziyaret edilmemiş
      // sekmeleri yer tutucuyla doldurup `index` ile senkron tutarız.
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

      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _select,
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
                        'hermestv',
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
          onDestinationSelected: _select,
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
