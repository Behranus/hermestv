import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hermestv/l10n/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:hermestv/screens/movie_detail_screen.dart';
import 'package:hermestv/screens/series_detail_screen.dart';
import 'package:hermestv/screens/vod_player_screen.dart';
import 'package:hermestv/services/resume_service.dart';
import 'package:hermestv/state/app_state.dart';

/// Netflix / Turkcell TV Plus tarzi VOD ekrani:
/// - Ustte buyuk hero banner
/// - Film / Dizi sekmeleri
/// - Kategori filtreleri
/// - 5x4 izgara duzeninde poster kartlari
class VodScreen extends StatefulWidget {
  const VodScreen({super.key, this.onGoToSetup});
  final VoidCallback? onGoToSetup;

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _selectedCategoryId;
  bool _showSearch = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
    final colors = Theme.of(context).colorScheme;

    if (!state.hasVod) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_filter_outlined, size: 72, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(context.watch<LocaleProvider>().loc.vodNeedsXtream,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 8),
            Text(context.watch<LocaleProvider>().loc.vodXtreamHint,
                style: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 13)),
          ],
        ),
      );
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.escape ||
            event.logicalKey == LogicalKeyboardKey.goBack) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        children: [
          // ── Ust Bar ──
          _VodTopBar(
            showSearch: _showSearch,
            isLoading: state.vodLoading,
            onSearchToggle: () => setState(() => _showSearch = !_showSearch),
            onRefresh: state.loadVod,
          ),

          // ── Arama ──
          if (_showSearch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: colors.surfaceContainerLow,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Film veya dizi ara...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),

          // ── Film / Dizi sekmeleri ──
          Container(
            color: colors.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _TabPill(
                  label: 'Filmler',
                  icon: Icons.movie_rounded,
                  selected: _tabController.index == 0,
                  onTap: () {
                    _tabController.animateTo(0);
                    setState(() => _selectedCategoryId = null);
                  },
                ),
                const SizedBox(width: 8),
                _TabPill(
                  label: 'Diziler',
                  icon: Icons.tv_rounded,
                  selected: _tabController.index == 1,
                  onTap: () {
                    _tabController.animateTo(1);
                    setState(() => _selectedCategoryId = null);
                  },
                ),
              ],
            ),
          ),

          // ── Kategori filtreleri ──
          _CategoryChips(
            categories: state.filteredVodCategories,
            selectedId: _selectedCategoryId,
            onSelect: (id) => setState(() => _selectedCategoryId = id),
            isMovieTab: _tabController.index == 0,
            movieCount: state.filteredVodMovies.length,
            seriesCount: state.filteredVodSeries.length,
          ),

          // ── Icerik ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _VodGrid(
                  isMovies: true,
                  state: state,
                  selectedCategoryId: _selectedCategoryId,
                  searchQuery: _searchQuery,
                  onItemTap: (item) {
                    final movie = state.filteredVodMovies.where((m) => m.id == item.id).firstOrNull;
                    if (movie != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MovieDetailScreen(movie: movie),
                      ));
                    }
                  },
                ),
                _VodGrid(
                  isMovies: false,
                  state: state,
                  selectedCategoryId: _selectedCategoryId,
                  searchQuery: _searchQuery,
                  onItemTap: (item) {
                    final series = state.filteredVodSeries.where((s) => s.id == item.id).firstOrNull;
                    if (series != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SeriesDetailScreen(series: series),
                      ));
                    }
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

// ═══════════════════════════════════════════════════════
// VOD Top Bar
// ═══════════════════════════════════════════════════════
class _VodTopBar extends StatelessWidget {
  const _VodTopBar({
    required this.showSearch,
    required this.isLoading,
    required this.onSearchToggle,
    required this.onRefresh,
  });

  final bool showSearch;
  final bool isLoading;
  final VoidCallback onSearchToggle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3C8AFF), Color(0xFF6C5CE7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'HTV',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'VOD',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          _VodIconButton(
            icon: showSearch ? Icons.close : Icons.search,
            onTap: onSearchToggle,
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          _VodIconButton(icon: Icons.refresh_rounded, onTap: onRefresh),
        ],
      ),
    );
  }
}

class _VodIconButton extends StatelessWidget {
  const _VodIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: colors.onSurfaceVariant),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Tab Pill (Filmler / Diziler)
// ═══════════════════════════════════════════════════════
class _TabPill extends StatefulWidget {
  const _TabPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? colors.primary.withValues(alpha: 0.15)
                : colors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected || _focused
                  ? (widget.selected ? colors.primary : colors.outline)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 16,
                  color: widget.selected ? colors.primary : colors.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.selected ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Kategori Cipleri
// ═══════════════════════════════════════════════════════
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _FilterPill(
            label: 'Tum ($count)',
            selected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          ...categories.map((cat) {
            final (id, name) = cat;
            return _FilterPill(
              label: name,
              selected: selectedId == id,
              onTap: () => onSelect(id),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterPill extends StatefulWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FilterPill> createState() => _FilterPillState();
}

class _FilterPillState extends State<_FilterPill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: widget.selected
                ? colors.primary.withValues(alpha: 0.15)
                : colors.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected || _focused
                  ? (widget.selected ? colors.primary : colors.outline)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: widget.selected || _focused ? FontWeight.w600 : FontWeight.normal,
              color: widget.selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// VOD Izgarasi
// ═══════════════════════════════════════════════════════
class _VodGrid extends StatefulWidget {
  const _VodGrid({
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
  State<_VodGrid> createState() => _VodGridState();
}

class _VodGridState extends State<_VodGrid> with AutomaticKeepAliveClientMixin {
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
    final colors = Theme.of(context).colorScheme;

    final all = <_VodItem>[];
    if (widget.isMovies) {
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

    var filtered = all;
    if (widget.selectedCategoryId != null) {
      filtered = all.where((item) => item.categoryId == widget.selectedCategoryId).toList();
    }
    if (widget.searchQuery.isNotEmpty) {
      filtered = all.where((item) =>
          item.name.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();
    }

    final relevantResume = _resumeRecords
        .where((r) => r.isMovie == widget.isMovies && !r.isCompleted)
        .toList()
      ..sort((a, b) => b.watchedAt.compareTo(a.watchedAt));

    if (filtered.isEmpty && !state.vodLoading && relevantResume.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text('Icerik bulunamadi', style: TextStyle(color: colors.onSurfaceVariant)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Hero Banner (ilk film)
        if (filtered.isNotEmpty && widget.selectedCategoryId == null && widget.searchQuery.isEmpty)
          SliverToBoxAdapter(
            child: _HeroBanner(
              item: filtered.first,
              onTap: () => widget.onItemTap(filtered.first),
            ),
          ),

        // Kaldigin Yerden Devam
        if (relevantResume.isNotEmpty)
          SliverToBoxAdapter(
            child: _ResumeRow(records: relevantResume),
          ),

        // Baslik
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isMovies ? 'Tum Filmler (${filtered.length})' : 'Tum Diziler (${filtered.length})',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colors.onSurface),
                ),
              ],
            ),
          ),
        ),

        // 5x4 Izgara
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.65,
              crossAxisSpacing: 8,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _PosterCard(
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

// ═══════════════════════════════════════════════════════
// Hero Banner
// ═══════════════════════════════════════════════════════
class _HeroBanner extends StatefulWidget {
  const _HeroBanner({required this.item, required this.onTap});
  final _VodItem item;
  final VoidCallback onTap;

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
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
    final colors = Theme.of(context).colorScheme;

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
          height: _focused ? 290 : 270,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Arka plan poster
                if (item.poster != null && item.poster!.isNotEmpty)
                  Image.network(item.poster!,
                      fit: BoxFit.cover,
                      cacheWidth: width.round(),
                      errorBuilder: (_, __, ___) => _placeholder(),
                      loadingBuilder: (_, child, p) =>
                          p == null ? child : _placeholder())
                else
                  _placeholder(),

                // Gradient overlay
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black87,
                        Colors.black,
                      ],
                      stops: [0.0, 0.35, 0.65, 1.0],
                    ),
                  ),
                ),

                // Film/Dizi rozeti
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.isMovie
                          ? colors.primary
                          : const Color(0xFF6C5CE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isMovie ? 'FILM' : 'DIZI',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                // Alt bilgi
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black)
                              ])),
                      const SizedBox(height: 4),
                      Row(children: [
                        if (item.rating != null && item.rating!.isNotEmpty) ...[
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFF5A623), size: 18),
                          const SizedBox(width: 4),
                          Text(item.rating!,
                              style: const TextStyle(
                                  color: Color(0xFFF5A623),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                        ],
                        if (item.genre != null && item.genre!.isNotEmpty)
                          Expanded(
                              child: Text(item.genre!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12))),
                      ]),
                      if (item.plot != null && item.plot!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.plot!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                height: 1.3)),
                      ],
                      const SizedBox(height: 10),
                      Row(children: [
                        _HeroBtn(
                            icon: Icons.play_arrow_rounded,
                            label: 'Izle',
                            primary: true,
                            onTap: widget.onTap),
                        const SizedBox(width: 8),
                        _HeroBtn(
                            icon: Icons.info_outline,
                            label: 'Bilgi',
                            primary: false,
                            onTap: widget.onTap),
                      ]),
                    ],
                  ),
                ),

                // Odak cercevesi
                if (_focused)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: colors.primary.withValues(alpha: 0.8),
                          width: 3),
                      borderRadius: BorderRadius.circular(14),
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
    return Container(
      color: const Color(0xFF1E2030),
      child: const Center(
          child: Icon(Icons.movie_creation_outlined,
              color: Colors.white12, size: 80)),
    );
  }
}

class _HeroBtn extends StatelessWidget {
  const _HeroBtn(
      {required this.icon,
      required this.label,
      required this.primary,
      required this.onTap});

  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: primary
              ? colors.primary
              : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Poster Karti (5x4 Izgara)
// ═══════════════════════════════════════════════════════
class _PosterCard extends StatefulWidget {
  const _PosterCard({required this.item, required this.onTap});
  final _VodItem item;
  final VoidCallback onTap;

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard> {
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
    final colors = Theme.of(context).colorScheme;

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
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused
                  ? colors.primary.withValues(alpha: 0.8)
                  : colors.outline.withValues(alpha: 0.3),
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poster
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(9)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (item.poster != null && item.poster!.isNotEmpty)
                        Image.network(item.poster!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _posterPlaceholder())
                      else
                        _posterPlaceholder(),

                      // IMDb puani
                      if (item.rating != null && item.rating!.isNotEmpty)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Color(0xFFF5A623), size: 10),
                                const SizedBox(width: 2),
                                Text(item.rating!,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),

                      // Film/Dizi etiketi
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: item.isMovie
                                ? colors.primary
                                : const Color(0xFF6C5CE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.isMovie ? 'F' : 'D',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Odak overlay
                      if (_focused)
                        Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: Center(
                            child: Icon(Icons.play_circle_fill_rounded,
                                color: Colors.white.withValues(alpha: 0.85),
                                size: 44),
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
                    Text(item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _focused ? colors.onSurface : colors.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: _focused ? FontWeight.w600 : FontWeight.w500,
                          height: 1.2,
                        )),
                    if (item.genre != null && item.genre!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(item.genre!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                                fontSize: 9)),
                      ),
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
      color: const Color(0xFF1E2030),
      child: Center(
        child: Icon(Icons.movie_rounded,
            color: Colors.white.withValues(alpha: 0.1), size: 32),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Devam Et Satiri
// ═══════════════════════════════════════════════════════
class _ResumeRow extends StatelessWidget {
  const _ResumeRow({required this.records});
  final List<ResumeRecord> records;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Kaldigin Yerden Devam',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SizedBox(
          height: 145,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final r = records[i];
              final progress = r.duration.inSeconds > 0
                  ? r.position.inSeconds / r.duration.inSeconds
                  : 0.0;
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => VodPlayerScreen(
                      url: r.url,
                      title: r.title,
                      mediaId: r.id,
                      poster: r.poster,
                      isMovie: r.isMovie,
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
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 80,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (r.poster != null)
                                Image.network(r.poster!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Container(color: colors.surface))
                              else
                                Container(color: colors.surface),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 3,
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation(
                                      progress > 0.9
                                          ? colors.tertiary
                                          : colors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(r.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 11)),
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

// ═══════════════════════════════════════════════════════
// VodItem Model
// ═══════════════════════════════════════════════════════
class _VodItem {
  final int id;
  final String name;
  final String? poster, rating, categoryId, plot, genre;
  final bool isMovie;

  _VodItem({
    required this.id,
    required this.name,
    this.poster,
    this.rating,
    this.categoryId,
    this.plot,
    this.genre,
    required this.isMovie,
  });
}
