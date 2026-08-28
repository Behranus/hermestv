import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/services/parental_lock_service.dart';
import 'package:hermestv/services/screenshot_service.dart';
import 'package:hermestv/services/settings_service.dart';
import 'package:hermestv/services/stream_player.dart';
import 'package:hermestv/services/stream_stats_service.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// TiviMate tarzı 3 kolonlu IPTV oynatıcısı:
/// Sol: Kanal listesi | Orta: Canlı yayın | Sağ: EPG zaman çizelgesi
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.channels,
    required this.initialIndex,
  });

  final List<Channel> channels;
  final int initialIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final StreamPlayer _player;
  late int _index;
  int _panelIndex = 0; // Panelde seçim indeksi (ok tuşları)
  bool _showPanel = false;

  bool _buffering = true;
  String? _error;
  bool _overlayVisible = true;
  Timer? _overlayTimer;
  Timer? _retryTimer;
  int _errorRetries = 0;
  bool _hasPlayed = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  double _volume = 1.0;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;
  double _bufferSecs = 0.1;

  List<SubtitleInfo> _subtitleTracks = [];
  String? _activeSubtitleId;
  String? _subtitleText;
  List<AudioTrackInfo> _audioTrackList = [];
  String? _activeAudioTrackId;
  DateTime _lastPositionAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Gemini altyazı çevirisi
  bool _geminiTranslate = true;
  String? _translatedSubtitleText;
  String _translateTargetLang = 'tr';
  Timer? _subtitleTranslateTimer;

  // Panel modu: false = sol kanal listesi, true = sağ EPG
  bool _showEpgPanel = false;

  // Panel filtresi
  String _panelFilterGroup = 'all';
  List<String> _panelGroups = [];
  List<Channel> _panelFilteredChannels = [];

  // Ekran oranı
  BoxFit _boxFit = BoxFit.contain;

  // Ağ istatistikleri
  final _statsService = StreamStatsService();
  StreamStats _currentStats = const StreamStats(
    latencyMs: 0, bandwidthBps: 0, estimatedFps: 30);
  bool _showStats = false;
  bool _isFullScreen = false;

  // Ekran görüntüsü
  final _screenshotKey = GlobalKey();



  Channel get _channel => widget.channels[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _player = createStreamPlayer(bufferSecs: _bufferSecs);
    _subscribe();
    WakelockPlus.enable();
    _loadSettings();
    _startStats();
    _open(_channel);
    _buildPanelGroups();
  }

  void _buildPanelGroups() {
    final g = <String>{};
    for (final c in widget.channels) {
      g.add(c.displayGroup);
    }
    final sorted = g.toList()..sort();
    _panelGroups = ['all', ...sorted];
    _updatePanelChannels();
  }

  void _updatePanelChannels() {
    if (_panelFilterGroup == 'all') {
      _panelFilteredChannels = List.from(widget.channels);
    } else {
      _panelFilteredChannels = widget.channels
          .where((c) => c.displayGroup == _panelFilterGroup)
          .toList();
    }
    // Seçili indeks geçerli aralıkta mı?
    if (_panelIndex >= _panelFilteredChannels.length) {
      _panelIndex = _panelFilteredChannels.isEmpty ? 0 : 0;
    }
  }

  void _panelRightArrow() {
    // Kategori sayısı önemli değil — geçiş her zaman çalışsın
    final currentIdx = _panelGroups.indexOf(_panelFilterGroup);
    if (currentIdx < 0 || currentIdx >= _panelGroups.length - 1) {
      _panelFilterGroup = _panelGroups.first;
    } else {
      _panelFilterGroup = _panelGroups[currentIdx + 1];
    }
    _panelIndex = 0; // Kategori değişince başa dön
    _updatePanelChannels();
    setState(() {});
  }

  void _panelLeftArrow() {
    // Kategori sayısı önemli değil — geçiş her zaman çalışsın
    final currentIdx = _panelGroups.indexOf(_panelFilterGroup);
    if (currentIdx <= 0) {
      _panelFilterGroup = _panelGroups.last;
    } else {
      _panelFilterGroup = _panelGroups[currentIdx - 1];
    }
    _panelIndex = 0; // Kategori değişince başa dön
    _updatePanelChannels();
    setState(() {});
  }



  Future<void> _loadSettings() async {
    final speed = await SettingsService.loadSpeed();
    final volume = await SettingsService.loadVolume();
    if (!mounted) return;
    _bufferSecs = speed.bufferSecs;
    _player.bufferSecs = _bufferSecs;
    await _player.setVolume(volume);
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _volumeHudTimer?.cancel();
    _retryTimer?.cancel();
    _subtitleTranslateTimer?.cancel();
    _statsService.dispose();
    WakelockPlus.disable();
    unawaited(_player.dispose());
    super.dispose();
  }

  // Gemini altyazı çevirisi
  void _onSubtitleTextChanged(String? text) {
    if (!_geminiTranslate || text == null || text.trim().isEmpty) {
      setState(() => _translatedSubtitleText = null);
      return;
    }
    // Debounce: 300ms bekle, çeviriyi tetikle
    _subtitleTranslateTimer?.cancel();
    _subtitleTranslateTimer = Timer(const Duration(milliseconds: 300), () {
      _translateSubtitleText(text);
    });
  }

  Future<void> _translateSubtitleText(String original) async {
    if (!_geminiTranslate) return;
    try {
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(original)}&langpair=en|$_translateTargetLang',
      );
      final resp = await http.get(url)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final translated = data['responseData']?['translatedText'] as String?;
        if (translated != null && translated.isNotEmpty && mounted) {
          setState(() => _translatedSubtitleText = translated);
        }
      }
    } catch (_) {
      // Hata durumunda orijinal metni göster
    }
  }

  void _toggleGeminiTranslate() {
    setState(() {
      _geminiTranslate = !_geminiTranslate;
      if (!_geminiTranslate) _translatedSubtitleText = null;
    });
  }

  void _startStats() {
    _statsService.stats.listen((s) {
      if (mounted) setState(() => _currentStats = s);
    });
    _statsService.start(_channel.url);
  }

  void _subscribe() {
    _player.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    });
    _player.error.listen((e) {
      if (!mounted) return;
      if (_errorRetries < 1) {
        _errorRetries++;
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(seconds: 2 + _errorRetries), () {
          if (mounted) _open(_channel);
        });
      } else {
        setState(() => _error = e);
      }
    });
    _player.playing.listen((p) {
      if (!mounted) return;
      if (p) {
        _errorRetries = 0;
        _hasPlayed = true;
      }
    });
    _player.volume.listen((v) {
      if (!mounted) return;
      setState(() => _volume = v);
    });
    _player.position.listen((p) {
      if (!mounted) return;
      final now = DateTime.now();
      if (now.difference(_lastPositionAt) < const Duration(milliseconds: 500)) return;
      _lastPositionAt = now;
      setState(() => _position = p);
    });
    _player.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.subtitleTracks.listen((tracks) {
      if (mounted) setState(() => _subtitleTracks = tracks);
    });
    _player.subtitleText.listen((text) {
      if (mounted) {
        setState(() => _subtitleText = text);
        _onSubtitleTextChanged(text);
      }
    });
    _player.activeSubtitleId.listen((id) {
      if (mounted && id != null) setState(() => _activeSubtitleId = id);
    });
    _player.audioTracks.listen((tracks) {
      if (mounted) setState(() => _audioTrackList = tracks);
    });
    _player.activeAudioTrackId.listen((id) {
      if (mounted && id != null) setState(() => _activeAudioTrackId = id);
    });
  }

  void _open(Channel channel) {
    _retryTimer?.cancel();
    setState(() {
      _buffering = true;
      _error = null;
      _hasPlayed = false;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    try {
      unawaited(_player.open(channel.url, subtitleUrl: channel.subtitleUrl));
    } catch (e) {
      if (mounted) setState(() => _error = 'Akış açılamadı: $e');
    }
    _statsService.stop();
    _statsService.start(channel.url);
    _scheduleOverlayHide();
  }

  void _openUser(Channel channel) {
    _errorRetries = 0;
    _open(channel);
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _overlayVisible && !_buffering && _error == null && !_showPanel) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  void _toggleOverlay() {
    setState(() => _overlayVisible = !_overlayVisible);
    if (_overlayVisible) _scheduleOverlayHide();
  }

  Future<void> _changeVolume(double delta) async {
    final next = (_volume + delta).clamp(0.0, 1.0);
    await _player.setVolume(next);
    SettingsService.saveVolume(next);
    _flashVolumeHud();
  }

  void _flashVolumeHud() {
    _volumeHudTimer?.cancel();
    setState(() => _showVolumeHud = true);
    _volumeHudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showVolumeHud = false);
    });
  }

  void _showEpgInfo(AppState state) {

  }

  // ==================== Panel Kontrolleri ====================

  void _togglePanel() {
    setState(() {
      _showPanel = !_showPanel;
      if (_showPanel) {
        // Mevcut kanalın kategorisini seç
        _panelFilterGroup = _channel.displayGroup;
        if (!_panelGroups.contains(_panelFilterGroup)) {
          _panelFilterGroup = 'all';
        }
        _updatePanelChannels();
        // Filtrelenmiş listede mevcut kanalı bul
        _panelIndex = _panelFilteredChannels.indexOf(_channel);
        if (_panelIndex < 0) _panelIndex = 0;
        _overlayVisible = true;
        _overlayTimer?.cancel();
      } else {
        _showEpgPanel = false;
        _scheduleOverlayHide();
      }
    });
  }

  void _closePanel() {
    if (!_showPanel) return;
    setState(() {
      _showPanel = false;
      _showEpgPanel = false;
    });
    _scheduleOverlayHide();
  }

  void _switchChannel(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.channels.length) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() {
      _index = next;
    });
    _openUser(_channel);
    _showEpgInfo(context.read<AppState>());
    // Panel açıksa kanal listesini de güncelle
    if (_showPanel) {
      _updatePanelChannels();
    }
  }

  void _selectChannel(int index) {
    if (index < 0 || index >= widget.channels.length) return;
    setState(() => _index = index);
    _openUser(_channel);
    _showEpgInfo(context.read<AppState>());
    _updatePanelChannels();
  }

  /// Paneldeki filtrelenmiş listeden kanal seç — orijinal listedeki indeksi bul
  void _selectPanelChannel(int panelIdx) {
    if (panelIdx < 0 || panelIdx >= _panelFilteredChannels.length) return;
    final ch = _panelFilteredChannels[panelIdx];
    final origIdx = widget.channels.indexOf(ch);
    if (origIdx >= 0) {
      setState(() => _index = origIdx);
      _openUser(_channel);
      _showEpgInfo(context.read<AppState>());
      _updatePanelChannels();
    }
  }

  void _showMainMenu() {
    _overlayTimer?.cancel();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Seçenekler', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.subtitles, color: Colors.white70),
              title: const Text('Altyazılar', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _showSubtitlesMenu(); },
            ),
            ListTile(
              leading: const Icon(Icons.volume_up, color: Colors.white70),
              title: const Text('Ses Parçaları', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                _activeAudioTrackId ?? 'Varsayılan',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              onTap: () { Navigator.pop(ctx); _showAudioMenu(); },
            ),
            ListTile(
              leading: const Icon(Icons.fast_rewind, color: Colors.white70),
              title: const Text('10 sn Geri Al', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _seekBy(-10); },
            ),
            ListTile(
              leading: const Icon(Icons.fast_forward, color: Colors.white70),
              title: const Text('10 sn İleri Al', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _seekBy(10); },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white70),
              title: const Text('Görüntü Kalitesi', style: TextStyle(color: Colors.white)),
              subtitle: Text(_boxFit == BoxFit.contain ? 'Otomatik' : _boxFit == BoxFit.fill ? 'Tam Ekran' : _boxFit == BoxFit.cover ? 'Kapla' : 'Özel',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
              onTap: () { Navigator.pop(ctx); _showAspectRatio(context); },
            ),
            ListTile(
              leading: Icon(_geminiTranslate ? Icons.translate : Icons.translate, color: _geminiTranslate ? Colors.green : Colors.white70),
              title: Text('Canlı Çeviri (MyMemory)', style: TextStyle(color: _geminiTranslate ? Colors.green : Colors.white)),
              subtitle: Text(_geminiTranslate ? 'İngilizce → Türkçe çeviri aktif' : 'Altyazıları otomatik Türkçeye çevir',
                style: TextStyle(color: _geminiTranslate ? Colors.green.withValues(alpha:0.7) : Colors.white38, fontSize: 12)),
              onTap: () { _toggleGeminiTranslate(); Navigator.pop(ctx); },
            ),
            ListTile(
              leading: const Icon(Icons.aspect_ratio, color: Colors.white70),
              title: const Text('Ekran Oranı', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _showAspectRatio(context); },
            ),
            ListTile(
              leading: const Icon(Icons.bedtime_outlined, color: Colors.white70),
              title: const Text('Uyku Zamanlayıcı', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _showSleepTimer(context); },
            ),
            ListTile(
              leading: Icon(_volume == 0 ? Icons.volume_off : _volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                color: Colors.white70),
              title: Text('Ses: ${(_volume * 100).round()}%', style: const TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); },
            ),
            ListTile(
              leading: Icon(_showStats ? Icons.analytics : Icons.analytics_outlined, color: Colors.white70),
              title: Text('Ağ İstatistikleri: ${_showStats ? 'Açık' : 'Kapalı'}',
                style: const TextStyle(color: Colors.white)),
              onTap: () { setState(() => _showStats = !_showStats); Navigator.pop(ctx); },
            ),
            ListTile(
              leading: const Icon(Icons.screenshot, color: Colors.white70),
              title: const Text('Ekran Görüntüsü Al', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final path = await ScreenshotService.capture(_screenshotKey);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(path != null ? 'Kaydedildi: $path' : 'Ekran görüntüsü alınamadı')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white70),
              title: Text(_isFullScreen ? 'Tam Ekrandan Çık' : 'Tam Ekran', style: const TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); _toggleFullScreen(); },
            ),
            const SizedBox(height: 16),
          ],
        ),  // Column
      ),  // SingleChildScrollView
      ),  // ConstrainedBox
      );  // SafeArea
    },
    ).then((_) {
      if (mounted) _scheduleOverlayHide();
    });
  }

  Future<void> _toggleFullScreen() async {
    try {
      final wm = windowManager;
      final isFull = await wm.isFullScreen();
      if (isFull) {
        await wm.setFullScreen(false);
        await wm.setAlwaysOnTop(false);
      } else {
        await wm.setFullScreen(true);
        await wm.setAlwaysOnTop(true);
      }
      if (mounted) setState(() => _isFullScreen = !isFull);
    } catch (e) {
      // window_manager desteklenmiyorsa fallback: SystemChrome
      try {
        if (_isFullScreen) {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
        if (mounted) setState(() => _isFullScreen = !_isFullScreen);
      } catch (_) {}
    }
  }

  void _seekBy(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);
    _player.seek(clamped);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // ---- Geri tuşu: panel→overlay→çıkış ----
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (_showPanel) { _closePanel(); return KeyEventResult.handled; }
      if (_overlayVisible) { setState(() => _overlayVisible = false); return KeyEventResult.handled; }
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    // ---- OK/Enter/Select: her zaman kanal listesini aç/kapat ----
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      if (_showPanel) {
        _selectPanelChannel(_panelIndex);
        _closePanel();
      } else {
        _togglePanel();
      }
      return KeyEventResult.handled;
    }

    // ---- Space: overlay aç/kapat ----
    if (key == LogicalKeyboardKey.space) {
      _toggleOverlay();
      return KeyEventResult.handled;
    }

    // ---- Paneldeyken ok tuşları ----
    if (_showPanel) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _panelIndex = (_panelIndex - 1).clamp(0, (_panelFilteredChannels.length - 1).clamp(0, 9999)));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _panelIndex = (_panelIndex + 1).clamp(0, (_panelFilteredChannels.length - 1).clamp(0, 9999)));
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _panelRightArrow();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        _panelLeftArrow();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // ---- Ana mod: panel kapalı ----
    if (key == LogicalKeyboardKey.arrowUp) {
      _switchChannel(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _switchChannel(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _changeVolume(-0.1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _showMainMenu();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showSubtitlesMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SubtitlesSheet(
        tracks: _subtitleTracks,
        activeId: _activeSubtitleId,
        geminiTranslate: _geminiTranslate,
        onToggleGeminiTranslate: _toggleGeminiTranslate,
      ),
    );
    if (selected == null || !mounted) return;
    if (selected == 'off') {
      await _player.disableSubtitles();
      setState(() => _activeSubtitleId = 'off');
    } else if (selected == 'file') {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub'],
      );
      if (result.isEmpty || !mounted) return;
      final path = result.first.path;
      if (path == null) return;
      await _player.setExternalSubtitle('file://$path');
      setState(() => _activeSubtitleId = 'file://$path');
    } else {
      await _player.setSubtitleTrackById(selected);
      setState(() => _activeSubtitleId = selected);
    }
  }

  // ==================== Ses Seçimi ====================

  Future<void> _showAudioMenu() async {
    if (_audioTrackList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu yayında birden fazla ses parçası bulunamadı')),
      );
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ses Parçaları', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final t in _audioTrackList)
              ListTile(
                leading: Icon(
                  t.id == _activeAudioTrackId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: t.id == _activeAudioTrackId ? const Color(0xFF1E88E5) : Colors.white54,
                ),
                title: Text(t.title, style: const TextStyle(color: Colors.white)),
                subtitle: t.language != null ? Text(t.language!, style: const TextStyle(color: Colors.white38, fontSize: 12)) : null,
                onTap: () {
                  Navigator.pop(ctx, t.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      await _player.setAudioTrackById(selected);
    }
  }

  // ==================== Uyku Zamanlayıcı ====================

  Timer? _sleepTimer;

  void _showSleepTimer(BuildContext context) {
    showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF161B22),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Uyku Zamanlayıcı',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (_sleepTimer != null)
              ListTile(
                leading: const Icon(Icons.timer_off, color: Colors.red),
                title: const Text('Zamanlayıcıyı iptal et', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _sleepTimer?.cancel();
                  setState(() => _sleepTimer = null);
                  Navigator.pop(ctx);
                },
              ),
            for (final mins in [15, 30, 45, 60, 90, 120])
              ListTile(
                leading: Icon(Icons.timer, color: Colors.white70),
                title: Text('$mins dakika', style: const TextStyle(color: Colors.white)),
                subtitle: Text('${(mins / 60).toStringAsFixed(1)} saat',
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  _sleepTimer?.cancel();
                  _sleepTimer = Timer(Duration(minutes: mins), () {
                    if (mounted) {
                      _player.pause();
                      Navigator.of(context).pop();
                    }
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$mins dakika sonra duracak')),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ==================== Ekran Oranı ====================

  void _showAspectRatio(BuildContext context) {
    showModalBottomSheet<BoxFit>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF161B22),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ekran Oranı',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final entry in {
              BoxFit.contain: 'Otomatik (Sığdır)',
              BoxFit.fill: 'Tam Ekran (Doldur)',
              BoxFit.cover: 'Kapla (Kırp)',
              BoxFit.fitWidth: 'Genişliği Sığdır',
              BoxFit.fitHeight: 'Yüksekliği Sığdır',
            }.entries)
              ListTile(
                leading: Icon(
                  entry.key == _boxFit ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: entry.key == _boxFit ? const Color(0xFF1E88E5) : Colors.white54,
                ),
                title: Text(entry.value, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  setState(() => _boxFit = entry.key);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final nowProgram = state.nowPlaying(_channel);
    final nextProgram = state.nextProgram(_channel);
    final isLive = (_player.isLive ?? false) ||
        (_duration == Duration.zero && _position == Duration.zero);

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onHover: (event) {
            if (!_showPanel) {
              final screenW = MediaQuery.of(context).size.width;
              if (event.position.dx >= screenW - 60) {
                _togglePanel();
              }
            }
          },
          child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleOverlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ana içerik: her zaman tam ekran video (RepaintBoundary ile sarılı)
              RepaintBoundary(
                key: _screenshotKey,
                child: _player.buildVideo(fit: _boxFit),
              ),

              // Buffering göstergesi — beyaz ekran yerine merkezi spinner
              if (_buffering && _error == null && !_hasPlayed)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white70, strokeWidth: 2.5),
                          SizedBox(height: 12),
                          Text('Yükleniyor...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),

              // Kanal geçiş buffer (oynarken donarsa hafif overlay)
              if (_buffering && _hasPlayed && _error == null)
                const Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2),
                  ),
                ),

              // Sol overlay: kanal listesi — Focus ile kumanda tuşları
              if (_showPanel)
                Positioned(
                  left: 0, top: 0, bottom: 0, width: 280,
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is! KeyDownEvent) return KeyEventResult.ignored;
                      final key = event.logicalKey;
                      if (key == LogicalKeyboardKey.arrowRight) {
                        _panelRightArrow();
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.arrowLeft) {
                        _panelLeftArrow();
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.arrowUp) {
                        setState(() => _panelIndex = (_panelIndex - 1).clamp(0, (_panelFilteredChannels.length - 1).clamp(0, 9999)));
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.arrowDown) {
                        setState(() => _panelIndex = (_panelIndex + 1).clamp(0, (_panelFilteredChannels.length - 1).clamp(0, 9999)));
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
                        _selectPanelChannel(_panelIndex);
                        _closePanel();
                        return KeyEventResult.handled;
                      }
                      if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
                        _closePanel();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: _TiviMateChannelList(
                    channels: _panelFilteredChannels,
                    selectedIndex: _panelIndex,
                    filterGroup: _panelFilterGroup,
                    groups: _panelGroups,
                    onSelect: (i) {
                      if (_panelIndex == i) {
                        // Aynı kanala tekrar tıklandı → aç
                        _selectPanelChannel(i);
                        _closePanel();
                      } else {
                        // Farklı kanala tıklandı → sadece seç
                        setState(() => _panelIndex = i);
                      }
                    },
                    filterGroupChanged: (g) {
                      setState(() {
                        _panelFilterGroup = g;
                        _updatePanelChannels();
                      });
                    },
                    onClose: _closePanel,
                  ),
                  ),
                ),

              // Sağ overlay: EPG zaman çizelgesi
              if (_showPanel && _showEpgPanel)
                Positioned(
                  right: 0, top: 0, bottom: 0, width: 320,
                  child: _EpgTimeline(
                    channel: _channel,
                    state: state,
                    nowProgram: nowProgram,
                    nextProgram: nextProgram,
                  ),
                ),

              // Ekran üstü altyazı (orijinal + çevirili)
              if (_subtitleText != null && _subtitleText!.isNotEmpty)
                Positioned(
                  left: 24, right: 24, bottom: 80,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Orijinal altyazı
                            Text(
                              _subtitleText!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white, fontSize: 20, height: 1.3,
                                shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1))],
                              ),
                            ),
                            // Çevrilmiş altyazı (eğer aktifse)
                            if (_geminiTranslate && _translatedSubtitleText != null && _translatedSubtitleText!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _translatedSubtitleText!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 18, height: 1.3,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Hata durumu
              if (_error != null)
                _ErrorOverlay(
                  message: _error!,
                  onRetry: () => _openUser(_channel),
                  onBack: () => Navigator.of(context).pop(),
                ),



              // Üst bar (kanal bilgisi)
              if (_overlayVisible && _error == null && !_showPanel)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_channel.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                if (nowProgram != null && nowProgram.title != null)
                                  Text(nowProgram.title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.amber, fontSize: 13)),
                                Text('${_channel.displayGroup} • ${_index + 1}/${widget.channels.length}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                              child: const Text('CANLI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            )
                          else
                            Text('${_fmt(_position)} / ${_fmt(_duration)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ),



              // Üst gradient — her zaman overlayVisible iken göster
              if (_overlayVisible && _error == null)
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.center,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                  ),
                ),

              if (_showVolumeHud)
                _VolumeHud(volume: _volume),

              // Ağ istatistikleri overlay (sağ üst)
              if (_showStats && _overlayVisible && !_showPanel && _error == null)
                Positioned(
                  top: 80, right: 12,
                  child: _NetworkStatsOverlay(stats: _currentStats, channelName: _channel.name),
                ),

              // Alt kontroller kaldırıldı — sadece sağ ok tuşuyla menü açılır

              // Alt kanal şeridi kaldırıldı — sadece sol panel ile kanal değiştirilir
            ],
          ),
        ),
        ),
      ),
    );
  }
  
}

// ==================== TiviMate Kanal Listesi ====================

class _TiviMateChannelList extends StatefulWidget {
  const _TiviMateChannelList({
    required this.channels,
    required this.selectedIndex,
    required this.filterGroup,
    required this.groups,
    required this.onSelect,
    required this.filterGroupChanged,
    required this.onClose,
  });

  final List<Channel> channels;
  final int selectedIndex;
  final String filterGroup;
  final List<String> groups;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> filterGroupChanged;
  final VoidCallback onClose;

  @override
  State<_TiviMateChannelList> createState() => _TiviMateChannelListState();
}

class _TiviMateChannelListState extends State<_TiviMateChannelList> {
  late final ScrollController _scroll;
  Set<String> _lockedChannels = {};

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _loadLocks();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  Future<void> _loadLocks() async {
    final locked = await ParentalLockService.getLockedChannels();
    if (mounted) setState(() => _lockedChannels = locked.toSet());
  }

  Future<bool> _checkPin(String channelId) async {
    final isLocked = await ParentalLockService.isLocked(channelId);
    if (!isLocked) return true;
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          title: const Text('Kanal Kilitli', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl, obscureText: true, keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
            decoration: const InputDecoration(
              hintText: 'PIN girin', hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1E88E5))),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Tamam')),
          ],
        );
      },
    );
    if (pin == null) return false;
    return await ParentalLockService.verifyPin(pin);
  }

  @override
  void didUpdateWidget(covariant _TiviMateChannelList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToSelected() {
    if (!_scroll.hasClients) return;
    const itemExtent = 56.0;
    final target = widget.selectedIndex * itemExtent;
    final viewport = _scroll.position.viewportDimension;
    if (target < _scroll.offset) {
      _scroll.jumpTo(target);
    } else if (target + itemExtent > _scroll.offset + viewport) {
      _scroll.jumpTo(target - viewport + itemExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = widget.channels;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Column(
      children: [
          // Üst bar: Playlist başlığı
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F23),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.queue_music, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Playlist 1 • Tüm Kanallar',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Kategori seçici — TiviMate tarzı yatay çubuk
          Container(
            height: 38,
            color: const Color(0xFF0D1117),
            child: Row(
              children: [
                // Sol ok butonu
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left, color: Colors.white54, size: 20),
                const SizedBox(width: 2),
                // Kategori listesi
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: widget.groups.length,
                    itemBuilder: (context, i) {
                      final g = widget.groups[i];
                      final selected = widget.filterGroup == g;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: selected ? Colors.blue.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: selected
                                ? Border.all(color: Colors.blueAccent, width: 1.5)
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            i == 0 ? ' Tümü ' : ' $g ',
                            style: TextStyle(
                              fontSize: 11,
                              color: selected ? Colors.white : Colors.white60,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                const SizedBox(width: 4),
              ],
            ),
          ),

          // Seçili kategori başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: Colors.blue.withValues(alpha: 0.15),
            child: Row(
              children: [
                const Icon(Icons.folder, color: Colors.blueAccent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.filterGroup == 'all' ? 'Tüm Kanallar' : widget.filterGroup,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${widget.channels.length} kanal',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          // Kanal listesi — ok tuşları üst panele iletilsin
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              itemCount: channels.length,
              itemExtent: 56,
              itemBuilder: (context, i) {
                final c = channels[i];
                final selected = i == widget.selectedIndex;
                return InkWell(
                  onTap: () => widget.onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    color: selected
                        ? Colors.blue.withValues(alpha: 0.3)
                        : i.isEven
                            ? Colors.white.withValues(alpha: 0.02)
                            : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        // Kanal numarası
                        SizedBox(
                          width: 32,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: selected ? Colors.amber : Colors.white54,
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        // Kanal logosu
                        _TiviMateLogo(channel: c, size: 36),
                        const SizedBox(width: 8),
                        // Kanal adı ve grup
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (_lockedChannels.contains(c.url))
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.lock, color: Colors.orange, size: 12),
                                    ),
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: selected ? Colors.white : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                c.displayGroup,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        // Seçili kanal göstergesi
                        if (selected)
                          Container(
                            width: 3,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
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

class _TiviMateLogo extends StatelessWidget {
  const _TiviMateLogo({required this.channel, required this.size});
  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = channel.logo;
    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(logo, width: size, height: size, fit: BoxFit.cover,
          cacheWidth: (size * 2).round(),
          errorBuilder: (_, _, _) => _fallback(),
          loadingBuilder: (_, child, progress) => progress == null ? child : _fallback()),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size, height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.tv, color: Colors.white38, size: 20),
    );
  }
}

// ==================== Kanal Bilgi Çubuğu (alt kısım) ====================

class _ChannelInfoBar extends StatelessWidget {
  const _ChannelInfoBar({
    required this.channel,
    required this.index,
    required this.total,
    this.nowProgram,
    this.nextProgram,
    required this.isLive,
  });

  final Channel channel;
  final int index, total;
  final String? nowProgram, nextProgram;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          // Kanal numarası
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          // Kanal adı + grup
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  channel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${channel.displayGroup} • $index/$total',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          // CANLI rozeti
          if (isLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('CANLI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

// ==================== EPG Zaman Çizelgesi (sağ panel) ====================

class _EpgTimeline extends StatelessWidget {
  const _EpgTimeline({
    required this.channel,
    required this.state,
    this.nowProgram,
    this.nextProgram,
  });

  final Channel channel;
  final AppState state;
  final dynamic nowProgram;
  final dynamic nextProgram;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final programs = <_EpgEntry>[];

    // Mevcut ve sonraki programları ekle
    if (nowProgram != null) {
      programs.add(_EpgEntry(
        title: nowProgram.title ?? 'Bilgi yok',
        start: nowProgram.start,
        end: nowProgram.end,
        isNow: true,
      ));
    }
    if (nextProgram != null) {
      programs.add(_EpgEntry(
        title: nextProgram.title ?? 'Bilgi yok',
        start: nextProgram.start,
        end: nextProgram.end,
        isNow: false,
      ));
    }

    // Sonraki programları da ekle (simülasyon)
    if (programs.isEmpty) {
      for (var i = 0; i < 8; i++) {
        final start = now.add(Duration(hours: i));
        final end = start.add(const Duration(hours: 1));
        programs.add(_EpgEntry(
          title: i == 0 ? 'Program' : 'Program ${i + 1}',
          start: start,
          end: end,
          isNow: i == 0,
        ));
      }
    }

    return Container(
      color: const Color(0xFF0F0F23),
      child: Column(
        children: [
          // Üst bilgi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                _TiviMateLogo(channel: channel, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        channel.displayGroup,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Program başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF16213E),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.live_tv, color: Colors.red, size: 16),
                SizedBox(width: 6),
                Text('Program', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // Program listesi
          Expanded(
            child: ListView.builder(
              itemCount: programs.length,
              itemBuilder: (context, i) {
                final p = programs[i];
                return _EpgEntryTile(entry: p);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpgEntry {
  final String title;
  final DateTime? start;
  final DateTime? end;
  final bool isNow;

  _EpgEntry({required this.title, this.start, this.end, required this.isNow});

  String _time(DateTime t) {
    final local = t.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String get timeRange {
    if (start == null) return '';
    if (end != null) return '${_time(start!)} - ${_time(end!)}';
    return _time(start!);
  }

  String get durationText {
    if (start == null || end == null) return '';
    final diff = end!.difference(start!);
    return '${diff.inMinutes} min';
  }
}

class _EpgEntryTile extends StatelessWidget {
  const _EpgEntryTile({required this.entry});
  final _EpgEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: entry.isNow ? Colors.blue.withValues(alpha: 0.15) : Colors.transparent,
        border: const Border(bottom: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: Row(
        children: [
          // Saat
          SizedBox(
            width: 60,
            child: Text(
              entry.timeRange,
              style: TextStyle(
                color: entry.isNow ? Colors.amber : Colors.white54,
                fontSize: 12,
                fontWeight: entry.isNow ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Program bilgisi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: entry.isNow ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: entry.isNow ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (entry.durationText.isNotEmpty)
                  Text(
                    entry.durationText,
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
              ],
            ),
          ),
          // Şimdi yayınlandı göstergesi
          if (entry.isNow)
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== Buffering Indicator ====================

class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                SizedBox(width: 10),
                Text('Kanal yükleniyor…', style: TextStyle(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Error Overlay ====================

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.message, required this.onRetry, required this.onBack});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 56),
              const SizedBox(height: 16),
              const Text('Akış açılamadı', style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 8),
              Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar Dene')),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(onPressed: onBack, icon: const Icon(Icons.arrow_back),
                    label: const Text('Geri'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Controls Overlay ====================

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.channel, required this.index, required this.total,
    required this.position, required this.duration, required this.isLive,
    required this.streamInfo, required this.nowProgram, required this.nextProgram,
    required this.nextStart, required this.onBack, required this.onChannelUp,
    required this.onChannelDown, required this.onSubtitles,
    required this.onSleepTimer, required this.onAspectRatio, this.onTogglePanel,
    this.geminiTranslate = false, this.onToggleGeminiTranslate,
  });

  final Channel channel;
  final int index, total;
  final Duration position, duration;
  final bool isLive;
  final String? streamInfo, nowProgram, nextProgram;
  final DateTime? nextStart;
  final VoidCallback onBack, onChannelUp, onChannelDown, onSubtitles;
  final VoidCallback onSleepTimer, onAspectRatio;
  final VoidCallback? onTogglePanel;
  final bool geminiTranslate;
  final VoidCallback? onToggleGeminiTranslate;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: false,
      child: SafeArea(
        child: Column(
          children: [
            // Üst bar: kanal bilgisi + EPG + CANLI rozeti
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(onPressed: onBack, tooltip: 'Geri',
                    icon: const Icon(Icons.arrow_back, color: Colors.white)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        if (nowProgram != null && nowProgram!.isNotEmpty)
                          Text(nowProgram!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.amber, fontSize: 13)),
                        Text('${channel.displayGroup} • ${index + 1}/$total',
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        if (streamInfo != null && streamInfo!.isNotEmpty)
                          Text(streamInfo!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (isLive)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                      child: const Text('CANLI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    )
                  else
                    Text('${_fmt(position)} / ${_fmt(duration)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Spacer(),
            // Alt kontrol çubuğu — TiviMate tarzı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // İlerleme çubuğu (VOD için)
                  if (!isLive)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(_fmt(position), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: duration.inMilliseconds > 0
                                  ? position.inMilliseconds / duration.inMilliseconds : 0,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(Color(0xFF1E88E5)),
                              minHeight: 3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_fmt(duration), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  // Kontrol butonları satırı
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _CtrlBtn(icon: Icons.skip_previous, label: 'Önceki', onTap: onChannelDown, size: 32),
                      if (onTogglePanel != null)
                        _CtrlBtn(icon: Icons.queue_music, label: 'Liste', onTap: onTogglePanel!),
                      _CtrlBtn(icon: Icons.subtitles, label: 'Altyazı (S)', onTap: onSubtitles),
                      _CtrlBtn(
                        icon: Icons.translate,
                        label: geminiTranslate ? 'Çeviri✓' : 'Çeviri',
                        onTap: onToggleGeminiTranslate ?? () {},
                        color: geminiTranslate ? Colors.green : null,
                      ),
                      _CtrlBtn(icon: Icons.aspect_ratio, label: 'Oran (A)', onTap: onAspectRatio),
                      _CtrlBtn(icon: Icons.bedtime_outlined, label: 'Uyku (T)', onTap: onSleepTimer),
                      _CtrlBtn(icon: Icons.skip_next, label: 'Sonraki', onTap: onChannelUp, size: 32),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Kısayol ipuçları
                  const Text(
                    'S:Altyazı  Ç:Çeviri  T:Uyku  A:Ekran Oranı  ←→:Ses  ↑↓:Kanal  OK:Liste',
                    style: TextStyle(color: Colors.white30, fontSize: 9),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),            ],
        ),
      ),
    );
  }
}

// ==================== Ağ İstatistikleri Overlay ====================

class _NetworkStatsOverlay extends StatelessWidget {
  const _NetworkStatsOverlay({required this.stats, required this.channelName});
  final StreamStats stats;
  final String channelName;

  Color _latencyColor() {
    if (stats.latencyMs < 100) return Colors.green;
    if (stats.latencyMs < 300) return Colors.lightGreenAccent;
    if (stats.latencyMs < 800) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 6),
              const Text('Ağ İstatistikleri',
                style: TextStyle(color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 10, color: Colors.white24),
          _StatRow(
            icon: Icons.speed,
            label: 'Gecikme',
            value: stats.latencyDisplay,
            color: _latencyColor(),
          ),
          _StatRow(
            icon: Icons.download,
            label: 'Bant Genişliği',
            value: stats.bandwidthDisplay,
            color: Colors.white70,
          ),
          _StatRow(
            icon: Icons.slow_motion_video,
            label: 'FPS',
            value: stats.fpsDisplay,
            color: Colors.white70,
          ),
          _StatRow(
            icon: Icons.signal_cellular_alt,
            label: 'Kalite',
            value: stats.qualityLevel,
            color: _latencyColor(),
          ),
          const SizedBox(height: 4),
          Text(channelName, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const Spacer(),
          Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}


/// TiviMate tarzı kontrol butonu
class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({required this.icon, required this.label, this.onTap, this.focused = false, this.size = 26, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool focused;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? (focused ? Colors.amber : Colors.white), size: size),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              color: color ?? (focused ? Colors.amber : Colors.white70), fontSize: 9,
              fontWeight: focused ? FontWeight.bold : FontWeight.normal)),            ],
        ),
      ),
    );
  }
}

// ==================== Ağ İstatistikleri Overlay ====================

// ==================== Volume HUD ====================

class _VolumeHud extends StatelessWidget {
  const _VolumeHud({required this.volume});
  final double volume;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0, right: 0, bottom: 40,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Icon(volume == 0 ? Icons.volume_off : volume < 0.5 ? Icons.volume_down : Icons.volume_up,
                color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: volume, minHeight: 6,
                  backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
              )),
              const SizedBox(width: 10),
              Text('${(volume * 100).round()}', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ==================== Subtitles Sheet ====================

class _SubtitlesSheet extends StatelessWidget {
  const _SubtitlesSheet({required this.tracks, required this.activeId, this.geminiTranslate = false, this.onToggleGeminiTranslate});
  final List<SubtitleInfo> tracks;
  final String? activeId;
  final bool geminiTranslate;
  final VoidCallback? onToggleGeminiTranslate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStreamTracks = tracks.isNotEmpty;

    // Altyazı sayısına göre yüksekliği ayarla
    final trackHeight = tracks.length.clamp(0, 8) * 56.0;
    final sheetHeight = 120.0 + trackHeight + 60.0; // başlık + tracks + dosya seçimi

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sürükleme çubuğu + başlık
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.subtitles, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Text('Altyazılar', style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold)),
                  if (tracks.isNotEmpty) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${tracks.length} parça',
                        style: const TextStyle(color: Colors.blueAccent, fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            // Kapalı seçeneği
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Icon(Icons.subtitles_off, size: 20,
                color: (activeId == null || activeId == 'off') ? Colors.green : Colors.white54),
              title: const Text('Kapalı', style: TextStyle(color: Colors.white, fontSize: 15)),
              trailing: (activeId == null || activeId == 'off')
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : null,
              onTap: () => Navigator.of(context).pop('off'),
            ),
            if (hasStreamTracks) ...[
              const Divider(height: 1, color: Colors.white12),
              // Başlık çubuğu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                color: Colors.white.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    const Icon(Icons.wifi, size: 14, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text('Akış Altyazıları (${tracks.length})',
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              // Altyazı listesi —.scroll edilebilir, tek satır sıkışması yok
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 56, endIndent: 16, color: Colors.white10),
                  itemBuilder: (context, i) {
                    final t = tracks[i];
                    final name = t.title?.isNotEmpty == true ? t.title! : '';
                    final lang = t.language?.isNotEmpty == true ? t.language! : '';
                    final isActive = activeId == t.id;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: Icon(
                        isActive ? Icons.subtitles : Icons.subtitles_outlined,
                        size: 20,
                        color: isActive ? Colors.green : Colors.white54,
                      ),
                      title: Text(
                        name.isNotEmpty ? name : 'Parça ${i + 1}',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.white,
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                      subtitle: lang.isNotEmpty
                          ? Text(lang, style: const TextStyle(color: Colors.white38, fontSize: 11))
                          : null,
                      trailing: isActive
                          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                          : null,
                      onTap: () => Navigator.of(context).pop(t.id),
                    );
                  },
                ),
              ),
            ] else ...[
              // Akış altyazısı yoksa bilgi mesajı
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  'Bu yayında yerleşik altyazı bulunamadı',
                  style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],
            const Divider(height: 1, color: Colors.white12),
            // Dosyadan yükle
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.upload_file, size: 20, color: Colors.amber),
              title: const Text('Dosyadan altyazı yükle', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: const Text('SRT, VTT, ASS, SSA, SUB', style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () => Navigator.of(context).pop('file'),
            ),
            const Divider(height: 1, color: Colors.white12),
            ],
        ),
      ),
    );
  }
}

// ==================== Ağ İstatistikleri Overlay ====================


// ==================== Yatay Kanal Seridi (Alt Panel - TiviMate tarzi) ====================

class _HorizontalChannelStrip extends StatefulWidget {
  final List<Channel> channels;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool isVisible;
  const _HorizontalChannelStrip({
    required this.channels,
    required this.currentIndex,
    required this.onSelect,
    this.isVisible = true,
  });
  @override
  State<_HorizontalChannelStrip> createState() => _HorizontalChannelStripState();
}

class _HorizontalChannelStripState extends State<_HorizontalChannelStrip> {
  late ScrollController _scroll;
  int _focusIdx = 0;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _focusIdx = widget.currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_focusIdx));
  }

  @override
  void didUpdateWidget(covariant _HorizontalChannelStrip old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _focusIdx = widget.currentIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(_focusIdx));
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(int idx) {
    if (!_scroll.hasClients) return;
    final offset = idx * 104.0 - 140.0;
    _scroll.animateTo(
      offset.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || widget.channels.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowRight) {
          setState(() => _focusIdx = (_focusIdx + 1).clamp(0, widget.channels.length - 1));
          _scrollTo(_focusIdx);
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          setState(() => _focusIdx = (_focusIdx - 1).clamp(0, widget.channels.length - 1));
          _scrollTo(_focusIdx);
        } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
          widget.onSelect(_focusIdx);
        }
      },
      child: Container(
        height: 90,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xCC000000), Colors.black],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.queue_music, size: 14, color: Colors.white54),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${widget.channels.length} kanal',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text('← → geçiş  OK seç', style: TextStyle(color: Colors.white30, fontSize: 9)),
                ],
              ),
            ),
            SizedBox(
              height: 60,
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                itemCount: widget.channels.length,
                itemBuilder: (ctx, i) {
                  final c = widget.channels[i];
                  final selected = i == widget.currentIndex;
                  return GestureDetector(
                    onTap: () => widget.onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primary.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? colors.primary : Colors.white10,
                          width: selected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: c.logo != null && c.logo!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      c.logo!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _miniFallback(c, colors),
                                    ),
                                  )
                                : _miniFallback(c, colors),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            c.name.length > 12 ? '${c.name.substring(0, 11)}…' : c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                              color: selected ? Colors.white : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniFallback(Channel c, ColorScheme colors) {
    final init = c.name.isNotEmpty ? c.name[0].toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(init, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.primary)),
      ),
    );
  }
}

// ==================== Basit Player Butonu ====================

class _PlayerBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _PlayerBtn({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.white70, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: color ?? Colors.white54, fontSize: 9)),
        ],
      ),
    );
  }
}
