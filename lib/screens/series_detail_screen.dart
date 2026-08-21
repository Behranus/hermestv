import 'package:flutter/material.dart';
import 'package:hermestv/models/vod.dart';
import 'package:hermestv/screens/vod_player_screen.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:provider/provider.dart';

/// Dizi detay sayfası: tanıtım görseli, açıklama, sezonlar ve bölümler.
class SeriesDetailScreen extends StatefulWidget {
  const SeriesDetailScreen({super.key, required this.series});

  final VodSeries series;

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  int? _selectedSeason;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppState>().seriesInfo(widget.series.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<AppState>();
    final series = widget.series;
    final info = state.seriesInfoCached(series.id);

    final backdrop = (info != null && info.backdrops.isNotEmpty)
        ? info.backdrops.first
        : series.cover;
    final rating = info?.rating ?? series.rating;
    final plot = info?.plot ?? series.plot;
    final genre = info?.genre;
    final year = info?.year;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
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
                      errorBuilder: (_, _, _) => _placeholder(context, series.name),
                    )
                  else
                    _placeholder(context, series.name),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          series.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (rating != null && rating.isNotEmpty)
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
                  ),
                  if (year != null || genre != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (year != null)
                          _chip(Icons.calendar_today, year),
                        if (genre != null)
                          _chip(Icons.local_movies, genre),
                      ],
                    ),
                  ],
                  if (plot != null && plot.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(plot,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      maxLines: 6, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          if (info == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (info.seasons.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Bu dizi için bölüm bulunamadı.')),
              ),
            )
          else ...[
            // Sezon seçici
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: info.seasons.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final season = info.seasons[i];
                    final selected = _selectedSeason == season.number ||
                        (_selectedSeason == null && i == 0);
                    return ChoiceChip(
                      label: Text('Sezon ${season.number}'),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedSeason = season.number),
                    );
                  },
                ),
              ),
            ),
            SliverList.separated(
              itemCount: _episodes(info).length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final ep = _episodes(info)[i];
                final url = state.episodePlayUrl(
                  ep.id,
                  containerExtension: ep.containerExtension,
                );
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 40,
                      child: ep.cover != null && ep.cover!.isNotEmpty
                          ? Image.network(
                              ep.cover!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _thumbFallback(context, ep),
                            )
                          : _thumbFallback(context, ep),
                    ),
                  ),
                  title: Text(
                    '${ep.displayNumber}. ${ep.title.isEmpty ? 'Bölüm' : ep.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (ep.duration != null && ep.duration!.isNotEmpty) ep.duration!,
                      if (ep.airDate != null && ep.airDate!.isNotEmpty) ep.airDate!,
                    ].join(' • '),
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: url != null
                      ? const Icon(Icons.play_circle_outline)
                      : null,
                  onTap: url == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VodPlayerScreen(
                                url: url,
                                title: 'S${ep.season}E${ep.displayNumber} — ${ep.title.isEmpty ? series.name : ep.title}',
                              ),
                            ),
                          ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  List<VodEpisode> _episodes(SeriesInfo info) {
    if (info.seasons.isEmpty) return const [];
    for (final s in info.seasons) {
      if (_selectedSeason == null && s == info.seasons.first) return s.episodes;
      if (s.number == _selectedSeason) return s.episodes;
    }
    return info.seasons.first.episodes;
  }

  Widget _chip(IconData icon, String label) {
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

  Widget _thumbFallback(BuildContext context, VodEpisode ep) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Text(
          ep.displayNumber,
          style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context, String name) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.tv, size: 72, color: colors.primary.withValues(alpha: 0.4)),
      ),
    );
  }
}
