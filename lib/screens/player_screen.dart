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
  double _bufferSecs = 0.5;

  List<SubtitleInfo> _subtitleTracks = [];
  String? _activeSubtitleId;
  String? _subtitleText;
  DateTime _lastPositionAt = DateTime.fromMillisecondsSinceEpoch(0);

  // Panel modu: false = sol kanal listesi, true = sağ EPG
  bool _showEpgPanel = false;

  // Panel filtresi
  String _panelFilterGroup = 'all';
  List<String> _panelGroups = [];



  Channel get _channel => widget.channels[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
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

  void _updatePanelChannels() {}

  void _panelRightArrow() {
    if (_panelGroups.length <= 2) return;
    final currentIdx = _panelGroups.indexOf(_panelFilterGroup);
    if (currentIdx < 0 || currentIdx >= _panelGroups.length - 1) {
      _panelFilterGroup = _panelGroups.first;
    } else {
      _panelFilterGroup = _panelGroups[currentIdx + 1];
    }
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
        _panelFilterGroup = _channel.displayGroup;
        if (!_panelGroups.contains(_panelFilterGroup)) {
          _panelFilterGroup = 'all';
        }
        _updatePanelChannels();
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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_showPanel) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _switchChannel(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _switchChannel(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        // Sağ tuş: EPG panelini aç/kapat veya kategori değiştir
        if (!_showEpgPanel) {
          setState(() => _showEpgPanel = true);
        } else {
          _panelRightArrow();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (_showEpgPanel) {
          setState(() => _showEpgPanel = false);
        } else {
          _closePanel();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
        // Paneldeyken OK: kanalı seç ve paneli kapat
        _closePanel();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
        _closePanel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Ana mod
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
      _togglePanel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space) {
      _toggleOverlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (_showPanel) {
        _closePanel();
        return KeyEventResult.handled;
      }
      Navigator.of(context).pop();
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
              // Ana içerik: her zaman tam ekran video
              _player.buildVideo(fit: BoxFit.contain),

              // Sol overlay: kanal listesi
              if (_showPanel)
                Positioned(
                  left: 0, top: 0, bottom: 0, width: 280,
                  child: _TiviMateChannelList(
                    channels: widget.channels,
                    selectedIndex: _index,
                    filterGroup: _panelFilterGroup,
                    groups: _panelGroups,
                    onSelect: _selectChannel,
                    filterGroupChanged: (g) {
                      setState(() {
                        _panelFilterGroup = g;
                        _updatePanelChannels();
                      });
                    },
                    onClose: _closePanel,
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



              // Üst/alt kontrol paneli
              if (_overlayVisible && _error == null && !_showPanel)
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

              if (_overlayVisible && _error == null && !_showPanel)
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

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
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
      color: const Color(0xFF1A1A2E),
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

          // Kategori seçici
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: widget.groups.length,
              itemBuilder: (context, i) {
                final g = widget.groups[i];
                final selected = widget.filterGroup == g;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(
                      i == 0 ? 'Tümü' : g,
                      style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.white70),
                    ),
                    selected: selected,
                    onSelected: (_) => widget.filterGroupChanged(g),
                    selectedColor: Colors.blue.withValues(alpha: 0.5),
                    backgroundColor: Colors.white10,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          // Kanal listesi
          Expanded(
            child: ListView.builder(
              controller: _scroll,
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
                              Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                ),
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
