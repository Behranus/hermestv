import 'package:flutter/material.dart';
import 'package:hermestv/models/vod.dart';
import 'package:hermestv/screens/vod_player_screen.dart';
import 'package:hermestv/services/resume_service.dart';
import 'package:hermestv/services/tmdb_image_service.dart';
import 'package:hermestv/services/watchlist_service.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Film detay sayfası: kompakt, tam sayfa scroll edilebilir.
class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movie});

  final VodMovie movie;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().movieDetails(widget.movie.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final movie = widget.movie;
    final details = state.movieDetailsCached(movie.id);

    final backdrop = details?.backdrop ?? movie.poster;
    final rating = details?.rating ?? movie.rating;
    final year = _year(details?.year);
    final genre = details?.genre;
    final plot = details?.plot;
    final duration = details?.duration;
    final playUrl = state.moviePlayUrl(movie.id);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop != null && backdrop.isNotEmpty)
                    Image.network(
                      backdrop,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(context),
                    )
                  else
                    _placeholder(context),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            backgroundColor: theme.colorScheme.surface,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık + puan (kompakt)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          movie.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (rating != null && rating.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 16),
                              const SizedBox(width: 4),
                              Text(rating, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Meta bilgiler (yatay)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (year != null) _metaChip(Icons.calendar_today, year),
                      if (duration != null) _metaChip(Icons.schedule, duration),
                      if (genre != null) _metaChip(Icons.local_movies, genre),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Oynat + Resume + Listeme Ekle
                  if (playUrl != null)
                    _ResumeButton(movie: movie, playUrl: playUrl),
                  const SizedBox(height: 8),
                  _WatchlistButton(
                    id: movie.id,
                    title: movie.name,
                    poster: movie.poster,
                    description: plot,
                    rating: rating,
                    isMovie: true,
                  ),
                  const SizedBox(height: 12),
                  // Yükleniyor
                  if (details == null)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )),
                    ),
                  // Konu (kompakt)
                  if (plot != null && plot.isNotEmpty) ...[
                    Text('Konu', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      plot,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      maxLines: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Kadro (Oyuncular) — Grid layout, TMDB görselli
                  if (details?.cast != null && details!.cast!.isNotEmpty) ...[
                    Text('Oyuncular', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    _CastGrid(
                      cast: details!.cast!,
                      tmdbId: details!.tmdbId,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Yönetmen
                  if (details?.director != null && details!.director!.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.movie_creation_outlined, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Yönetmen: ${details!.director}', style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // YouTube Fragman
                  if (details?.trailer != null && details!.trailer!.isNotEmpty) ...[
                    Text('Fragman', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final url = Uri.parse('https://www.youtube.com/watch?v=${details!.trailer}');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.black,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.network(
                              'https://img.youtube.com/vi/${details!.trailer}/0.jpg',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.black87,
                                child: const Icon(Icons.play_circle_outline, size: 64, color: Colors.white70),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: const Icon(Icons.play_arrow_rounded, size: 48, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _year(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) return null;
    return releaseDate.length >= 4 ? releaseDate.substring(0, 4) : releaseDate;
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie, size: 56, color: colors.primary.withValues(alpha: 0.4)),
      ),
    );
  }
}

// ==================== Resume Butonu ====================

class _ResumeButton extends StatefulWidget {
  const _ResumeButton({required this.movie, required this.playUrl});
  final VodMovie movie;
  final String playUrl;

  @override
  State<_ResumeButton> createState() => _ResumeButtonState();
}

class _ResumeButtonState extends State<_ResumeButton> {
  ResumeRecord? _resumeRecord;

  @override
  void initState() {
    super.initState();
    _loadResume();
  }

  Future<void> _loadResume() async {
    final records = await ResumeService.load();
    if (!mounted) return;
    final match = records.where((r) => r.id == widget.movie.id).firstOrNull;
    if (match != null && !match.isCompleted) {
      setState(() => _resumeRecord = match);
    }
  }

  void _play({Duration? resumeFrom}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VodPlayerScreen(
          url: widget.playUrl,
          title: widget.movie.name,
          mediaId: widget.movie.id,
          poster: widget.movie.poster,
          isMovie: true,
          resumePosition: resumeFrom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resume = _resumeRecord;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _play(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Filmi İzle', style: TextStyle(fontSize: 14)),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
          ),
        ),
        if (resume != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _play(resumeFrom: resume.position),
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: Text(
                'Kaldığın yerden (${resume.positionText} / ${resume.durationText})',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: const BorderSide(color: Colors.amber),
                foregroundColor: Colors.amber,
              ),
            ),
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: resume.progress,
              minHeight: 2,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.amber),
            ),
          ),
        ],
      ],
    );
  }
}

// ==================== Listeme Ekle Butonu ====================

class _WatchlistButton extends StatefulWidget {
  const _WatchlistButton({
    required this.id,
    required this.title,
    this.poster,
    this.description,
    this.rating,
    required this.isMovie,
  });

  final int id;
  final String title;
  final String? poster;
  final String? description;
  final String? rating;
  final bool isMovie;

  @override
  State<_WatchlistButton> createState() => _WatchlistButtonState();
}

class _WatchlistButtonState extends State<_WatchlistButton> {
  bool _inList = false;

  @override
  void initState() {
    super.initState();
    _checkList();
  }

  Future<void> _checkList() async {
    final inList = await WatchlistService.contains(widget.id);
    if (mounted) setState(() => _inList = inList);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _toggleList,
        icon: Icon(
          _inList ? Icons.bookmark : Icons.bookmark_border,
          size: 20,
        ),
        label: Text(_inList ? 'Listemden Çıkar' : 'Listeme Ekle'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(
            color: _inList ? Colors.amber : Theme.of(context).colorScheme.outline,
          ),
          foregroundColor: _inList ? Colors.amber : null,
        ),
      ),
    );
  }

  Future<void> _toggleList() async {
    if (_inList) {
      await WatchlistService.remove(widget.id);
    } else {
      await WatchlistService.add(WatchlistItem(
        id: widget.id,
        title: widget.title,
        poster: widget.poster,
        description: widget.description,
        rating: widget.rating,
        isMovie: widget.isMovie,
        addedAt: DateTime.now(),
      ));
    }
    _checkList();
  }
}

// ==================== Oyuncu Grid ====================

class _CastGrid extends StatefulWidget {
  const _CastGrid({required this.cast, this.tmdbId});
  final String cast;
  final String? tmdbId;

  @override
  State<_CastGrid> createState() => _CastGridState();
}

class _CastGridState extends State<_CastGrid> {
  Map<String, String> _images = {};

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    if (widget.tmdbId == null || widget.tmdbId!.isEmpty) return;
    try {
      final images = await TmdbImageService.fetchCastImages(widget.tmdbId!);
      if (mounted && images.isNotEmpty) setState(() => _images = images);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actors = widget.cast.split(',').take(12).where((a) => a.trim().isNotEmpty).toList();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actors.map((a) {
        final actor = a.trim();
        final imgUrl = _images[actor];

        return SizedBox(
          width: 72,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: imgUrl != null ? NetworkImage(imgUrl) : null,
                child: imgUrl == null
                    ? Text(
                        actor.isNotEmpty ? actor[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 3),
              Text(
                actor,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
