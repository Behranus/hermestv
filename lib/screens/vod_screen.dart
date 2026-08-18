import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iptv_player/models/vod.dart';
import 'package:iptv_player/screens/movie_detail_screen.dart';
import 'package:iptv_player/screens/series_detail_screen.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:iptv_player/widgets/channel_list.dart';
import 'package:provider/provider.dart';

enum _VodMode { movies, series }

/// VOD ana ekranı — Netflix tarzı: arama + film/dizi seçici
/// kaydırılınca kaybolur, tam ekran film/dizi ızgarasına yer açılır.
class VodScreen extends StatefulWidget {
  const VodScreen({super.key, this.onGoToSetup});

  final VoidCallback? onGoToSetup;

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen> {
  _VodMode _mode = _VodMode.movies;

  final FocusNode _searchFocus = FocusNode(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          (event.logicalKey == LogicalKeyboardKey.goBack ||
              event.logicalKey == LogicalKeyboardKey.escape)) {
        node.unfocus();
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );

  @override
  void dispose() {
    _searchFocus.dispose();
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
      body: _VodBody(
        state: state,
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
        searchFocus: _searchFocus,
        onMovieTap: (m) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: m)),
        ),
        onSeriesTap: (s) => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: s)),
        ),
      ),
    );
  }
}

/// Netflix tarzı: SliverAppBar ile arama + kategori, scroll'da kaybolur.
class _VodBody extends StatelessWidget {
  const _VodBody({
    required this.state,
    required this.mode,
    required this.onModeChanged,
    required this.searchFocus,
    required this.onMovieTap,
    required this.onSeriesTap,
  });

  final AppState state;
  final _VodMode mode;
  final ValueChanged<_VodMode> onModeChanged;
  final FocusNode searchFocus;
  final void Function(VodMovie) onMovieTap;
  final void Function(VodSeries) onSeriesTap;

  @override
  Widget build(BuildContext context) {
    if (state.vodLoading && state.vodMovies.isEmpty && state.vodSeries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.vodError != null &&
        state.vodMovies.isEmpty &&
        state.vodSeries.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'VOD kataloğu yüklenemedi',
        subtitle: state.vodError,
        actionLabel: 'Tekrar dene',
        onAction: state.loadVod,
      );
    }

    final isMovies = mode == _VodMode.movies;
    final all = <_RowItem>[
      if (isMovies)
        for (final m in state.filteredVodMovies)
          _RowItem(m.id, m.name, m.poster, m.rating, m.categoryId)
      else
        for (final s in state.filteredVodSeries)
          _RowItem(s.id, s.name, s.cover, s.rating, s.categoryId),
    ];

    return CustomScrollView(
      slivers: [
        // ---- Collapsible search + category bar ----
        SliverAppBar(
          expandedHeight: 120,
          pinned: true,
          floating: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          flexibleSpace: FlexibleSpaceBar(
            background: Column(
              children: [
                const SizedBox(height: 48), // AppBar collapse padding
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: TextField(
                    focusNode: searchFocus,
                    onChanged: state.setVodQuery,
                    onSubmitted: (_) => searchFocus.unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Film veya dizi ara…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: state.vodQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => state.setVodQuery(''),
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: SegmentedButton<_VodMode>(
                    segments: const [
                      ButtonSegment(
                        value: _VodMode.movies,
                        label: Text('Filmler'),
                        icon: Icon(Icons.movie, size: 16),
                      ),
                      ButtonSegment(
                        value: _VodMode.series,
                        label: Text('Diziler'),
                        icon: Icon(Icons.tv, size: 16),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => onModeChanged(s.first),
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
            if (state.vodMovies.isNotEmpty || state.vodSeries.isNotEmpty)
              IconButton(
                tooltip: 'Kataloğu yenile',
                icon: const Icon(Icons.refresh),
                onPressed: state.loadVod,
              ),
          ],
        ),

        // ---- Content ----
        if (all.isEmpty)
          const SliverFillRemaining(
            child: EmptyState(
              icon: Icons.search_off,
              title: 'Sonuç bulunamadı',
              subtitle:
                  'Arama veya kategori filtresini değiştirmeyi deneyin.',
            ),
          )
        else
          _NetflixSliverList(
            isMovies: isMovies,
            all: all,
            movies: isMovies ? state.filteredVodMovies : null,
            series: isMovies ? null : state.filteredVodSeries,
            categories: state.vodCategories,
            onMovieTap: onMovieTap,
            onSeriesTap: onSeriesTap,
          ),
      ],
    );
  }
}

class _RowItem {
  const _RowItem(this.id, this.name, this.poster, this.rating, this.categoryId);

  final int id;
  final String name;
  final String? poster;
  final String? rating;
  final String? categoryId;
}

/// Netflix tarzı sliver list — hero + kategori satırları.
class _NetflixSliverList extends StatelessWidget {
  const _NetflixSliverList({
    required this.isMovies,
    required this.all,
    required this.categories,
    required this.onMovieTap,
    required this.onSeriesTap,
    this.movies,
    this.series,
  });

  final bool isMovies;
  final List<_RowItem> all;
  final List<(String, String)> categories;
  final void Function(VodMovie) onMovieTap;
  final void Function(VodSeries) onSeriesTap;
  final List<VodMovie>? movies;
  final List<VodSeries>? series;

  void _openItem(_RowItem item) {
    if (isMovies) {
      final m = movies?.where((m) => m.id == item.id).firstOrNull;
      if (m != null) onMovieTap(m);
    } else {
      final s = series?.where((s) => s.id == item.id).firstOrNull;
      if (s != null) onSeriesTap(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = all.first;

    // Kategorilere göre grupla
    final byCategory = <String?, List<_RowItem>>{};
    for (final item in all.skip(1)) {
      byCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }

    return SliverList(
      delegate: SliverChildListDelegate([
        // ---- Hero: büyük tanıtım kartı ----
        _HeroCard(
          item: hero,
          isMovie: isMovies,
          onTap: () => _openItem(hero),
        ),
        const SizedBox(height: 20),
        _RowSection(
          title: isMovies ? 'Tüm Filmler' : 'Tüm Diziler',
          items: all,
          isMovie: isMovies,
          onTap: _openItem,
        ),
        // ---- Kategori satırları ----
        for (final (id, name) in categories)
          if (id != 'all' && (byCategory[id]?.length ?? 0) > 0) ...[
            const SizedBox(height: 20),
            _RowSection(
              title: name,
              items: byCategory[id]!,
              isMovie: isMovies,
              onTap: _openItem,
            ),
          ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ==================== Hero Card ====================

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.item, required this.isMovie, required this.onTap});

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
                            if (widget.isMovie)
                              const _Pill(label: 'Film')
                            else
                              const _Pill(label: 'Dizi'),
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
              Icon(icon, color: filled ? Colors.black : Colors.white, size: 20),
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused ? colors.primary : Colors.transparent,
                  width: focused ? 3 : 0,
                ),
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.4),
                          blurRadius: 12,
                        )
                      ]
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _poster(colors),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.center,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        if (item.rating != null && item.rating!.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  color: Colors.amber, size: 11),
                              const SizedBox(width: 2),
                              Text(
                                item.rating!,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
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

  Widget _poster(ColorScheme colors) {
    final url = widget.item.poster;
    if (url == null || url.isEmpty) {
      return ColoredBox(color: colors.surfaceContainerHighest);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 220,
      errorBuilder: (_, _, _) =>
          ColoredBox(color: colors.surfaceContainerHighest),
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : ColoredBox(color: colors.surfaceContainerHighest),
    );
  }
}
