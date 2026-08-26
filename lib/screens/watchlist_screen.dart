import 'package:flutter/material.dart';
import 'package:hermestv/models/vod.dart';
import 'package:hermestv/screens/movie_detail_screen.dart';
import 'package:hermestv/screens/series_detail_screen.dart';
import 'package:hermestv/services/watchlist_service.dart';

/// Kisisel izleme listesi ekrani - modern Zorin OS tema
class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<WatchlistItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await WatchlistService.load();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Ust bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.bookmark_rounded, color: Color(0xFF6C5CE7), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Listem',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_items.length} icerik',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),

          // Icerik
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_border_rounded,
                            size: 72, color: colors.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('Liste bos',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 8),
                        Text(
                          'Izlemek istedigin filmleri ve dizileri\nburaya ekleyebilirsin.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _WatchlistCard(
                        item: item,
                        onTap: () => _openItem(item),
                        onRemove: () async {
                          await WatchlistService.remove(item.id);
                          _load();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openItem(WatchlistItem item) {
    if (item.isMovie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailScreen(
            movie: VodMovie(
              id: item.id,
              name: item.title,
              poster: item.poster,
              rating: item.rating,
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
            series: VodSeries(
              id: item.id,
              name: item.title,
              cover: item.poster,
              rating: item.rating,
            ),
          ),
        ),
      );
    }
  }
}

class _WatchlistCard extends StatelessWidget {
  const _WatchlistCard({
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final WatchlistItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Row(
              children: [
                // Poster
                if (item.poster != null)
                  SizedBox(
                    width: 80,
                    height: 120,
                    child: Image.network(
                      item.poster!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: colors.surface,
                        child: Icon(
                          item.isMovie ? Icons.movie_rounded : Icons.tv,
                          color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: 80,
                    height: 120,
                    child: Container(
                      color: colors.surface,
                      child: Icon(
                        item.isMovie ? Icons.movie_rounded : Icons.tv,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),

                // Bilgiler
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: onRemove,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.bookmark_remove_rounded,
                                  size: 20,
                                  color: colors.error.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.rating != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star_rounded,
                                  size: 14, color: const Color(0xFFF5A623)),
                              const SizedBox(width: 4),
                              Text(item.rating!,
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ],
                        if (item.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.description!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (item.isMovie
                                    ? colors.primary
                                    : const Color(0xFF6C5CE7))
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.isMovie ? 'Film' : 'Dizi',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: item.isMovie
                                  ? colors.primary
                                  : const Color(0xFF6C5CE7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
