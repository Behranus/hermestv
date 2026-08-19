import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/screens/movie_detail_screen.dart';
import 'package:iptv_player/screens/series_detail_screen.dart';
import 'package:iptv_player/screens/vod_player_screen.dart';
import 'package:iptv_player/services/resume_service.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:iptv_player/widgets/channel_list.dart';
import 'package:provider/provider.dart';

/// VOD ana ekranı — Netflix/Prime Video tarzı:
/// - Üstte büyük hero banner
/// - Gezinme ikonları
/// - Büyük poster ızgarası
/// - Odaklanınca film bilgisi paneli
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
      backgroundColor: const Color(0xFF0D0D1A),
      body: Column(
        children: [
          // Üst bar: Film/Dizi sekmeleri + yenile
          _NetflixTopBar(
            tabController: _tabController,
            onRefresh: state.loadVod,
            isLoading: state.vodLoading,
          ),

          // Sekme içeriği
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _NetflixTab(
                  isMovies: true,
                  state: state,
                  onItemTap: (item) {
                    final movie = state.filteredVodMovies.where((m) => m.id == item.id).firstOrNull;
                    if (movie != null) Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
                    );
                  },
                ),
                _NetflixTab(
                  isMovies: false,
                  state: state,
                  onItemTap: (item) {
                    final series = state.filteredVodSeries.where((s) => s.id == item.id).firstOrNull;
                    if (series != null) Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Netflix Üst Bar ====================

class _NetflixTopBar extends StatelessWidget {
  const _NetflixTopBar({
    required this.tabController,
    required this.onRefresh,
    required this.isLoading,
  });

  final TabController tabController;
  final VoidCallback onRefresh;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D1A),
      child: Column(
          children: [
            // Üst satır: Logo + yenile
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
              child: Row(
                children: [
                  // Logo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'BBTV',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isLoading)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                    ),
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh, color: Colors.white54, size: 22),
                  ),
                ],
              ),
            ),

            // Film/Dizi sekmeleri
            TabBar(
              controller: tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.red,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
              tabs: const [
                Tab(text: 'Filmler'),
                Tab(text: 'Diziler'),
              ],
            ),
          ],
      ),
    );
  }
}

// ==================== Netflix Sekme İçeriği ====================

class _NetflixTab extends StatefulWidget {
  const _NetflixTab({
    required this.isMovies,
    required this.state,
    required this.onItemTap,
  });

  final bool isMovies;
  final AppState state;
  final void Function(dynamic) onItemTap;

  @override
  State<_NetflixTab> createState() => _NetflixTabState();
}

class _NetflixTabState extends State<_NetflixTab>
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

    // Tüm içerikleri topla
    final all = <_VodItem>[];
    if (isMovies) {
      for (final m in state.filteredVodMovies) {
        final d = state.movieDetailsCached(m.id);
        all.add(_VodItem(
          id: m.id, name: m.name, poster: m.poster,
          rating: m.rating, categoryId: m.categoryId,
          plot: d?.plot, genre: d?.genre, isMovie: true,
        ));
      }
    } else {
      for (final s in state.filteredVodSeries) {
        final d = state.seriesInfoCached(s.id);
        all.add(_VodItem(
          id: s.id, name: s.name, poster: s.cover,
          rating: s.rating, categoryId: s.categoryId,
          plot: d?.plot ?? s.plot, genre: d?.genre, isMovie: false,
        ));
      }
    }

    // Devam ettirme kayıtları
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

    // Kategorilere göre grupla
    final byCategory = <String?, List<_VodItem>>{};
    for (final item in all) {
      byCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await state.loadVod();
        await _loadResume();
      },
      child: CustomScrollView(
        slivers: [
          // Hero Banner
          if (all.isNotEmpty)
            SliverToBoxAdapter(
              child: _NetflixHeroBanner(item: all.first, onTap: () => widget.onItemTap(all.first)),
            ),

          // İnce ayırıcı çizgi
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.white24, height: 1),
            ),
          ),

          // Kaldığın Yerden Devam
          if (relevantResume.isNotEmpty)
            SliverToBoxAdapter(
              child: _ResumeRow(records: relevantResume, state: state),
            ),

          // Tümü Izgarası
          if (all.isNotEmpty)
            SliverToBoxAdapter(
              child: _NetflixSection(
                title: isMovies ? 'Tüm Filmler' : 'Tüm Diziler',
                items: all,
                onItemTap: widget.onItemTap,
              ),
            ),

          // Kategorilere göre satırlar
          for (final (id, name) in state.vodCategories)
            if (id != 'all' && byCategory[id] != null && byCategory[id]!.isNotEmpty)
              SliverToBoxAdapter(
                child: _NetflixSection(
                  title: name,
                  items: byCategory[id]!,
                  onItemTap: widget.onItemTap,
                ),
              ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

// ==================== Netflix Hero Banner ====================

class _NetflixHeroBanner extends StatefulWidget {
  const _NetflixHeroBanner({required this.item, required this.onTap});
  final _VodItem item;
  final VoidCallback onTap;

  @override
  State<_NetflixHeroBanner> createState() => _NetflixHeroBannerState();
}

class _NetflixHeroBannerState extends State<_NetflixHeroBanner> {
  final _focus = FocusNode(debugLabel: 'hero');

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

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final focused = _focus.hasFocus;
    final width = MediaQuery.of(context).size.width;

    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: focused ? 280 : 260,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: focused ? [
              BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: 2),
            ] : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Arka plan poster
                if (item.poster != null && item.poster!.isNotEmpty)
                  Image.network(
                    item.poster!,
                    fit: BoxFit.cover,
                    cacheWidth: width.round(),
                    errorBuilder: (_, _, _) => _heroPlaceholder(),
                    loadingBuilder: (_, child, p) => p == null ? child : _heroPlaceholder(),
                  )
                else
                  _heroPlaceholder(),

                // Gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black87,
                        Colors.black,
                      ],
                      stops: [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),

                // Film/Dizi rozeti
                Positioned(
                  top: 16, left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.isMovie ? Colors.blue : Colors.purple,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isMovie ? 'FİLM' : 'DİİZ',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Alt bilgi
                Positioned(
                  left: 16, right: 16, bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (item.rating != null && item.rating!.isNotEmpty) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(item.rating!, style: const TextStyle(
                              color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold,
                            )),
                            const SizedBox(width: 12),
                          ],
                          if (item.genre != null && item.genre!.isNotEmpty)
                            Expanded(
                              child: Text(
                                item.genre!,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                      if (item.plot != null && item.plot!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.plot!,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3),
                        ),
                      ],
                      const SizedBox(height: 10),
                      // Butonlar
                      Row(
                        children: [
                          _NetflixButton(
                            icon: Icons.play_arrow,
                            label: 'İzle',
                            primary: true,
                            onTap: widget.onTap,
                          ),
                          const SizedBox(width: 10),
                          _NetflixButton(
                            icon: Icons.info_outline,
                            label: 'Bilgi',
                            primary: false,
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
    );
  }

  Widget _heroPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.movie_creation_outlined, color: Colors.white12, size: 80),
      ),
    );
  }
}

// ==================== Netflix Bölüm ====================

class _NetflixSection extends StatefulWidget {
  const _NetflixSection({
    required this.title,
    required this.items,
    required this.onItemTap,
  });

  final String title;
  final List<_VodItem> items;
  final void Function(dynamic) onItemTap;

  @override
  State<_NetflixSection> createState() => _NetflixSectionState();
}

class _NetflixSectionState extends State<_NetflixSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _NetflixPoster(
              item: widget.items[i],
              onTap: () => widget.onItemTap(widget.items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ==================== Netflix Poster ====================

class _NetflixPoster extends StatefulWidget {
  const _NetflixPoster({required this.item, required this.onTap});
  final _VodItem item;
  final VoidCallback onTap;

  @override
  State<_NetflixPoster> createState() => _NetflixPosterState();
}

class _NetflixPosterState extends State<_NetflixPoster> {
  final _focus = FocusNode();
  bool _showInfo = false;
  Timer? _infoTimer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        // 500ms sonra bilgi göster (5 saniye değil, daha hızlı tepki)
        _infoTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted && _focus.hasFocus) setState(() => _showInfo = true);
        });
      } else {
        _infoTimer?.cancel();
        if (_showInfo) setState(() => _showInfo = false);
      }
    });
  }

  @override
  void dispose() {
    _infoTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final focused = _focus.hasFocus;

    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: focused ? 140 : 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: focused ? [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ] : [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                      ),
                    ],
                    border: focused
                        ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (item.poster != null && item.poster!.isNotEmpty)
                          Image.network(
                            item.poster!,
                            fit: BoxFit.cover,
                            cacheWidth: 280,
                            errorBuilder: (_, _, _) => _posterPlaceholder(),
                            loadingBuilder: (_, child, p) => p == null ? child : _posterPlaceholder(),
                          )
                        else
                          _posterPlaceholder(),

                        // IMDb puanı rozeti
                        if (item.rating != null && item.rating!.isNotEmpty)
                          Positioned(
                            top: 4, right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 10),
                                  const SizedBox(width: 2),
                                  Text(item.rating!, style: const TextStyle(
                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
                                  )),
                                ],
                              ),
                            ),
                          ),

                        // Film/Dizi rozeti
                        Positioned(
                          top: 4, left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isMovie ? Colors.blue.withValues(alpha: 0.8) : Colors.purple.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.isMovie ? 'FİLM' : 'DİZİ',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Başlık
              const SizedBox(height: 6),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: focused ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _posterPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(child: Icon(Icons.movie, color: Colors.white12, size: 32)),
    );
  }
}

// ==================== Devam Et Satırı ====================

class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.records, required this.state});
  final List<ResumeRecord> records;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text('Devam Et', style: TextStyle(
                color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold,
              )),
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
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VodPlayerScreen(
                      url: r.url, title: r.title, mediaId: r.id,
                      poster: r.poster, isMovie: r.isMovie, resumePosition: r.position,
                    ),
                  ),
                ),
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
                              if (r.poster != null && r.poster!.isNotEmpty)
                                Image.network(r.poster!, fit: BoxFit.cover, cacheWidth: 240,
                                  errorBuilder: (_, _, _) => _placeholder())
                              else
                                _placeholder(),
                              Positioned(
                                left: 0, right: 0, bottom: 0,
                                child: Container(
                                  height: 4,
                                  color: Colors.black.withValues(alpha: 0.5),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: r.progress,
                                    child: Container(color: Colors.amber),
                                  ),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      Text(r.remainingText, maxLines: 1,
                        style: const TextStyle(fontSize: 10, color: Colors.white54)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(color: Colors.white12,
      child: const Center(child: Icon(Icons.movie, color: Colors.white38, size: 32)));
  }
}

// ==================== Yardımcı Sınıflar ====================

class _VodItem {
  const _VodItem({
    required this.id, required this.name, this.poster,
    this.rating, this.categoryId, this.plot, this.genre,
    required this.isMovie,
  });

  final int id;
  final String name;
  final String? poster;
  final String? rating;
  final String? categoryId;
  final String? plot;
  final String? genre;
  final bool isMovie;
}

// ==================== Netflix Buton ====================

class _NetflixButton extends StatelessWidget {
  const _NetflixButton({
    required this.icon,
    required this.label,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: primary ? Colors.black : Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              color: primary ? Colors.black : Colors.white,
              fontSize: 13, fontWeight: FontWeight.w600,
            )),
          ],
        ),
      ),
    );
  }
}
