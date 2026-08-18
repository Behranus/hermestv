import 'package:flutter/material.dart';
import 'package:iptv_player/models/vod.dart';
import 'package:iptv_player/screens/vod_player_screen.dart';
import 'package:iptv_player/services/resume_service.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:provider/provider.dart';

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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
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
              padding: const EdgeInsets.all(12),
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
                  // Oynat + Resume
                  if (playUrl != null)
                    _ResumeButton(movie: movie, playUrl: playUrl),
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
                  const SizedBox(height: 24),
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
