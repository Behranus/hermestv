import 'package:flutter/material.dart';
import 'package:iptv_player/models/vod.dart';
import 'package:iptv_player/screens/vod_player_screen.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:provider/provider.dart';

/// Film detay sayfası: tanıtım görseli, IMDb puanı, açıklama ve oynat.
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
    // Detayları (açıklama, tanıtım, puan) arka planda yükle.
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
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (backdrop != null && backdrop.isNotEmpty)
                    Image.network(
                      backdrop,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(context, movie.name),
                    )
                  else
                    _placeholder(context, movie.name),
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık + puan
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          movie.name,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (rating != null && rating.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                rating,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (year != null || duration != null || genre != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (year != null) _metaChip(theme, Icons.calendar_today, year),
                        if (duration != null) _metaChip(theme, Icons.schedule, duration),
                        if (genre != null) _metaChip(theme, Icons.local_movies, genre),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Oynat
                  if (playUrl != null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VodPlayerScreen(url: playUrl, title: movie.name),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Filmi İzle', style: TextStyle(fontSize: 16)),
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ),
                  const SizedBox(height: 20),
                  if (details == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (plot != null && plot.isNotEmpty) ...[
                    Text('Konu', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(plot, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                  ],
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

  Widget _metaChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context, String name) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.movie, size: 72, color: colors.primary.withValues(alpha: 0.4)),
      ),
    );
  }
}
