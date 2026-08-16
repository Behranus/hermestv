import 'package:flutter/material.dart';
import 'package:iptv_player/screens/movie_detail_screen.dart';
import 'package:iptv_player/screens/series_detail_screen.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:iptv_player/widgets/channel_list.dart';
import 'package:iptv_player/widgets/vod_card.dart';
import 'package:provider/provider.dart';

enum _VodMode { movies, series }

/// VOD ana ekranı: Filmler / Diziler sekmeleri, kategori çipleri ve poster ızgarası.
class VodScreen extends StatefulWidget {
  const VodScreen({super.key, this.onGoToSetup});

  /// VOD yokken "Kurulum" sekmesine geçmek için.
  final VoidCallback? onGoToSetup;

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen> {
  _VodMode _mode = _VodMode.movies;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.hasVod) {
      return Scaffold(
        appBar: AppBar(title: const Text('VOD')),
        body: EmptyState(
          icon: Icons.movie_filter_outlined,
          title: 'VOD için Xtream bağlantısı gerekir',
          subtitle: 'Kurulum sekmesinden Xtream Codes girişi yap, Xtream tabanlı bir '
              'playlist URL\'si (get.php) ekle veya M3U kanalları live/kullanıcı/şifre '
              'adresleri içeriyorsa VOD otomatik açılır.',
          actionLabel: 'Kuruluma git',
          onAction: widget.onGoToSetup,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('VOD'),
        actions: [
          if (state.vodLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              onChanged: state.setVodQuery,
              decoration: InputDecoration(
                hintText: 'Film veya dizi ara…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.vodQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => state.setVodQuery(''),
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(context, state),
    );
  }

  Widget _buildBody(BuildContext context, AppState state) {
    if (state.vodLoading && state.vodMovies.isEmpty && state.vodSeries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.vodError != null && state.vodMovies.isEmpty && state.vodSeries.isEmpty) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'VOD kataloğu yüklenemedi',
        subtitle: state.vodError,
        actionLabel: 'Tekrar dene',
        onAction: state.loadVod,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SegmentedButton<_VodMode>(
            segments: const [
              ButtonSegment(value: _VodMode.movies, label: Text('Filmler'), icon: Icon(Icons.movie)),
              ButtonSegment(value: _VodMode.series, label: Text('Diziler'), icon: Icon(Icons.tv)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: state.vodCategories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (id, name) = state.vodCategories[i];
              final selected = state.selectedVodCategory == id;
              return ChoiceChip(
                label: Text(name),
                selected: selected,
                onSelected: (_) => state.setVodCategory(id),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth;
            // İstenen düzen: bir ekranda 5 sütun × 4 satır = 20 film.
            // Dar ekranlarda (mobil dikey) taşmasın diye sütun azaltılır.
            final columns = wide >= 1100
                ? 5
                : wide >= 800
                    ? 4
                    : wide >= 520
                        ? 3
                        : 2;
            // 4 satırın aynı anda görünmesi için hücre yüksekliğini ekrana
            // göre hesapla (sabit 0.62 yerine) → 20 film bir bakışta.
            final cellW =
                (wide - 24 - 12 * (columns - 1)) / columns;
            final cellH = (constraints.maxHeight - 24 - 12 * 3) / 4;
            final ratio = columns >= 4
                ? cellW / cellH
                : 0.62;
            final grid = GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: ratio,
              ),
              itemCount: _mode == _VodMode.movies
                  ? state.filteredVodMovies.length
                  : state.filteredVodSeries.length,
              itemBuilder: (context, i) {
                if (_mode == _VodMode.movies) {
                  final m = state.filteredVodMovies[i];
                  return VodCard(
                    title: m.name,
                    imageUrl: m.poster,
                    rating: m.rating,
                    autofocus: i == 0,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => MovieDetailScreen(movie: m)),
                    ),
                  );
                }
                final s = state.filteredVodSeries[i];
                return VodCard(
                  title: s.name,
                  imageUrl: s.cover,
                  rating: s.rating,
                  autofocus: i == 0,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: s)),
                  ),
                );
              },
            );

            final empty = _mode == _VodMode.movies
                ? state.filteredVodMovies.isEmpty
                : state.filteredVodSeries.isEmpty;
            if (empty) {
              return const EmptyState(
                icon: Icons.search_off,
                title: 'Sonuç bulunamadı',
                subtitle: 'Arama veya kategori filtresini değiştirmeyi deneyin.',
              );
            }
            return grid;
          }),
        ),
      ],
    );
  }
}
