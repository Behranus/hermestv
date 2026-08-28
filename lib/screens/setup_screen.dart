import 'package:file_picker/file_picker.dart';
import 'package:hermestv/l10n/app_localizations.dart';
import 'package:hermestv/l10n/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermestv/screens/free_tv_screen.dart';
import 'package:hermestv/services/playlist_service.dart';
import 'package:hermestv/services/settings_service.dart';
import 'package:hermestv/state/app_state.dart';

/// Ayarlar / Kaynak ekleme ekrani - modern Zorin OS tema
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
  AppLocalizations get loc => context.read<LocaleProvider>().loc;

  @override
  void initState() {
    super.initState();
    _loadSpeed();
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
      SnackBar(content: Text('Baglanti hizi: ${speed.label} (${speed.description})')),
    );
  }

  void _closeKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

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
      messenger.showSnackBar(SnackBar(content: Text('${state.channels.length} kanal yuklendi.')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${state.error}')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${state.channels.length} kanal yuklendi.')));
    }
  }

  Future<void> _loginXtream() async {
    _closeKeyboard();
    final state = context.read<AppState>();
    final server = _xtreamServer.text.trim();
    final username = _xtreamUser.text.trim();
    final password = _xtreamPass.text.trim();
    if (server.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _xtreamError = loc.server + ', ' + loc.username + ' ve ' + loc.password + ' gerekli');
      return;
    }
    setState(() {
      _xtreamBusy = true;
      _xtreamError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.loginXtream(server: server, username: username, password: password);
      if (!mounted) return;
      if (state.error != null) {
        messenger.showSnackBar(SnackBar(content: Text('Hata: ${state.error}')));
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text('Baglandi: ${state.channels.length} kanal, ${state.vodMovies.length} film, ${state.vodSeries.length} dizi.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _xtreamError = e.toString());
        messenger.showSnackBar(SnackBar(content: Text(loc.loginError + ': $e')));
      }
    } finally {
      if (mounted) setState(() => _xtreamBusy = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Setup ekraninda geri tusu -> bir onceki alana don (veya kanal ekranina)
        Navigator.of(context).maybePop();
      },
      child: Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Column(
        children: [
          // Ust bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.settings_rounded, color: colors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  context.watch<LocaleProvider>().loc.setup,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                ),
              ],
            ),
          ),

          // Icerik
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Kaynak Ekle ──
                _SectionHeader(
                  icon: Icons.link_rounded,
                  title: loc.addSource,
                  subtitle: 'URL, Xtream Codes, ' + loc.pickFileSub,
                ),

                // URL + Xtream
                LayoutBuilder(builder: (context, constraints) {
                  final urlCard = _UrlCard(
                    controller: _urlController,
                    isLoading: state.isLoading,
                    onSubmit: _loadUrl,
                    loc: loc,
                  );
                  final xtreamCard = _XtreamCard(
                    server: _xtreamServer,
                    user: _xtreamUser,
                    pass: _xtreamPass,
                    error: _xtreamError,
                    busy: _xtreamBusy,
                    onSubmit: _loginXtream,
                    loc: loc,
                  );
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
                  return Column(children: [urlCard, const SizedBox(height: 12), xtreamCard]);
                }),

                const SizedBox(height: 12),

                // Dosya yukleme
                _SettingsCard(
                  child: ListTile(
                    leading: Icon(Icons.folder_open_rounded, color: colors.primary),
                    title: Text(loc.pickFile),
                    subtitle: Text(loc.pickFileSub, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                    trailing: Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
                    onTap: _pickFile,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Ucretsiz Kanallar ──
                _SectionHeader(
                  icon: Icons.public_rounded,
                  title: loc.freeTv,
                  subtitle: loc.freeLegalSub,
                ),

                _SettingsCard(
                  child: ListTile(
                    leading: Icon(Icons.public_rounded, color: colors.tertiary),
                    title: Text(loc.freeLegal),
                    subtitle: Text('Ulke, kanal ve kategori sec', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
                    trailing: Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FreeTvScreen())),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Mevcut Kaynaklar ──
                if (state.allSources.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.list_alt_rounded,
                    title: 'Mevcut Kaynaklar',
                    subtitle: '${state.allSources.length} kaynak aktif',
                  ),
                  _SettingsCard(
                    child: Column(
                      children: [
                        for (var i = 0; i < state.allSources.length; i++)
                          ListTile(
                            leading: Icon(
                              state.allSources[i].isActive
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined,
                              color: state.allSources[i].isActive
                                  ? Colors.green
                                  : Colors.red,
                              size: 20,
                            ),
                            title: Text(
                              _sourceLabel(state.allSources[i]),
                              style: TextStyle(
                                fontSize: 13,
                                color: state.allSources[i].isActive
                                    ? null
                                    : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              '${state.allSources[i].channelCount ?? 0} kanal',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    state.allSources[i].isActive
                                        ? Icons.remove_circle_outline
                                        : Icons.add_circle_outline,
                                    color: state.allSources[i].isActive
                                        ? Colors.orange
                                        : Colors.green,
                                    size: 22,
                                  ),
                                  tooltip: state.allSources[i].isActive
                                      ? 'Kapat'
                                      : 'Aç',
                                  onPressed: () {
                                    state.toggleSource(i);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  color: Colors.red,
                                  tooltip: 'Sil',
                                  onPressed: () {
                                    state.removeIptvSource(i);
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ── Oynatici ──
                _SectionHeader(
                  icon: Icons.speed_rounded,
                  title: loc.player,
                  subtitle: loc.speedDesc,
                ),

                _SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.speed_rounded, size: 18, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(loc.connectionSpeed, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(loc.speedDesc, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final speed in PlayerSpeed.options)
                              ChoiceChip(
                                label: Text(speed.label, style: const TextStyle(fontSize: 12)),
                                tooltip: speed.description,
                                selected: _speed?.bufferSecs == speed.bufferSecs,
                                onSelected: (_) => _setSpeed(speed),
                              ),
                          ],
                        ),
                        if (_speed != null) ...[
                          const SizedBox(height: 8),
                          Text(_speed!.description, style: TextStyle(color: colors.primary, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── EPG ──
                _SectionHeader(
                  icon: Icons.calendar_month_rounded,
                  title: loc.epg,
                  subtitle: 'Elektronik Program Kilavuzu',
                ),

                _SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 18, color: colors.primary),
                            const SizedBox(width: 8),
                            Text(loc.epg, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (state.epg != null)
                          Text('${state.epg!.channelCount} kanal icin program yuklendi.',
                              style: TextStyle(color: colors.tertiary, fontSize: 13))
                        else
                          Text(loc.epgDesc, style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _epgController,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          onTapOutside: (_) => _closeKeyboard(),
                          decoration: InputDecoration(
                            hintText: 'https://ornek.com/epg.xml.gz',
                            prefixIcon: const Icon(Icons.calendar_month, size: 18),
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
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: Text(loc.loadEpg),
                            ),
                            if (state.epg != null || state.epgUrl != null) ...[
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: state.clearEpg,
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: Text(loc.remove),
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
                          Text('EPG hatasi: ${state.epgError!}',
                              style: TextStyle(color: colors.error, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Icerek Ayarlari ──
                _SectionHeader(
                  icon: Icons.family_restroom,
                  title: 'Icerek Ayarlari',
                  subtitle: 'Yetiskin icerik filtresi',
                ),
                _SettingsCard(
                  child: SwitchListTile(
                    secondary: Icon(
                      state.showAdultContent ? Icons.warning_amber_rounded : Icons.child_care_rounded,
                      color: state.showAdultContent ? colors.tertiary : colors.primary,
                    ),
                    title: Text('Yetiskin Icerik Goster'),
                    subtitle: Text(
                      state.showAdultContent
                          ? 'Yetiskin icerikler gorunur durumda'
                          : 'Yetiskin icerikler gizli (varsayilan)',
                      style: TextStyle(
                        color: state.showAdultContent ? colors.tertiary : colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    value: state.showAdultContent,
                    onChanged: (value) async {
                      state.setShowAdultContent(value);
                      await SettingsService.saveAdultContent(value);
                    },
                    activeColor: colors.tertiary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),

                // ── Durum ──
                if (state.source != null) ...[
                  const SizedBox(height: 8),
                  _SectionHeader(
                    icon: Icons.info_outline,
                    title: loc.status,
                    subtitle: 'IP baglantisi',
                  ),
                  _SettingsCard(
                    child: ListTile(
                      leading: Icon(Icons.info_outline_rounded, color: colors.onSurfaceVariant),
                      title: Text(loc.savedSource),
                      subtitle: Text('${_sourceLabel(state.source!)} - ${state.channels.length} kanal'),
                      trailing: IconButton(
                        tooltip: loc.remove,
                        icon: Icon(Icons.delete_outline_rounded, color: colors.error),
                        onPressed: state.clearPlaylist,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],

                if (state.error != null)
                  _SettingsCard(
                    color: colors.errorContainer,
                    child: ListTile(
                      leading: Icon(Icons.error_outline_rounded, color: colors.error),
                      title: Text(loc.error),
                      subtitle: Text(state.error!, maxLines: 3),
                    ),
                  ),

                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (state.testProbeActive)
                  _SettingsCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${loc.verified} ${state.testProbeDone}/${state.testProbeTotal}',
                            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
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
                  ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
      ),  // Scaffold
    );  // PopScope
  }

  String _sourceLabel(PlaylistSource source) {
    return switch (source.type) {
      PlaylistSourceType.url => 'URL: ${source.value}',
      PlaylistSourceType.file => 'Dosya: ${source.value.split('/').last}',
      PlaylistSourceType.demo => 'Demo',
      PlaylistSourceType.xtream => 'Xtream',
    };
  }
}

// ═══════════════════════════════════════════════════════
// Widget Yardimcilari
// ═══════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child, this.color});
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _UrlCard extends StatelessWidget {
  const _UrlCard({
    required this.controller,
    required this.isLoading,
    required this.onSubmit,
    required this.loc,
  });

  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSubmit;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.link_rounded, size: 18, color: colors.primary),
                const SizedBox(width: 8),
                Text(loc.urlPlaylist, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text('M3U/M3U8 URL', style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                hintText: 'https://ornek.com/playlist.m3u8',
                prefixIcon: const Icon(Icons.link, size: 18),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isLoading ? null : onSubmit,
                icon: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(isLoading ? 'Yukleniyor...' : loc.loadUrl),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _XtreamCard extends StatefulWidget {
  const _XtreamCard({
    required this.server,
    required this.user,
    required this.pass,
    required this.error,
    required this.busy,
    required this.onSubmit,
    required this.loc,
  });

  final TextEditingController server, user, pass;
  final String? error;
  final bool busy;
  final VoidCallback onSubmit;
  final AppLocalizations loc;

  @override
  State<_XtreamCard> createState() => _XtreamCardState();
}

class _XtreamCardState extends State<_XtreamCard> {
  final _serverFocus = FocusNode();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();
  final _loginFocus = FocusNode();

  @override
  void dispose() {
    _serverFocus.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    _loginFocus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (node == _serverFocus) { _userFocus.requestFocus(); return KeyEventResult.handled; }
      if (node == _userFocus) { _passFocus.requestFocus(); return KeyEventResult.handled; }
      if (node == _passFocus) { _loginFocus.requestFocus(); return KeyEventResult.handled; }
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (node == _userFocus) { _serverFocus.requestFocus(); return KeyEventResult.handled; }
      if (node == _passFocus) { _userFocus.requestFocus(); return KeyEventResult.handled; }
      if (node == _loginFocus) { _passFocus.requestFocus(); return KeyEventResult.handled; }
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      if (node == _loginFocus) { widget.onSubmit(); return KeyEventResult.handled; }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _SettingsCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.dns_rounded, size: 18, color: colors.tertiary),
                ),
                const SizedBox(width: 10),
                Text('Xtream Codes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text('Portal + ${widget.loc.username} + ${widget.loc.password}',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 14),
            Focus(
              focusNode: _serverFocus,
              onKeyEvent: _handleKey,
              child: TextField(
                controller: widget.server,
                autofocus: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => _serverFocus.unfocus(),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'http://sunucu:8080',
                  prefixIcon: const Icon(Icons.dns, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Focus(
              focusNode: _userFocus,
              onKeyEvent: _handleKey,
              child: TextField(
                controller: widget.user,
                autofocus: false,
                textInputAction: TextInputAction.next,
                onTapOutside: (_) => _userFocus.unfocus(),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.loc.username,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Focus(
              focusNode: _passFocus,
              onKeyEvent: _handleKey,
              child: TextField(
                controller: widget.pass,
                autofocus: false,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onTapOutside: (_) => _passFocus.unfocus(),
                onSubmitted: (_) => widget.onSubmit(),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: widget.loc.password,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            if (widget.error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: colors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.error!, style: TextStyle(color: colors.onErrorContainer, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Focus(
              focusNode: _loginFocus,
              onKeyEvent: _handleKey,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.busy ? null : widget.onSubmit,
                  icon: widget.busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.login_rounded, size: 18),
                  label: Text(widget.busy ? widget.loc.connecting : widget.loc.login, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );  // _SettingsCard
  }
}
