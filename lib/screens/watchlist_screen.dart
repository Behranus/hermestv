import 'package:flutter/material.dart';
import 'package:hermestv/models/vod.dart';
import 'package:hermestv/screens/movie_detail_screen.dart';
import 'package:hermestv/screens/series_detail_screen.dart';
import 'package:hermestv/services/watchlist_service.dart';

/// Kişisel izleme listesi ekranı (My List).
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

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('Liste boş', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'İzlemek istediğin filmleri ve dizileri buraya ekle',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _WatchlistTile(
          item: item,
          onTap: () => _openItem(item),
          onRemove: () async {
            await WatchlistService.remove(item.id);
            _load();
          },
        );
      },
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

class _WatchlistTile extends StatelessWidget {
  const _WatchlistTile({
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
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
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      item.isMovie ? Icons.movie : Icons.tv,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: 80,
                height: 120,
                child: Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(
                    item.isMovie ? Icons.movie : Icons.tv,
                    color: theme.colorScheme.outline,
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
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.bookmark_remove, size: 20),
                          onPressed: onRemove,
                          tooltip: 'Listeden çıkar',
                        ),
                      ],
                    ),
                    if (item.rating != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber[600]),
                          const SizedBox(width: 4),
                          Text(item.rating!, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      item.isMovie ? 'Film' : 'Dizi',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
