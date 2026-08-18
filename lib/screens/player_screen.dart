import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/services/settings_service.dart';
import 'package:iptv_player/services/stream_player.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tam ekran IPTV oynatıcısı — TiviMate tarzı anlık EPG + TVMate kategorili liste.
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
  int _listIndex = 0;
  bool _showList = false;

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
  double _bufferSecs = 0.5;

  List<SubtitleInfo> _subtitleTracks = [];
  String? _activeSubtitleId;
  String? _subtitleText;
  DateTime _lastPositionAt = DateTime.fromMillisecondsSinceEpoch(0);

  // TiviMate tarzı kanal değiştirme EPG bilgi çubuğu
  bool _showEpgBanner = false;
  String? _epgBannerTitle;
  String? _epgBannerNext;
  String? _epgBannerCategory;
  Timer? _epgBannerTimer;

  // TVMate tarzı kategori navigasyonu
  String _panelFilterGroup = 'all';
  List<String> _panelGroups = [];
  List<Channel> _panelChannels = [];

  Channel get _channel => widget.channels[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _listIndex = _index;
    _player = createStreamPlayer(bufferSecs: _bufferSecs);
    _subscribe();
    WakelockPlus.enable();
    _loadSettings();
    _open(_channel);
    _buildPanelGroups();
  }

  void _buildPanelGroups() {
    final g = <String>{};
    for (final c in widget.channels) {
      g.add(c.displayGroup);
    }
    final sorted = g.toList()..sort();
    final turkish = sorted.where(_isTurkish).toList();
    final rest = sorted.where((x) => !_isTurkish(x)).toList();
    _panelGroups = ['all', ...turkish, ...rest];
    _updatePanelChannels();
  }

  static bool _isTurkish(String g) {
    final l = g.toLowerCase();
    return l.contains('türk') || l.contains('turk') || l.contains('tr |') ||
        l.startsWith('tr ') || l.startsWith('tr|') || l == 'tr' || l.contains('türkiye');
  }

  void _updatePanelChannels() {
    if (_panelFilterGroup == 'all') {
      _panelChannels = List.from(widget.channels);
    } else {
      _panelChannels = widget.channels
          .where((c) => c.displayGroup == _panelFilterGroup)
          .toList();
    }
  }

  void _panelRightArrow() {
    if (_panelGroups.length <= 2) return;
    final currentIdx = _panelGroups.indexOf(_panelFilterGroup);
    if (currentIdx < 0 || currentIdx >= _panelGroups.length - 1) {
      _panelFilterGroup = _panelGroups.first;
    } else {
      _panelFilterGroup = _panelGroups[currentIdx + 1];
    }
    _updatePanelChannels();
    final currentChannel = widget.channels[_index];
    final idxInNew = _panelChannels.indexOf(currentChannel);
    _listIndex = idxInNew >= 0 ? idxInNew : 0;
    setState(() {});
  }

  void _panelLeftArrow() {
    if (_panelFilterGroup != 'all') {
      _panelFilterGroup = 'all';
      _updatePanelChannels();
      final currentChannel = widget.channels[_index];
      final idxInNew = _panelChannels.indexOf(currentChannel);
      _listIndex = idxInNew >= 0 ? idxInNew : 0;
      setState(() {});
    }
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
    _epgBannerTimer?.cancel();
    WakelockPlus.disable();
    unawaited(_player.dispose());
    super.dispose();
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
        _retryTimer = Timer(const Duration(seconds: 3), () {
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
      if (_duration == Duration.zero) return;
      if (!_overlayVisible && !_showEpgBanner) return;
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
      if (mounted) setState(() => _subtitleText = text);
    });
    _player.activeSubtitleId.listen((id) {
      if (mounted && id != null) setState(() => _activeSubtitleId = id);
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
    _scheduleOverlayHide();
  }

  void _openUser(Channel channel) {
    _errorRetries = 0;
    _open(channel);
  }

  void _scheduleOverlayHide() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _overlayVisible && !_buffering && _error == null && !_showList) {
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

  // ==================== TiviMate EPG Banner ====================

  /// Kanal değiştirildiğinde TiviMate tarzı anlık EPG bilgi çubuğunu göster.
  void _showEpgInfo(AppState state) {
    _epgBannerTimer?.cancel();
    final nowProgram = state.nowPlaying(_channel);
    final nextProgram = state.nextProgram(_channel);
    setState(() {
      _showEpgBanner = true;
      _epgBannerTitle = nowProgram?.title;
      _epgBannerNext = nextProgram?.title;
      _epgBannerCategory = _channel.displayGroup;
    });
    // 5 saniye sonra kaybol
    _epgBannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showEpgBanner = false);
    });
  }

  // ==================== Kanal listesi ====================

  void _toggleChannelList() {
    setState(() {
      _showList = !_showList;
      if (_showList) {
        _panelFilterGroup = _channel.displayGroup;
        if (!_panelGroups.contains(_panelFilterGroup)) {
          _panelFilterGroup = 'all';
        }
        _updatePanelChannels();
        final idxInNew = _panelChannels.indexOf(_channel);
        _listIndex = idxInNew >= 0 ? idxInNew : 0;
        _overlayVisible = true;
        _overlayTimer?.cancel();
      } else {
        _panelFilterGroup = 'all';
        _updatePanelChannels();
        _scheduleOverlayHide();
      }
    });
  }

  void _closeList() {
    if (!_showList) return;
    setState(() {
      _showList = false;
      _panelFilterGroup = 'all';
      _updatePanelChannels();
    });
    _scheduleOverlayHide();
  }

  void _moveList(int delta) {
    final next = _listIndex + delta;
    if (next < 0 || next >= _panelChannels.length) return;
    setState(() => _listIndex = next);
  }

  void _selectListChannel() {
    final panelChannel = _panelChannels[_listIndex];
    final globalIndex = widget.channels.indexOf(panelChannel);
    _closeList();
    if (globalIndex == _index) return;
    setState(() => _index = globalIndex);
    _openUser(_channel);
    _showEpgInfo(context.read<AppState>());
  }

  void _selectListChannelAt(int i) {
    if (i < 0 || i >= _panelChannels.length) return;
    _listIndex = i;
    _selectListChannel();
  }

  void _switchChannel(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.channels.length) {
      HapticFeedback.selectionClick();
      return;
    }
    setState(() {
      _index = next;
      _listIndex = next;
    });
    _openUser(_channel);
    _showEpgInfo(context.read<AppState>());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_showList) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveList(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveList(1);
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
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
        _selectListChannel();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
        _closeList();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

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
      _changeVolume(0.1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
      _toggleChannelList();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      _toggleOverlay();
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
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleOverlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _player.buildVideo(fit: BoxFit.contain),
              // Ekran üstü altyazı
              if (_subtitleText != null && _subtitleText!.isNotEmpty)
                Positioned(
                  left: 24, right: 24, bottom: 80,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _subtitleText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 22, height: 1.3,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black, offset: Offset(0, 1))],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              // Yükleme / hata
              if (_buffering && !_hasPlayed && _error == null)
                const _BufferingIndicator()
              else if (_error != null)
                _ErrorOverlay(
                  message: _error!,
                  onRetry: () => _openUser(_channel),
                  onBack: () => Navigator.of(context).pop(),
                ),
              // TiviMate tarzı EPG bilgi çubuğu (kanal değiştirmede anlık görünür)
              if (_showEpgBanner && _error == null && !_showList)
                _EpgInfoBanner(
                  channelName: _channel.name,
                  groupName: _epgBannerCategory ?? _channel.displayGroup,
                  nowTitle: _epgBannerTitle,
                  nextTitle: _epgBannerNext,
                  index: _index,
                  total: widget.channels.length,
                ),
              // Üst/alt kontrol paneli
              if (_overlayVisible && _error == null)
                _ControlsOverlay(
                  channel: _channel,
                  index: _index,
                  total: widget.channels.length,
                  position: _position,
                  duration: _duration,
                  isLive: isLive,
                  streamInfo: _player.streamInfo,
                  nowProgram: nowProgram?.title,
                  nextProgram: nextProgram?.title,
                  nextStart: nextProgram?.start,
                  onBack: () => Navigator.of(context).pop(),
                  onChannelUp: () => _switchChannel(1),
                  onChannelDown: () => _switchChannel(-1),
                  onSubtitles: _showSubtitlesMenu,
                ),
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
              // Kanal listesi paneli
              if (_showList && _error == null)
                _ChannelListPanel(
                  channels: widget.channels,
                  panelChannels: _panelChannels,
                  selectedIndex: _listIndex,
                  currentIndex: _index,
                  filterGroup: _panelFilterGroup,
                  groups: _panelGroups,
                  onSelectIndex: _selectListChannelAt,
                  onClose: _closeList,
                  onRightArrow: _panelRightArrow,
                ),
              if (_showVolumeHud)
                _VolumeHud(volume: _volume),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== TiviMate EPG Banner ====================

/// Kanal değiştirildiğinde üstte kısa süreliğine görünen EPG bilgi çubuğu.
/// TiviMate'in kanal değiştirmedeki "şimdi ne var" bilgisi gibi.
class _EpgInfoBanner extends StatefulWidget {
  const _EpgInfoBanner({
    required this.channelName,
    required this.groupName,
    this.nowTitle,
    this.nextTitle,
    required this.index,
    required this.total,
  });

  final String channelName;
  final String groupName;
  final String? nowTitle;
  final String? nextTitle;
  final int index;
  final int total;

  @override
  State<_EpgInfoBanner> createState() => _EpgInfoBannerState();
}

class _EpgInfoBannerState extends State<_EpgInfoBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16, top: 60, right: 16,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12, width: 1),
            ),
            child: Row(
              children: [
                // Kanal numarası
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kanal adı + grup
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.channelName,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16, fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.groupName,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white60, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Şimdi yayında
                      if (widget.nowTitle != null && widget.nowTitle!.isNotEmpty)
                        Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.red, shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Şimdi: ${widget.nowTitle}',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.lightBlueAccent, fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      // Sıradaki
                      if (widget.nextTitle != null && widget.nextTitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Sonra: ${widget.nextTitle}',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
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
  });

  final Channel channel;
  final int index, total;
  final Duration position, duration;
  final bool isLive;
  final String? streamInfo, nowProgram, nextProgram;
  final DateTime? nextStart;
  final VoidCallback onBack, onChannelUp, onChannelDown, onSubtitles;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _time(DateTime t) {
    final local = t.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      Text('${channel.displayGroup} • ${index + 1}/$total',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      if (streamInfo != null && streamInfo!.isNotEmpty)
                        Text(streamInfo!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      if (nowProgram != null && nowProgram!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.play_arrow, size: 14, color: Colors.lightBlueAccent),
                          const SizedBox(width: 4),
                          Expanded(child: Text('Şimdi: $nowProgram', maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13))),
                        ]),
                      ],
                      if (nextProgram != null && nextProgram!.isNotEmpty)
                        Text('Sonra: $nextProgram (${nextStart != null ? _time(nextStart!) : ''})',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: onChannelDown, tooltip: 'Önceki kanal',
                  iconSize: 36, icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white)),
                const SizedBox(width: 16),
                IconButton(onPressed: onSubtitles, tooltip: 'Altyazılar',
                  iconSize: 30, icon: const Icon(Icons.subtitles, color: Colors.white)),
                const SizedBox(width: 16),
                IconButton(onPressed: onChannelUp, tooltip: 'Sonraki kanal',
                  iconSize: 36, icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== TVMate Kanal Listesi Paneli ====================

class _ChannelListPanel extends StatefulWidget {
  const _ChannelListPanel({
    required this.channels,
    required this.panelChannels,
    required this.selectedIndex,
    required this.currentIndex,
    required this.filterGroup,
    required this.groups,
    required this.onSelectIndex,
    required this.onClose,
    required this.onRightArrow,
  });

  final List<Channel> channels;
  final List<Channel> panelChannels;
  final int selectedIndex;
  final int currentIndex;
  final String filterGroup;
  final List<String> groups;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onClose;
  final VoidCallback onRightArrow;

  @override
  State<_ChannelListPanel> createState() => _ChannelListPanelState();
}

class _ChannelListPanelState extends State<_ChannelListPanel> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void didUpdateWidget(covariant _ChannelListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.filterGroup != widget.filterGroup) {
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
    const itemExtent = 48.0;
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
    final channels = widget.panelChannels;
    final selectedIndex = widget.selectedIndex;
    final currentIndex = widget.currentIndex;
    final width = (MediaQuery.of(context).size.width * 0.28).clamp(260.0, 420.0).toDouble();

    final groupIdx = widget.groups.indexOf(widget.filterGroup);
    final groupCount = widget.groups.length;
    final groupLabel = widget.filterGroup == 'all' ? 'TÜMÜ' : widget.filterGroup;

    return Positioned(
      right: 0, top: 0, bottom: 0, width: width,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder, color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(groupLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.amber, fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                        if (groupCount > 1)
                          Text('${groupIdx + 1}/$groupCount',
                            style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        const SizedBox(width: 4),
                        IconButton(onPressed: widget.onClose, tooltip: 'Kapat',
                          icon: const Icon(Icons.close, color: Colors.white54, size: 18)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Icon(Icons.arrow_right, color: Colors.white38, size: 14),
                        Text('Kategori', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_drop_down, color: Colors.white38, size: 14),
                        Text('Kanal', style: TextStyle(color: Colors.white38, fontSize: 10)),
                        SizedBox(width: 8),
                        Icon(Icons.check_circle, color: Colors.white38, size: 14),
                        Text('Seç', style: TextStyle(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: channels.length,
                itemExtent: 48,
                itemBuilder: (context, i) {
                  final c = channels[i];
                  final selected = i == selectedIndex;
                  final isCurrent = widget.channels.indexOf(c) == currentIndex;
                  return InkWell(
                    onTap: () => widget.onSelectIndex(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      color: selected
                          ? Colors.lightBlue.withValues(alpha: 0.35)
                          : isCurrent
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Row(
                        children: [
                          _ListLogo(channel: c),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? Colors.amber : Colors.white,
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.bold : FontWeight.w400,
                                  )),
                                Text(c.displayGroup, maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                          ),
                          if (isCurrent)
                            Container(width: 6, height: 6,
                              decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.black.withValues(alpha: 0.4),
                child: Row(
                  children: const [
                    Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 14),
                    Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 14),
                    SizedBox(width: 4),
                    Expanded(child: Text('Gezin', style: TextStyle(color: Colors.white54, fontSize: 10))),
                    Icon(Icons.arrow_right, color: Colors.white54, size: 14),
                    SizedBox(width: 2),
                    Text('Kategori', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle, color: Colors.white54, size: 14),
                    SizedBox(width: 2),
                    Text('Aç', style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListLogo extends StatelessWidget {
  const _ListLogo({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final logo = channel.logo;
    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(logo, width: 34, height: 34, fit: BoxFit.cover,
          cacheWidth: 68,
          errorBuilder: (_, _, _) => _fallback(),
          loadingBuilder: (_, child, progress) => progress == null ? child : _fallback()),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?';
    return Container(
      width: 34, height: 34, alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
      child: Text(initial, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white70)),
    );
  }
}

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
  const _SubtitlesSheet({required this.tracks, required this.activeId});
  final List<SubtitleInfo> tracks;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasStreamTracks = tracks.isNotEmpty;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Altyazılar', style: theme.textTheme.titleLarge),
          ),
          ListTile(
            leading: const Icon(Icons.subtitles_off),
            title: const Text('Kapalı'),
            trailing: activeId == null || activeId == 'off'
                ? const Icon(Icons.check, color: Colors.green) : null,
            onTap: () => Navigator.of(context).pop('off'),
          ),
          if (hasStreamTracks) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Akış altyazıları', style: theme.textTheme.labelLarge),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true, itemCount: tracks.length,
                itemBuilder: (context, i) {
                  final t = tracks[i];
                  final label = [t.title, t.language].whereType<String>().where((s) => s.isNotEmpty).join(' • ');
                  return ListTile(
                    leading: const Icon(Icons.subtitles),
                    title: Text(label.isEmpty ? 'Parça ${i + 1}' : label),
                    trailing: activeId == t.id ? const Icon(Icons.check, color: Colors.green) : null,
                    onTap: () => Navigator.of(context).pop(t.id),
                  );
                },
              ),
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Dosyadan altyazı yükle'),
            subtitle: const Text('SRT, VTT, ASS, SSA, SUB'),
            onTap: () => Navigator.of(context).pop('file'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
