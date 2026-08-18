import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/screens/movie_detail_screen.dart';
import 'package:iptv_player/screens/series_detail_screen.dart';
import 'package:iptv_player/screens/vod_player_screen.dart';
import 'package:iptv_player/services/resume_service.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:iptv_player/widgets/channel_list.dart';
import 'package:provider/provider.dart';

/// VOD ana ekranı — Film ve Dizi bağımsız sekmeler.
///
/// Her sekme kendi Netflix tarzı listesine sahip: hero kart +
/// yatay kategori satırları. Kumanda ile sekmeler arası geçiş
/// TabController ile sağlanır.
class VodScreen extends StatefulWidget {
  const VodScreen({super.key, this.onGoToSetup});

  final VoidCallback? onGoToSetup;

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.hasVod) {
      return Scaffold(
        appBar: AppBar(title: const Text('VOD')),
        body: EmptyState(
          icon: Icons.movie_filter_outlined,
          title: 'VOD için Xtream bağlantısı gerekir',
          subtitle:
              'Kurulum sekmesinden Xtream Codes girişi yap, Xtream tabanlı bir '
              "playlist URL'si (get.php) ekle veya M3U kanalları live/kullanıcı/şifre "
              'adresleri içeriyorsa VOD otomatik açılır.',
          actionLabel: 'Kuruluma git',
          onAction: widget.onGoToSetup,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOD'),
        actions: [
          if (state.vodLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            tooltip: 'Kataloğu yenile',
            icon: const Icon(Icons.refresh),
            onPressed: state.loadVod,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.movie, size: 18), text: 'Filmler'),
            Tab(icon: Icon(Icons.tv, size: 18), text: 'Diziler'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ---- Film sekmesi ----
          _VodTab(
            isMovies: true,
            state: state,
            onItemTap: (m) => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => MovieDetailScreen(movie: m)),
            ),
          ),
          // ---- Dizi sekmesi ----
          _VodTab(
            isMovies: false,
            state: state,
            onItemTap: (s) => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => SeriesDetailScreen(series: s)),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Tek sekme (Film veya Dizi) ====================

class _VodTab extends StatefulWidget {
  const _VodTab({
    required this.isMovies,
    required this.state,
    required this.onItemTap,
  });

  final bool isMovies;
  final AppState state;
  final void Function(dynamic) onItemTap;

  @override
  State<_VodTab> createState() => _VodTabState();
}

class _VodTabState extends State<_VodTab>
    with AutomaticKeepAliveClientMixin {
  List<ResumeRecord> _resumeRecords = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  Future<void> _loadResume() async {
    final records = await ResumeService.load();
    if (!mounted) return;
    setState(() => _resumeRecords = records);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final state = widget.state;
    final isMovies = widget.isMovies;

    final all = <_RowItem>[
      if (isMovies)
        for (final m in state.filteredVodMovies) ...[
          () {
            final d = state.movieDetailsCached(m.id);
            return _RowItem(m.id, m.name, m.poster, m.rating, m.categoryId,
                d?.plot, d?.genre);
          }(),
        ]
      else
        for (final s in state.filteredVodSeries) ...[
          () {
            final d = state.seriesInfoCached(s.id);
            return _RowItem(s.id, s.name, s.cover, s.rating, s.categoryId,
                d?.plot ?? s.plot, d?.genre);
          }(),
        ],
    ];

    // Devam ettirme kayıtları (film/dizi ayrımı)
    final relevantResume = _resumeRecords
        .where((r) => r.isMovie == isMovies && !r.isCompleted)
        .toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));

    if (all.isEmpty && !state.vodLoading && relevantResume.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Sonuç bulunamadı',
        subtitle: 'İçerik yükleniyor veya kategori boş.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await state.loadVod();
        await _loadResume();
      },
      child: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              // Kaldığın Yerden Devam (varsa)
              if (relevantResume.isNotEmpty) ...[
                _ResumeSection(
                  records: relevantResume,
                  isMovie: isMovies,
                  state: state,
                ),
                const SizedBox(height: 16),
              ],
              if (all.isNotEmpty) ...[
                _HeroCard(
                  item: all.first,
                  isMovie: isMovies,
                  onTap: () => _openItem(all.first),
                ),
                const SizedBox(height: 20),
                _RowSection(
                  title: isMovies ? 'Tüm Filmler' : 'Tüm Diziler',
                  items: all,
                  isMovie: isMovies,
                  onTap: _openItem,
                ),
                ..._buildCategoryRows(all),
              ],
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryRows(List<_RowItem> all) {
    final state = widget.state;
    final isMovies = widget.isMovies;

    // Kategorilere göre grupla (ilk eleman hariç — hero olarak kullanıldı)
    final byCategory = <String?, List<_RowItem>>{};
    for (final item in all.skip(1)) {
      byCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }

    final rows = <Widget>[];
    for (final (id, name) in state.vodCategories) {
      if (id == 'all') continue;
      final items = byCategory[id];
      if (items == null || items.isEmpty) continue;
      rows.add(const SizedBox(height: 20));
      rows.add(_RowSection(
        title: name,
        items: items,
        isMovie: isMovies,
        onTap: _openItem,
      ));
    }
    return rows;
  }

  void _openItem(_RowItem item) {
    final state = widget.state;
    if (widget.isMovies) {
      final m = state.filteredVodMovies.where((m) => m.id == item.id).firstOrNull;
      if (m != null) widget.onItemTap(m);
    } else {
      final s = state.filteredVodSeries.where((s) => s.id == item.id).firstOrNull;
      if (s != null) widget.onItemTap(s);
    }
  }
}

// ==================== Kaldığın Yerden Devam Bölümü ====================

class _ResumeSection extends StatelessWidget {
  const _ResumeSection({
    required this.records,
    required this.isMovie,
    required this.state,
  });

  final List<ResumeRecord> records;
  final bool isMovie;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.history, size: 20, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                isMovie ? 'Filmlerde Devam Et' : 'Dizilerde Devam Et',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final r = records[i];
              return _ResumeCard(record: r, state: state);
            },
          ),
        ),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.record, required this.state});
  final ResumeRecord record;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // VOD oynatıcıyı aç, kaldığın yerden devam et
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VodPlayerScreen(
              url: record.url,
              title: record.title,
              mediaId: record.id,
              poster: record.poster,
              isMovie: record.isMovie,
              resumePosition: record.position,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (record.poster != null && record.poster!.isNotEmpty)
                      Image.network(
                        record.poster!,
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                        errorBuilder: (_, _, _) => _placeholder(),
                        loadingBuilder: (_, child, p) => p == null ? child : _placeholder(),
                      )
                    else
                      _placeholder(),
                    // İlerleme çubuğu
                    Positioned(
                      left: 0, right: 0, bottom: 0,
                      child: Container(
                        height: 4,
                        color: Colors.black.withValues(alpha: 0.5),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: record.progress,
                          child: Container(color: Colors.amber),
                        ),
                      ),
                    ),
                    // Oynat ikonu
                    const Center(
                      child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              record.title,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              record.remainingText,
              maxLines: 1,
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.white12,
      child: const Center(child: Icon(Icons.movie, color: Colors.white38, size: 32)),
    );
  }
}

// ==================== Yardımcı Sınıflar ====================

class _RowItem {
  const _RowItem(this.id, this.name, this.poster, this.rating, this.categoryId, [this.plot, this.genre]);

  final int id;
  final String name;
  final String? poster;
  final String? rating;
  final String? categoryId;
  final String? plot;   // Konu/açıklama
  final String? genre;  // Tür
}

// ==================== Hero Card ====================

class _HeroCard extends StatefulWidget {
  const _HeroCard(
      {required this.item, required this.isMovie, required this.onTap});

  final _RowItem item;
  final bool isMovie;
  final VoidCallback onTap;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  final _focus = FocusNode(debugLabel: 'vod-hero');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final focused = _focus.hasFocus;
    final height = MediaQuery.of(context).size.height * 0.38;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: focused ? height + 8 : height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _HeroImage(url: item.poster, name: item.name),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),
                  if (focused)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.rating != null &&
                                item.rating!.isNotEmpty) ...[
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                item.rating!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            _Pill(
                                label: widget.isMovie ? 'Film' : 'Dizi'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _HeroButton(
                              icon: Icons.play_arrow,
                              label: 'İzle',
                              filled: true,
                              onTap: widget.onTap,
                            ),
                            const SizedBox(width: 10),
                            _HeroButton(
                              icon: Icons.info_outline,
                              label: 'Detay',
                              filled: false,
                              onTap: widget.onTap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white12,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: filled ? Colors.black : Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: filled ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (url == null || url!.isEmpty) {
      return ColoredBox(color: colors.surfaceContainerHighest);
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      cacheWidth: 720,
      errorBuilder: (_, _, _) =>
          ColoredBox(color: colors.surfaceContainerHighest),
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : ColoredBox(color: colors.surfaceContainerHighest),
    );
  }
}

// ==================== Row Section ====================

class _RowSection extends StatelessWidget {
  const _RowSection({
    required this.title,
    required this.items,
    required this.isMovie,
    required this.onTap,
  });

  final String title;
  final List<_RowItem> items;
  final bool isMovie;
  final void Function(_RowItem) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final item = items[i];
              return _RowCard(
                item: item,
                isMovie: isMovie,
                onTap: () => onTap(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RowCard extends StatefulWidget {
  const _RowCard({
    required this.item,
    required this.isMovie,
    required this.onTap,
  });

  final _RowItem item;
  final bool isMovie;
  final VoidCallback onTap;

  @override
  State<_RowCard> createState() => _RowCardState();
}

class _RowCardState extends State<_RowCard> {
  final _focus = FocusNode(debugLabel: 'vod-row-card');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final item = widget.item;
    final focused = _focus.hasFocus;
    const w = 110.0;

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: SizedBox(
        width: w,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Ana kart
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: widget.onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: focused ? colors.primary : Colors.transparent,
                      width: focused ? 3 : 0,
                    ),
                    boxShadow: focused
                        ? [BoxShadow(color: colors.primary.withValues(alpha: 0.4), blurRadius: 12)]
                        : null,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _poster(colors),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center, end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6, right: 6, bottom: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.w600, height: 1.2)),
                            if (item.rating != null && item.rating!.isNotEmpty)
                              Row(children: [
                                const Icon(Icons.star, color: Colors.amber, size: 11),
                                const SizedBox(width: 2),
                                Text(item.rating!,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10)),
                              ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // TiviMate tarzı künye bilgi kartı (odaklanınca üstte çıkar)
            if (focused)
              Positioned(
                bottom: w * 1.35,
                left: 0, right: 0,
                child: _InfoCard(item: item, isMovie: widget.isMovie),
              ),
          ],
        ),
      ),
    );
  }

  Widget _poster(ColorScheme colors) {
    final url = widget.item.poster;
    if (url == null || url.isEmpty) {
      return ColoredBox(color: colors.surfaceContainerHighest);
    }
    return Image.network(url, fit: BoxFit.cover, cacheWidth: 220,
      errorBuilder: (_, _, _) => ColoredBox(color: colors.surfaceContainerHighest),
      loadingBuilder: (_, child, progress) => progress == null
          ? child : ColoredBox(color: colors.surfaceContainerHighest));
  }
}

// ==================== Netflix Tarzı Bilgi Paneli ====================

/// Odaklanınca kartın üstünde görünen geniş bilgi paneli.
/// Büyük poster + film/dizi bilgileri: puan, tür, konu.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.item, required this.isMovie});
  final _RowItem item;
  final bool isMovie;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(12),
      elevation: 12,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Büyük poster
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 100, height: 140,
                child: item.poster != null && item.poster!.isNotEmpty
                    ? Image.network(
                        item.poster!,
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                        errorBuilder: (_, _, _) => _posterFallback(),
                        loadingBuilder: (_, child, p) => p == null ? child : _posterFallback(),
                      )
                    : _posterFallback(),
              ),
            ),
            const SizedBox(width: 12),
            // Bilgi paneli
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Film/Dizi rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isMovie ? Colors.blue.withValues(alpha: 0.3) : Colors.purple.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isMovie ? 'FILM' : 'DIZI',
                      style: TextStyle(
                        color: isMovie ? Colors.blue[200] : Colors.purple[200],
                        fontSize: 10, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Başlık
                  Text(
                    item.name,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Puan + tür
                  Row(
                    children: [
                      if (item.rating != null && item.rating!.isNotEmpty) ...[
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          item.rating!,
                          style: const TextStyle(
                            color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (item.genre != null && item.genre!.isNotEmpty)
                        Expanded(
                          child: Text(
                            item.genre!,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  // Konu (varsa)
                  if (item.plot != null && item.plot!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.plot!,
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70, fontSize: 11, height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // İpucu
                  Row(
                    children: const [
                      Icon(Icons.play_circle_outline, color: Colors.white38, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'OK ile izle',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: Colors.white12,
      child: Center(
        child: Icon(
          isMovie ? Icons.movie : Icons.tv,
          color: Colors.white38, size: 32,
        ),
      ),
    );
  }
}
