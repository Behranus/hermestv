import 'package:flutter/material.dart';
import 'package:hermestv/services/free_tv_service.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:provider/provider.dart';

/// iptv-org kataloğundan ücretsiz ve yasal kanallar.
///
/// Akış: ülke seç (Türkiye ilk sırada) → ülke içindeki kategoriler
/// (veya tüm dünya kategorileri). Her kategori o ülkenin kanallarını içerir.
class FreeTvScreen extends StatefulWidget {
  const FreeTvScreen({super.key});

  @override
  State<FreeTvScreen> createState() => _FreeTvScreenState();
}

class _FreeTvScreenState extends State<FreeTvScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ücretsiz ve Yasal Kanallar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kaynak: iptv-org', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Bu liste yalnızca yayıncıların kendilerinin ücretsiz sunduğu '
                    '(public broadcaster ve free-to-air) kanalları içerir. '
                    'Önce ülke seç, sonra o ülkenin kategorilerine göz at.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Tüm dünya kategorileri
          Card(
            color: theme.colorScheme.primaryContainer,
            child: ListTile(
              leading: Icon(Icons.public, color: theme.colorScheme.onPrimaryContainer),
              title: const Text('Tüm Dünya — Kategoriler'),
              subtitle: const Text('Kategorilere göre tüm ülkelerin kanalları'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _CategoryGridScreen(country: null),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // ---- Ek HD/4K kaynaklar (Sungate Titan benzeri cihazların
          // kullandığı免费 kaynaklar: Pluto TV, Samsung TV Plus, Plex, Free-TV) ----
          Text('Ek HD/4K Kaynaklar', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Sungate Titan benzeri cihazların sağladığı ücretsiz HD/4K kanallar.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final (label, url) in FreeTvService.extraSources)
            Card(
              child: ListTile(
                dense: true,
                leading: Icon(
                  label.contains('4K') ? Icons.videocam : Icons.live_tv,
                  color: theme.colorScheme.primary,
                ),
                title: Text(label),
                subtitle: const Text('HD/4K ücretsiz yayınlar'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final state = context.read<AppState>();
                  state.loadFromUrl(url);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label yükleniyor…')),
                  );
                },
              ),
            ),
          const SizedBox(height: 24),
          Text('Ülkeler', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'İstediğin ülkenin ücretsiz kanallarını keşfet.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final country in FreeTvService.countries)
            Card(
              child: ListTile(
                dense: true,
                leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                title: Text(country.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _CategoryGridScreen(country: country),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Bir ülkenin (veya tüm dünyanın) kategori ızgarası.
/// Her kategori o ülkeye özel `categories/{kategori}/{ülke}.m3u` adresini yükler.
class _CategoryGridScreen extends StatefulWidget {
  const _CategoryGridScreen({required this.country});

  /// Null ise tüm dünya, değilse o ülkenin kategorileri.
  final FreeTvCountry? country;

  @override
  State<_CategoryGridScreen> createState() => _CategoryGridScreenState();
}

class _CategoryGridScreenState extends State<_CategoryGridScreen> {
  bool _loading = false;
  String? _loadingLabel;

  // Ülke seçildiğinde: grup (kategori) adı → kanal sayısı.
  Map<String, int> _countryCategories = {};
  bool _categoriesLoading = false;
  String? _categoriesError;

  String get _title => widget.country == null
      ? 'Tüm Dünya — Kategoriler'
      : '${widget.country!.flag} ${widget.country!.label} — Kategoriler';

  String get _allLabel => widget.country == null
      ? 'Tüm kanallar (dünya)'
      : 'Tüm kanallar (${widget.country!.label})';

  @override
  void initState() {
    super.initState();
    final country = widget.country;
    if (country != null) _loadCountryCategories(country.code);
  }

  Future<void> _loadCountryCategories(String code) async {
    setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    try {
      final cats = await FreeTvService.loadCountryCategories(code);
      if (mounted) setState(() => _countryCategories = cats);
    } catch (e) {
      if (mounted) setState(() => _categoriesError = e.toString());
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  /// Ülkenin tüm kanallarını yükler; `group` verilirse yalnızca o grup açılır.
  Future<void> _loadCountryChannels(String code, String? group, String label) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadingLabel = label;
    });
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.loadFromUrl(FreeTvService.countryM3u(code));
      // Kategori seçildiyse o gruba odaklan.
      if (group != null) state.setGroup(group);
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('$label yüklendi: ${state.channels.length} kanal')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Yükleme hatası: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGlobal(String url, String label) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _loadingLabel = label;
    });
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.loadFromUrl(url);
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('$label yüklendi: ${state.channels.length} kanal')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Yükleme hatası: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final country = widget.country;
    final isCountry = country != null;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Tüm kanallar
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.live_tv),
                  title: Text(_allLabel),
                  subtitle: Text(isCountry
                      ? '${country.label} ülkesinin tüm kanalları tek listede'
                      : 'Tüm ülkelerin tüm kanalları'),
                  trailing: const Icon(Icons.download),
                  onTap: () => isCountry
                      ? _loadCountryChannels(country.code, null, _allLabel)
                      : _loadGlobal(FreeTvService.allM3u, _allLabel),
                ),
              ),
              const SizedBox(height: 24),
              Text('Kategoriler', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                isCountry
                    ? 'Ülke kanalları konularına göre gruplandı — istediğine dokun.'
                    : 'Kategorilere göre tüm dünyadan kanallar.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (isCountry && _categoriesLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (isCountry && _categoriesError != null)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Kategoriler alınamadı: $_categoriesError',
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => _loadCountryCategories(country.code),
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isCountry)
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.6,
                  children: [
                    for (final entry in _countryCategories.entries)
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _loadCountryChannels(
                            country.code,
                            entry.key,
                            '${FreeTvService.translateGroup(entry.key)} (${entry.value})',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  _groupIcon(entry.key),
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        FreeTvService.translateGroup(entry.key),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                      Text(
                                        '${entry.value} kanal',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: [
                    for (final cat in FreeTvService.categories)
                      Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _loadGlobal(
                            FreeTvService.categoryM3u(cat.slug),
                            '${cat.label} kategorisi',
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(cat.icon, color: theme.colorScheme.primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    cat.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
          if (_loading)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('$_loadingLabel yükleniyor…'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _groupIcon(String group) {
    return switch (group.toLowerCase()) {
      'news' => Icons.newspaper,
      'sports' => Icons.sports_soccer,
      'music' => Icons.music_note,
      'movies' || 'series' => Icons.movie,
      'kids' || 'animation' => Icons.child_care,
      'documentary' => Icons.travel_explore,
      'education' => Icons.school,
      'culture' => Icons.theater_comedy,
      'religious' => Icons.temple_buddhist,
      'travel' => Icons.flight,
      'weather' => Icons.cloud,
      'business' => Icons.business,
      'lifestyle' || 'general' => Icons.public,
      _ => Icons.tv,
    };
  }
}
