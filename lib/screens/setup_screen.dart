import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:iptv_player/screens/free_tv_screen.dart';
import 'package:iptv_player/services/playlist_service.dart';
import 'package:iptv_player/services/settings_service.dart';
import 'package:iptv_player/services/test_server_service.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:provider/provider.dart';

/// Kaynak ekleme ekranı: URL + Xtream Codes + dosya + test yayınları + ücretsiz kanallar + EPG.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlController = TextEditingController();
  final _epgController = TextEditingController();
  final _xtreamServer = TextEditingController();
  final _xtreamUser = TextEditingController();
  final _xtreamPass = TextEditingController();

  bool _xtreamBusy = false;
  String? _xtreamError;
  PlayerSpeed? _speed;

  // Test sunucuları (günlük yenilenen havuz)
  List<TestServer>? _testServers;
  bool _testServersLoading = false;
  String? _testServersNote;

  @override
  void initState() {
    super.initState();
    _loadSpeed();
    _loadTestServers();
  }

  /// Test sunucu havuzunu yükler. Önbellek 24 saat içindeyse yeniden kontrol
  /// edilmez (günlük yenileme); listeyi elle tazelemek için [_refreshTestServers].
  Future<void> _loadTestServers() async {
    if (mounted) setState(() => _testServersLoading = true);
    final servers = await TestServerService.refresh(force: false);
    if (!mounted) return;
    setState(() {
      _testServers = servers;
      _testServersLoading = false;
    });
  }

  Future<void> _refreshTestServers() async {
    setState(() => _testServersLoading = true);
    final servers = await TestServerService.refresh(force: true);
    if (!mounted) return;
    setState(() {
      _testServers = servers;
      _testServersLoading = false;
      _testServersNote = 'Sunucular tazelendi.';
    });
  }

  Future<void> _loadSpeed() async {
    final speed = await SettingsService.loadSpeed();
    if (mounted) setState(() => _speed = speed);
  }

  Future<void> _setSpeed(PlayerSpeed speed) async {
    setState(() => _speed = speed);
    await SettingsService.saveSpeed(speed);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bağlantı hızı: ${speed.label} (${speed.description})')),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _epgController.dispose();
    _xtreamServer.dispose();
    _xtreamUser.dispose();
    _xtreamPass.dispose();
    super.dispose();
  }

  /// Klavyeyi/kutucuğu kapatır — kumanda tuşları tekrar navigasyona döner.
  void _closeKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _loadUrl() async {
    _closeKeyboard();
    final v = _urlController.text.trim();
    if (v.isEmpty) return;
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    await state.loadFromUrl(v);
    if (!mounted) return;
    if (state.error != null) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: ${state.error}')));
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('${state.channels.length} kanal yüklendi.')),
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'txt', 'pls'],
    );
    if (result.isEmpty || !mounted) return;
    final path = result.first.path;
    if (path == null) return;
    final state = context.read<AppState>();
    await state.loadFromFile(path);
    if (!mounted) return;
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${state.error}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${state.channels.length} kanal yüklendi.')),
      );
    }
  }

  Future<void> _loadTest() async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    await state.loadTest();
    if (!mounted) return;
    if (state.error != null) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: ${state.error}')));
    } else {
      final vod = state.vodMovies.isNotEmpty || state.vodSeries.isNotEmpty
          ? ', ${state.vodMovies.length} film${state.vodSeries.isNotEmpty ? ' + ${state.vodSeries.length} dizi' : ''}'
          : '';
      messenger.showSnackBar(
        SnackBar(content: Text('${state.channels.length} test yayını yüklendi$vod.')),
      );
    }
  }

  Future<void> _loginXtream() async {
    _closeKeyboard();
    final state = context.read<AppState>();
    final server = _xtreamServer.text.trim();
    final username = _xtreamUser.text.trim();
    final password = _xtreamPass.text.trim();
    if (server.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _xtreamError = 'Sunucu, kullanıcı adı ve şifre gerekli.');
      return;
    }
    setState(() {
      _xtreamBusy = true;
      _xtreamError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.loginXtream(
        server: server,
        username: username,
        password: password,
      );
      if (!mounted) return;
      if (state.error != null) {
        messenger.showSnackBar(SnackBar(content: Text('Hata: ${state.error}')));
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Bağlandı: ${state.channels.length} kanal, ${state.vodMovies.length} film, ${state.vodSeries.length} dizi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _xtreamError = e.toString());
        messenger.showSnackBar(SnackBar(content: Text('Giriş hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _xtreamBusy = false);
    }
  }

  /// Bölüm başlığı — ayarları derli toplu gruplar.
  Widget _sectionHeader(ThemeData theme, IconData icon, String title,
      [String? subtitle]) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kurulum')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ---- Bölüm 1: Kaynak Ekle ----
          _sectionHeader(
            theme,
            Icons.add_circle_outline,
            'Kaynak Ekle',
            'URL, Xtream Codes veya cihazdan M3U dosyası',
          ),

          // URL + Xtream yan yana (geniş ekran) / alt alta (telefon)
          LayoutBuilder(builder: (context, constraints) {
            final urlCard = _urlCard(theme, state);
            final xtreamCard = _xtreamCard(theme, state);
            if (constraints.maxWidth >= 720) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: urlCard),
                  const SizedBox(width: 12),
                  Expanded(child: xtreamCard),
                ],
              );
            }
            return Column(
              children: [
                urlCard,
                const SizedBox(height: 12),
                xtreamCard,
              ],
            );
          }),

          const SizedBox(height: 12),

          // Dosya + Test yayınları
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.folder_open),
                    title: const Text('Dosya Seç'),
                    subtitle: const Text('Cihazdan M3U seç'),
                    onTap: _pickFile,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.science_outlined),
                        title: const Text('Test Yayınları'),
                        subtitle: const Text('İnternetteki test sunucuları — günde bir kez otomatik yenilenir'),
                        onTap: _loadTest,
                      ),
                      // Günlük yenilenen test sunucu havuzu
                      if (_testServersLoading)
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_testServers != null && _testServers!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final s in _testServers!) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle,
                                          color: Colors.green, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${s.name} — ${s.liveCount} kategori'
                                          '${s.vodCount > 0 ? ', ${s.vodCount} film' : ''}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Row(
                                children: [
                                  Text(
                                    'En iyi sunucu otomatik yüklenir • VOD dahil',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    tooltip: 'Sunucuları tazele',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    onPressed: _refreshTestServers,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Şu an çalışan test sunucusu yok — doğrudan test yayınları yüklenir.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Sunucuları tazele',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.refresh, size: 18),
                                onPressed: _refreshTestServers,
                              ),
                            ],
                          ),
                        ),
                      if (_testServersNote != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Text(
                            _testServersNote!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ---- Bölüm 2: Ücretsiz Kanallar ----
          _sectionHeader(
            theme,
            Icons.public,
            'Ücretsiz Kanallar',
            'Yasal ve ücretsiz dünya kanalları',
          ),

          // Ücretsiz ve yasal kanallar
          Card(
            child: ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Ücretsiz ve Yasal Kanallar'),
              subtitle: const Text('iptv-org kataloğundan ülke → kategori seç (Türkiye ilk sırada)'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FreeTvScreen()),
              ),
            ),
          ),

          // ---- Bölüm 3: Oynatıcı ----
          _sectionHeader(
            theme,
            Icons.speed,
            'Oynatıcı',
            'Kanal geçiş hızı ve tampon ayarı',
          ),

          // Bağlantı hızı (kanal geçişi)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bağlantı Hızı', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Kanal geçiş hızı ve tampon süresi. Küçük tampon = daha hızlı geçiş, '
                    'büyük tampon = yavaş ağlarda daha akıcı yayın.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final speed in PlayerSpeed.options)
                        ChoiceChip(
                          label: Text(speed.label),
                          tooltip: speed.description,
                          selected: _speed?.bufferSecs == speed.bufferSecs,
                          onSelected: (_) => _setSpeed(speed),
                        ),
                    ],
                  ),
                  if (_speed != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _speed!.description,
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ---- Bölüm 4: Rehber ----
          _sectionHeader(
            theme,
            Icons.calendar_month,
            'Rehber',
            'EPG program bilgileri',
          ),

          // EPG
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EPG (Program Rehberi)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    state.epg != null
                        ? '${state.epg!.channelCount} kanal için program yüklendi.'
                        : 'Sağlayıcının verdiği XMLTV adresini gir (ör. https://…/epg.xml.gz). '
                            'Xtream girişinde EPG otomatik yüklenir.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _epgController,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onTapOutside: (_) => _closeKeyboard(),
                    decoration: const InputDecoration(
                      labelText: 'EPG URL\'si',
                      hintText: 'https://ornek.com/epg.xml.gz',
                      prefixIcon: Icon(Icons.calendar_month),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      _closeKeyboard();
                      if (v.trim().isNotEmpty) state.loadEpg(v.trim());
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          final v = _epgController.text;
                          if (v.trim().isNotEmpty) state.loadEpg(v.trim());
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('EPG Yükle'),
                      ),
                      if (state.epg != null || state.epgUrl != null) ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: state.clearEpg,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Kaldır'),
                        ),
                      ],
                    ],
                  ),
                  if (state.epgLoading) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (state.epgError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'EPG hatası: ${state.epgError}',
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ---- Bölüm 5: Durum ----
          if (state.source != null) ...[
            _sectionHeader(
              theme,
              Icons.info_outline,
              'Durum',
              'Aktif kaynak ve bilgiler',
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Kayıtlı kaynak'),
                subtitle: Text(
                  '${_sourceLabel(state.source!)} • ${state.channels.length} kanal',
                ),
                trailing: IconButton(
                  tooltip: 'Kaldır',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: state.clearPlaylist,
                ),
              ),
            ),
          ],

          if (state.error != null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
                title: const Text('Hata'),
                subtitle: Text(state.error!, maxLines: 3),
              ),
            ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          // Ücretsiz/test kanalları doğrulanıyor (günlük yenileme).
          if (state.testProbeActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kanallar doğrulanıyor… '
                    '${state.testProbeDone}/${state.testProbeTotal}'
                    ' (yalnızca açılanlar listelenir)',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.testProbeTotal > 0
                        ? state.testProbeDone / state.testProbeTotal
                        : null,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _urlCard(ThemeData theme, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Playlist URL\'si (M3U)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Sağlayıcının verdiği M3U/M3U8 adresini yapıştır.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => _closeKeyboard(),
              decoration: const InputDecoration(
                labelText: 'Playlist URL\'si',
                hintText: 'https://ornek.com/playlist.m3u8',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loadUrl(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: state.isLoading ? null : _loadUrl,
                icon: const Icon(Icons.download),
                label: const Text('URL\'den Yükle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _xtreamCard(ThemeData theme, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xtream Codes', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Portal adresi + kullanıcı adı + şifre. Canlı kanallar, VOD ve EPG otomatik yüklenir.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _xtreamServer,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              onTapOutside: (_) => _closeKeyboard(),
              decoration: const InputDecoration(
                labelText: 'Sunucu adresi',
                hintText: 'http://sunucu:8080',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _xtreamUser,
              textInputAction: TextInputAction.next,
              onTapOutside: (_) => _closeKeyboard(),
              decoration: const InputDecoration(
                labelText: 'Kullanıcı adı',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _xtreamPass,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => _closeKeyboard(),
              onSubmitted: (_) => _loginXtream(),
              decoration: const InputDecoration(
                labelText: 'Şifre',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_xtreamError != null) ...[
              const SizedBox(height: 10),
              Text(
                _xtreamError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _xtreamBusy ? null : _loginXtream,
                icon: _xtreamBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(_xtreamBusy ? 'Bağlanılıyor…' : 'Giriş Yap'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(PlaylistSource source) {
    return switch (source.type) {
      PlaylistSourceType.url => 'URL: ${source.value}',
      PlaylistSourceType.file => 'Dosya: ${source.value.split('/').last}',
      PlaylistSourceType.demo => 'Test yayınları',
      PlaylistSourceType.xtream => 'Xtream Codes hesabı',
    };
  }
}
