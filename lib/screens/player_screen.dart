import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/services/mpv_tuning.dart';
import 'package:iptv_player/services/settings_service.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Tam ekran IPTV oynatıcısı.
///
/// Uzaktan kumanda (D-pad) / klavye:
/// - ↑↓          : kanal değiştirir (liste kapalıyken)
/// - ←→          : ses seviyesi
/// - OK (Enter)  : sol tarafta kanal listesini açar/kapatır (logo + isim)
/// - Boşluk / ekrana dokunma: üst/alt kontrol panelini (ses dahil) gösterir/gizler
/// - Geri tuşu   : oynatıcıdan çıkar
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.channels,
    required this.initialIndex,
  });

  /// Kanal değiştirme ve liste için tüm kanal listesi.
  final List<Channel> channels;
  final int initialIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late int _index;
  int _listIndex = 0;
  bool _showList = false;

  bool _buffering = true;
  String? _error;
  bool _overlayVisible = true;
  Timer? _overlayTimer;
  Timer? _retryTimer;
  int _errorRetries = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  double _volume = 1.0;
  double _lastNonZeroVolume = 1.0;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;
  double _bufferSecs = 0.5;

  List<SubtitleTrack> _subtitleTracks = [];
  String? _activeSubtitleId;
  DateTime _lastPositionAt = DateTime.fromMillisecondsSinceEpoch(0);

  Channel get _channel => widget.channels[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _listIndex = _index;
    _player = Player();
    _controller = VideoController(_player);
    MpvTuning.apply(_player, bufferSecs: _bufferSecs);
    _subscribe();
    WakelockPlus.enable();
    _loadSettings();
    _open(_channel);
  }

  /// Kayıtlı bağlantı hızını ve ses seviyesini uygular.
  Future<void> _loadSettings() async {
    final speed = await SettingsService.loadSpeed();
    final volume = await SettingsService.loadVolume();
    if (!mounted) return;
    _bufferSecs = speed.bufferSecs;
    MpvTuning.apply(_player, bufferSecs: _bufferSecs);
    await _player.setVolume(volume);
  }

  @override
  void dispose() {
    _overlayTimer?.cancel();
    _volumeHudTimer?.cancel();
    _retryTimer?.cancel();
    WakelockPlus.disable();
    _player.dispose();
    super.dispose();
  }

  void _subscribe() {
    _player.stream.buffering.listen((b) {
      if (mounted) setState(() => _buffering = b);
    });
    // Geçici ağ hatalarında oynatıcıyı 2 kez otomatik yeniden bağla
    // (TiviMate tarzı kendi kendini kurtarma); 2 deneme de başarısızsa hata göster.
    _player.stream.error.listen((e) {
      if (!mounted) return;
      if (_errorRetries < 2) {
        _errorRetries++;
        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            _open(_channel);
          }
        });
      } else {
        setState(() => _error = e);
      }
    });
    _player.stream.volume.listen((v) {
      if (!mounted) return;
      setState(() {
        _volume = v;
        if (v > 0) _lastNonZeroVolume = v;
      });
    });
    // Konum güncellemeleri: canlı yayında (süre 0) hiç güncelleme yapma;
    // VOD benzeri akışta ise yalnızca arayüz görünürken saniyede en fazla 2 kez.
    // (Her karede setState yapmak tüm oynatıcıyı yeniden çizer → takılma/donma.)
    _player.stream.position.listen((p) {
      if (!mounted) return;
      if (_duration == Duration.zero) return;
      if (!_overlayVisible) return;
      final now = DateTime.now();
      if (now.difference(_lastPositionAt) < const Duration(milliseconds: 500)) return;
      _lastPositionAt = now;
      setState(() => _position = p);
    });
    _player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    // Akış içi video/audio/altyazı parçaları.
    _player.stream.tracks.listen((tracks) {
      if (!mounted) return;
      setState(() => _subtitleTracks = List.of(tracks.subtitle));
      // Akış parçası yoksa ve kanalda harici altyazı tanımlıysa onu yükle.
      if (tracks.subtitle.isEmpty && _channel.subtitleUrl != null) {
        final url = _channel.subtitleUrl!;
        try {
          _player.setSubtitleTrack(SubtitleTrack.uri(url, title: 'Harici altyazı'));
          _activeSubtitleId = url;
        } catch (_) {
          // Altyazı yüklenemezse oynatmaya devam et.
        }
      }
    });
  }

  void _open(Channel channel) {
    _retryTimer?.cancel();
    setState(() {
      _buffering = true;
      _error = null;
      _position = Duration.zero;
      _duration = Duration.zero;
    });
    try {
      _player.open(Media(channel.url));
    } catch (e) {
      if (mounted) setState(() => _error = 'Akış açılamadı: $e');
    }
    _scheduleOverlayHide();
  }

  /// Kullanıcının bilinçli bir kanal seçiminde retry sayacını sıfırlar.
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

  // ---- Ses ----

  Future<void> _changeVolume(double delta) async {
    final next = (_volume + delta).clamp(0.0, 1.0);
    await _player.setVolume(next);
    SettingsService.saveVolume(next);
    _flashVolumeHud();
  }

  Future<void> _setVolume(double v) async {
    final next = v.clamp(0.0, 1.0);
    await _player.setVolume(next);
    SettingsService.saveVolume(next);
  }

  Future<void> _toggleMute() async {
    if (_volume == 0) {
      await _player.setVolume(_lastNonZeroVolume);
    } else {
      _lastNonZeroVolume = _volume;
      await _player.setVolume(0);
    }
  }

  /// Ses değiştiğinde, kontrol paneli kapalıyken bile kısa süreliğine
  /// altta ses çubuğu gösterir.
  void _flashVolumeHud() {
    _volumeHudTimer?.cancel();
    setState(() => _showVolumeHud = true);
    _volumeHudTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showVolumeHud = false);
    });
  }

  // ---- Kanal listesi paneli (OK) ----

  void _toggleChannelList() {
    setState(() {
      _showList = !_showList;
      if (_showList) {
        _listIndex = _index;
        _overlayVisible = true;
        _overlayTimer?.cancel();
      } else {
        _scheduleOverlayHide();
      }
    });
  }

  void _closeList() {
    if (!_showList) return;
    setState(() => _showList = false);
    _scheduleOverlayHide();
  }

  void _moveList(int delta) {
    final next = _listIndex + delta;
    if (next < 0 || next >= widget.channels.length) return;
    setState(() => _listIndex = next);
  }

  void _selectListChannel() {
    final next = _listIndex;
    _closeList();
    if (next == _index) return;
    setState(() => _index = next);
    _openUser(_channel);
  }

  /// Dokunmatik seçim: paneldeki satıra dokununca o kanal açılır.
  void _selectListChannelAt(int i) {
    if (i < 0 || i >= widget.channels.length) return;
    _listIndex = i;
    _selectListChannel();
  }

  // ---- Kanal değiştirme (↑↓) ----

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
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Kanal listesi açıkken ↑↓ listede gezinir, OK seçimi oynatır.
    if (_showList) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveList(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveList(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select) {
        _selectListChannel();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.escape) {
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
    setState(() => _activeSubtitleId = selected);
    if (selected == 'off') {
      await _player.setSubtitleTrack(SubtitleTrack.no());
    } else if (selected == 'file') {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['srt', 'vtt', 'ass', 'ssa', 'sub'],
      );
      if (result.isEmpty || !mounted) return;
      final path = result.first.path;
      if (path == null) return;
      await _player.setSubtitleTrack(SubtitleTrack.uri('file://$path', title: 'Dosya altyazısı'));
      setState(() => _activeSubtitleId = 'file://$path');
    } else {
      // Akış içi parça seçimi.
      for (final t in _subtitleTracks) {
        if (t.id == selected) {
          await _player.setSubtitleTrack(SubtitleTrack(t.id, t.title, t.language));
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final nowProgram = state.nowPlaying(_channel);
    final nextProgram = state.nextProgram(_channel);

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
              Video(
                controller: _controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
              if (_buffering && _error == null)
                const _BufferingIndicator()
              else if (_error != null)
                _ErrorOverlay(
                  message: _error!,
                  onRetry: () => _openUser(_channel),
                  onBack: () => Navigator.of(context).pop(),
                ),
              if (_overlayVisible && _error == null)
                _ControlsOverlay(
                  channel: _channel,
                  index: _index,
                  total: widget.channels.length,
                  position: _position,
                  duration: _duration,
                  isLive: _duration == Duration.zero && _position == Duration.zero,
                  nowProgram: nowProgram?.title,
                  nextProgram: nextProgram?.title,
                  nextStart: nextProgram?.start,
                  volume: _volume,
                  onVolumeChanged: _setVolume,
                  onToggleMute: _toggleMute,
                  onBack: () => Navigator.of(context).pop(),
                  onChannelUp: () => _switchChannel(1),
                  onChannelDown: () => _switchChannel(-1),
                  onSubtitles: _showSubtitlesMenu,
                ),
              // Üstteki gradyan, kontrollerin okunabilirliği için.
              if (_overlayVisible && _error == null)
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              // OK tuşuyla açılan sol kanal listesi (ekranın ~%25'i).
              if (_showList && _error == null)
                _ChannelListPanel(
                  channels: widget.channels,
                  selectedIndex: _listIndex,
                  currentIndex: _index,
                  onSelectIndex: _selectListChannelAt,
                  onClose: _closeList,
                ),
              // Ses HUD'u — panel kapalıyken bile ses değişince görünür.
              if (_showVolumeHud)
                _VolumeHud(volume: _volume),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kanal açılırken üstte görünen küçük yükleme göstergesi.
/// Önceki kanalın görüntüsü ekranda kalır → geçiş hızlı hissettirir.
class _BufferingIndicator extends StatelessWidget {
  const _BufferingIndicator();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
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
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
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

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

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
              const Text(
                'Akış açılamadı',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tekrar Dene'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Geri'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({
    required this.channel,
    required this.index,
    required this.total,
    required this.position,
    required this.duration,
    required this.isLive,
    required this.nowProgram,
    required this.nextProgram,
    required this.nextStart,
    required this.volume,
    required this.onVolumeChanged,
    required this.onToggleMute,
    required this.onBack,
    required this.onChannelUp,
    required this.onChannelDown,
    required this.onSubtitles,
  });

  final Channel channel;
  final int index;
  final int total;
  final Duration position;
  final Duration duration;
  final bool isLive;
  final String? nowProgram;
  final String? nextProgram;
  final DateTime? nextStart;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback onToggleMute;
  final VoidCallback onBack;
  final VoidCallback onChannelUp;
  final VoidCallback onChannelDown;
  final VoidCallback onSubtitles;

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
    final muted = volume == 0;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: onBack,
                  tooltip: 'Geri',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${channel.displayGroup} • ${index + 1}/$total',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      if (nowProgram != null && nowProgram!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.play_arrow, size: 14, color: Colors.lightBlueAccent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Şimdi: $nowProgram',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (nextProgram != null && nextProgram!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Sonra: $nextProgram (${nextStart != null ? _time(nextStart!) : ''})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isLive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CANLI',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  Text(
                    '${_fmt(position)} / ${_fmt(duration)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
              ],
            ),
          ),
          const Spacer(),
          // Ses kontrol paneli — ekrana dokununca belirir, tam ekranda gizlenir.
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: onToggleMute,
                  tooltip: muted ? 'Sesi aç' : 'Sessize al',
                  icon: Icon(
                    muted
                        ? Icons.volume_off
                        : volume < 0.5
                            ? Icons.volume_down
                            : Icons.volume_up,
                    color: Colors.white,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: volume,
                    onChanged: onVolumeChanged,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                  ),
                ),
                Text(
                  '${(volume * 100).round()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onChannelDown,
                  tooltip: 'Önceki kanal',
                  iconSize: 36,
                  icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: onSubtitles,
                  tooltip: 'Altyazılar',
                  iconSize: 30,
                  icon: const Icon(Icons.subtitles, color: Colors.white),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: onChannelUp,
                  tooltip: 'Sonraki kanal',
                  iconSize: 36,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// OK tuşuyla açılan, ekranın sol ~%25'ini kaplayan kanal listesi.
/// Her satırda kanal logosu ve adı; seçili kanal vurgulanır.
class _ChannelListPanel extends StatefulWidget {
  const _ChannelListPanel({
    required this.channels,
    required this.selectedIndex,
    required this.currentIndex,
    required this.onSelectIndex,
    required this.onClose,
  });

  final List<Channel> channels;
  final int selectedIndex;
  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final VoidCallback onClose;

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
    final channels = widget.channels;
    final selectedIndex = widget.selectedIndex;
    final currentIndex = widget.currentIndex;
    // Ekran genişliğinin %25'i, en az 240 en çok 400 px.
    final width = (MediaQuery.of(context).size.width * 0.25)
        .clamp(240.0, 400.0)
        .toDouble();

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      width: width,
      child: Material(
        color: Colors.black.withValues(alpha: 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.list, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kanallar (${channels.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      tooltip: 'Kapat',
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
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
                itemBuilder: (context, i) {
                  final c = channels[i];
                  final selected = i == selectedIndex;
                  final isCurrent = i == currentIndex;
                  return InkWell(
                    onTap: () => widget.onSelectIndex(i),
                    child: Container(
                      color: selected
                          ? Colors.lightBlue.withValues(alpha: 0.35)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          _ListLogo(channel: c),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? Colors.amber : Colors.white,
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.bold : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            const Icon(Icons.play_arrow, color: Colors.amber, size: 18),
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
                padding: const EdgeInsets.all(10),
                color: Colors.black.withValues(alpha: 0.5),
                child: const Row(
                  children: [
                    Icon(Icons.keyboard_arrow_up, color: Colors.white54, size: 16),
                    Icon(Icons.keyboard_arrow_down, color: Colors.white54, size: 16),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Gezin • OK: Aç • ←: Kapat',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ),
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

/// Paneldeki kanal logosu (yoksa baş harf).
class _ListLogo extends StatelessWidget {
  const _ListLogo({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final logo = channel.logo;
    if (logo != null && logo.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          logo,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final initial = channel.name.isNotEmpty ? channel.name[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        initial,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
      ),
    );
  }
}

/// Ses değişince altta beliren kısa ses çubuğu (HUD).
class _VolumeHud extends StatelessWidget {
  const _VolumeHud({required this.volume});

  final double volume;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: IgnorePointer(
        child: Center(
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  volume == 0
                      ? Icons.volume_off
                      : volume < 0.5
                          ? Icons.volume_down
                          : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: volume,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(volume * 100).round()}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Altyazı seçim sayfası.
class _SubtitlesSheet extends StatelessWidget {
  const _SubtitlesSheet({required this.tracks, required this.activeId});

  final List<SubtitleTrack> tracks;
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
                ? const Icon(Icons.check, color: Colors.green)
                : null,
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
                shrinkWrap: true,
                itemCount: tracks.length,
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
