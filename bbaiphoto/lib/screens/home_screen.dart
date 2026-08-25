import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bbaiphoto/l10n/locale_provider.dart';
import 'package:bbaiphoto/screens/editor_dashboard.dart';

/// BBAI Photo ana ekranı — geniş/dar ekran navigasyonu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final l = locale.loc;

    final titles = [l.editor, l.templates, l.settings];
    final icons = [Icons.auto_awesome, Icons.collections, Icons.settings];

    final placeholders = List<Widget>.generate(3, (i) {
      if (!_visited.contains(i)) return const SizedBox.shrink();
      return switch (i) {
        0 => const EditorDashboard(),
        1 => const _TemplatesPlaceholder(),
        _ => const _SettingsPlaceholder(),
      };
    });
    final body = IndexedStack(index: _index, children: placeholders);

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;

      if (wide) {
        return Scaffold(
          body: Row(
            children: [
              // Sol Navigation Rail
              SizedBox(
                width: 88,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF667EEA),
                                  Color(0xFF764BA2),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BBAI Photo',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _CompactLangSelector(locale: locale),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
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

      // Dar ekran (mobil)
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

/// Kompakt dil seçici
class _CompactLangSelector extends StatelessWidget {
  const _CompactLangSelector({required this.locale});
  final LocaleProvider locale;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final flag = locale.lang == 'tr' ? '🇹🇷' : '🇬🇧';

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
      ],
    );
  }
}

/// Şablonlar placeholder
class _TemplatesPlaceholder extends StatelessWidget {
  const _TemplatesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const EditorDashboard();
  }
}

/// Ayarlar placeholder
class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>();
    final l = locale.loc;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        title: Text(l.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Dil seçimi
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    l.language,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _LangTile(
                  flag: '🇹🇷',
                  label: l.turkish,
                  isActive: locale.lang == 'tr',
                  onTap: () => locale.setLocale('tr'),
                ),
                _LangTile(
                  flag: '🇬🇧',
                  label: l.english,
                  isActive: locale.lang == 'en',
                  onTap: () => locale.setLocale('en'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Hakkında
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.appName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          l.version,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l.appDesc,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String flag;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LangTile({
    required this.flag,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 20)),
      title: Text(
        label,
        style: TextStyle(
          color: isActive ? const Color(0xFF1E88E5) : Colors.white70,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isActive
          ? const Icon(Icons.check_circle, color: Color(0xFF1E88E5), size: 20)
          : null,
      onTap: onTap,
    );
  }
}
