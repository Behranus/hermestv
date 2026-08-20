import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/screens/movie_detail_screen.dart';
import 'package:iptv_player/screens/series_detail_screen.dart';
import 'package:iptv_player/screens/vod_player_screen.dart';
import 'package:iptv_player/services/resume_service.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:provider/provider.dart';

/// Turkcell TV Plus tarzı VOD ekranı:
/// - Üstte büyük hero banner
/// - Kategori filtreleri (yatay scroll)
/// - 5×4 ızgara düzeninde film/dizi kartları
/// - Kumanda ile tam erişim
class VodScreen extends StatefulWidget {
  const VodScreen({super.key, this.onGoToSetup});

  final VoidCallback? onGoToSetup;

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedCategoryId;
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _focusSection = 0; // 0=üst bar, 1=kategoriler, 2=grid
  final _categoryScrollKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.hasVod) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.movie_filter_outlined, color: Colors.white24, size: 80),
              const SizedBox(height: 16),
              const Text('VOD için Xtream bağlantısı gerekir',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
              const SizedBox(height: 8),
              Text('Kurulum sekmesinden Xtream Codes girişi yap',
                style: TextStyle(color: Colors.white38, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final key = event.logicalKey;
        // ESC: geri
        if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        // Geri tuşu: bir önceki bölüme geç
        if (key == LogicalKeyboardKey.arrowLeft && _focusSection > 0) {
          setState(() => _focusSection--);
          return KeyEventResult.handled;
        }
        // Sağ ok: bir sonraki bölüme geç
        if (key == LogicalKeyboardKey.arrowRight && _focusSection < 2) {
          setState(() => _focusSection++);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Column(
          children: [
            // Üst bar
            _TurkcellTopBar(
              onBack: () => Navigator.of(context).pop(),
              onRefresh: state.loadVod,
              isLoading: state.vodLoading,
              onSearchToggle: () => setState(() => _showSearch = !_showSearch),
              showSearch: _showSearch,
            ),

            // Arama kutusu
            if (_showSearch)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Film veya dizi ara...',
                    hintStyle: TextStyle(color: Colors.white38),
                    prefixIcon: Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF161B22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

            // Film / Dizi sekmeleri
            Container(
              color: const Color(0xFF0D0D1A),
              child: Row(
                children: [
                  _TabChip('Filmler', _tabController.index == 0, () {
                    _tabController.animateTo(0);
                    setState(() => _selectedCategoryId = null);
                  }),
                  _TabChip('Diziler', _tabController.index == 1, () {
                    _tabController.animateTo(1);
                    setState(() => _selectedCategoryId = null);
                  }),
                ],
              ),
            ),

            // Kategori filtreleri
            _CategoryFilterBar(
              key: _categoryScrollKey,
              categories: state.vodCategories,
              selectedId: _selectedCategoryId,
              onSelect: (id) => setState(() => _selectedCategoryId = id),
              isMovieTab: _tabController.index == 0,
              movieCount: state.filteredVodMovies.length,
              seriesCount: state.filteredVodSeries.length,
            ),

            // İçerik
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TurkcellContentGrid(
                    isMovies: true,
                    state: state,
                    selectedCategoryId: _selectedCategoryId,
                    searchQuery: _searchQuery,
                    onItemTap: (item) {
                      final movie = state.filteredVodMovies.where((m) => m.id == item.id).firstOrNull;
                      if (movie != null) Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: movie)),
                      );
                    },
                  ),
                  _TurkcellContentGrid(
                    isMovies: false,
                    state: state,
                    selectedCategoryId: _selectedCategoryId,
                    searchQuery: _searchQuery,
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
      ),
    );
  }
}

// ==================== Üst Bar ====================
class _TurkcellTopBar extends StatelessWidget {
  const _TurkcellTopBar({
    required this.onBack,
    required this.onRefresh,
    required this.isLoading,
    required this.onSearchToggle,
    required this.showSearch,
  });

  final VoidCallback onBack, onRefresh, onSearchToggle;
  final bool isLoading, showSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
      color: const Color(0xFF0D0D1A),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: Colors.white)),
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0050),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('BBTV', style: TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          const Text('VOD', style: TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(
            onPressed: onSearchToggle,
            icon: Icon(showSearch ? Icons.close : Icons.search, color: Colors.white54),
          ),
          if (isLoading)
            const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 22),
          ),
        ],
      ),
    );
  }
}

// ==================== Tab Chip ====================
class _TabChip extends StatefulWidget {
  const _TabChip(this.label, this.selected, this.onTap);
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected ? const Color(0xFFFF0050) : const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(20),
            border: _focused ? Border.all(color: Colors.white38, width: 2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.label == 'Filmler' ? Icons.movie : Icons.tv,
                color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(widget.label, style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: (widget.selected || _focused) ? FontWeight.bold : FontWeight.normal,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Kategori Filtre Barı ====================
class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelect,
    required this.isMovieTab,
    required this.movieCount,
    required this.seriesCount,
  });

  final List<(String, String)> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final bool isMovieTab;
  final int movieCount, seriesCount;

  @override
  Widget build(BuildContext context) {
    final count = isMovieTab ? movieCount : seriesCount;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          _FilterChip(
            label: 'Tümü ($count)',
            selected: selectedId == null,
            onTap: () => onSelect(null),
            color: const Color(0xFFFF0050),
          ),
          ...categories.map((cat) {
            final (id, name) = cat;
            return _FilterChip(
              label: name,
              selected: selectedId == id,
              onTap: () => onSelect(id),
              color: const Color(0xFF1E88E5),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: widget.selected ? widget.color.withValues(alpha: 0.3) : const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected ? widget.color : (_focused ? Colors.white38 : Colors.transparent),
              width: _focused ? 2 : 1,
            ),
          ),
          child: Text(widget.label, style: TextStyle(
            color: widget.selected ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: (widget.selected || _focused) ? FontWeight.bold : FontWeight.normal,
          )),
        ),
      ),
    );
  }
}

// ==================== İçerik Izgarası ====================
class _TurkcellContentGrid extends StatefulWidget {
  const _TurkcellContentGrid({
    required this.isMovies,
    required this.state,
    required this.selectedCategoryId,
    required this.searchQuery,
    required this.onItemTap,
  });

  final bool isMovies;
  final AppState state;
  final String? selectedCategoryId;
  final String searchQuery;
  final void Function(dynamic) onItemTap;

  @override
  State<_TurkcellContentGrid> createState() => _TurkcellContentGridState();
}

class _TurkcellContentGridState extends State<_TurkcellContentGrid>
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

    // Filtreleme
    var filtered = all;
    if (widget.selectedCategoryId != null) {
      filtered = all.where((item) => item.categoryId == widget.selectedCategoryId).toList();
    }
    if (widget.searchQuery.isNotEmpty) {
      filtered = filtered.where((item) =>
        item.name.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();
    }

    // Devam ettirme kayıtları
    final relevantResume = _resumeRecords
        .where((r) => r.isMovie == isMovies && !r.isCompleted)
        .toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));

    if (filtered.isEmpty && !state.vodLoading && relevantResume.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: Colors.white24, size: 64),
            SizedBox(height: 8),
            Text('İçerik bulunamadı', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Hero Banner (ilk film)
        if (filtered.isNotEmpty && widget.selectedCategoryId == null && widget.searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: _TurkcellHeroBanner(
              item: filtered.first,
              onTap: () => widget.onItemTap(filtered.first),
            ),
          ),

        // Kaldığın Yerden Devam
        if (relevantResume.isNotEmpty)
          SliverToBoxAdapter(
            child: _ResumeRow(records: relevantResume, state: state),
          ),

        // Başlık
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              isMovies ? 'Tüm Filmler (${filtered.length})' : 'Tüm Diziler (${filtered.length})',
              style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // 5×4 Izgara
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.67,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _TurkcellPosterCard(
                item: filtered[i],
                onTap: () => widget.onItemTap(filtered[i]),
              ),
              childCount: filtered.length,
            ),
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }
}

// ==================== Hero Banner ====================
class _TurkcellHeroBanner extends StatefulWidget {
  const _TurkcellHeroBanner({required this.item, required this.onTap});
  final _VodItem item;
  final VoidCallback onTap;

  @override
  State<_TurkcellHeroBanner> createState() => _TurkcellHeroBannerState();
}

class _TurkcellHeroBannerState extends State<_TurkcellHeroBanner> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
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
          height: _focused ? 280 : 260,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _focused ? [
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
                  Image.network(item.poster!, fit: BoxFit.cover,
                    cacheWidth: width.round(),
                    errorBuilder: (_, _, _) => _placeholder(),
                    loadingBuilder: (_, child, p) => p == null ? child : _placeholder())
                else
                  _placeholder(),

                // Gradient overlay
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.transparent, Colors.black87, Colors.black],
                      stops: [0.0, 0.4, 0.7, 1.0],
                    ),
                  ),
                ),

                // Film/Dizi rozeti
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0050),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.isMovie ? 'FİLM' : 'DİİZ',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // Alt bilgi
                Positioned(
                  left: 14, right: 14, bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)])),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (item.rating != null && item.rating!.isNotEmpty) ...[
                          const Icon(Icons.star, color: Color(0xFFFFB300), size: 16),
                          const SizedBox(width: 4),
                          Text(item.rating!, style: const TextStyle(color: Color(0xFFFFB300),
                            fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                        ],
                        if (item.genre != null && item.genre!.isNotEmpty)
                          Expanded(child: Text(item.genre!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 12))),
                      ]),
                      if (item.plot != null && item.plot!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.plot!, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
                      ],
                      const SizedBox(height: 8),
                      Row(children: [
                        _HeroButton(icon: Icons.play_arrow, label: 'İzle', primary: true, onTap: widget.onTap),
                        const SizedBox(width: 8),
                        _HeroButton(icon: Icons.info_outline, label: 'Bilgi', primary: false, onTap: widget.onTap),
                      ]),
                    ],
                  ),
                ),

                // Odak göstergesi
                if (_focused)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF1E88E5), width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(color: const Color(0xFF1A1A2E),
      child: const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white12, size: 80)));
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({required this.icon, required this.label, required this.primary, required this.onTap});
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? const Color(0xFFFF0050) : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ==================== Poster Kartı (5×4 ızgara) ====================
class _TurkcellPosterCard extends StatefulWidget {
  const _TurkcellPosterCard({required this.item, required this.onTap});
  final _VodItem item;
  final VoidCallback onTap;

  @override
  State<_TurkcellPosterCard> createState() => _TurkcellPosterCardState();
}

class _TurkcellPosterCardState extends State<_TurkcellPosterCard> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

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
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(8),
            border: _focused ? Border.all(color: const Color(0xFF1E88E5), width: 2) : null,
            boxShadow: _focused ? [
              BoxShadow(color: Colors.black54, blurRadius: 12, spreadRadius: 1),
            ] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poster
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.poster != null && item.poster!.isNotEmpty)
                        Image.network(item.poster!, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _posterPlaceholder())
                      else
                        _posterPlaceholder(),

                      // IMDb puanı (sağ üst)
                      if (item.rating != null && item.rating!.isNotEmpty)
                        Positioned(
                          top: 4, right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star, color: Color(0xFFFFB300), size: 10),
                                const SizedBox(width: 2),
                                Text(item.rating!, style: const TextStyle(
                                  color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),

                      // Film/Dizi rozeti (sol üst)
                      Positioned(
                        top: 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF0050),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            item.isMovie ? 'FİLM' : 'DİİZ',
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Hover overlay
                      if (_focused)
                        Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: const Center(
                            child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 48),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bilgi
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _focused ? Colors.white : Colors.white70,
                        fontSize: 11,
                        fontWeight: _focused ? FontWeight.bold : FontWeight.normal,
                      )),
                    if (item.genre != null && item.genre!.isNotEmpty)
                      Text(item.genre!, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
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
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Kaldığın Yerden Devam', style: TextStyle(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
              final progress = r.duration.inSeconds > 0
                  ? r.position.inSeconds / r.duration.inSeconds : 0.0;
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VodPlayerScreen(
                      url: r.url, title: r.title, mediaId: r.id,
                      poster: r.poster, isMovie: r.isMovie,
                      resumePosition: r.position,
                    ),
                  ));
                },
                child: SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 80,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (r.poster != null)
                                Image.network(r.poster!, fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(color: const Color(0xFF1A1A2E)))
                              else
                                Container(color: const Color(0xFF1A1A2E)),
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: LinearProgressIndicator(
                                  value: progress, minHeight: 3,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation(
                                    progress > 0.9 ? Colors.green : const Color(0xFF1E88E5)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
}

// ==================== VodItem Model ====================
class _VodItem {
  final int id;
  final String name;
  final String? poster, rating, categoryId, plot, genre;
  final bool isMovie;

  _VodItem({
    required this.id, required this.name, this.poster, this.rating,
    this.categoryId, this.plot, this.genre, required this.isMovie,
  });
}
