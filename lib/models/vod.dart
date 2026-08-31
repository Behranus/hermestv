/// Xtream Codes VOD kataloğundaki bir film.
class VodMovie {
  const VodMovie({
    required this.id,
    required this.name,
    this.poster,
    this.rating,
    this.categoryId,
    this.directUrl,
    this.containerExtension,
    // YTS destekli alanlar
    this.streamUrl,
    this.plot,
    this.backdrop,
    this.year,
    this.genre,
    this.duration,
    this.actors,
    this.director,
    this.extra,
  });

  final dynamic id;
  final String name;

  /// Poster/tanıtım görseli (stream_icon).
  final String? poster;

  /// IMDb tarzı puan (0-10).
  final String? rating;
  final String? categoryId;

  /// Xtream dışı doğrudan oynatma adresi (test kataloğu gibi).
  final String? directUrl;

  /// Sunucunun bildirdiği dosya uzantısı.
  final String? containerExtension;

  // YTS destekli alanlar
  final String? streamUrl;   // Magnet link veya oynatma URL'si
  final String? plot;        // Film konusu
  final String? backdrop;    // Arka plan görseli
  final String? year;        // Yapım yılı
  final String? genre;       // Tür
  final String? duration;    // Süre
  final String? actors;      // Oyuncular
  final String? director;    // Yönetmen
  final Map<String, dynamic>? extra;  // Ek bilgiler (magnet links, torrent details)

  factory VodMovie.fromJson(Map<String, dynamic> json) {
    final rating = json['rating']?.toString();
    return VodMovie(
      id: int.tryParse(json['stream_id']?.toString() ?? '') ?? 0,
      name: (json['name']?.toString() ?? '').trim(),
      poster: _nonEmpty(json['stream_icon']),
      rating: (rating == null || rating.isEmpty || rating == '0') ? null : rating,
      categoryId: json['category_id']?.toString(),
      directUrl: _nonEmpty(json['direct_source']),
      containerExtension: _nonEmpty(json['container_extension']),
    );
  }
}

/// Xtream Codes VOD kataloğundaki bir dizi.
class VodSeries {
  const VodSeries({
    required this.id,
    required this.name,
    this.cover,
    this.rating,
    this.plot,
    this.categoryId,
  });

  final int id;
  final String name;
  final String? cover;
  final String? rating;
  final String? plot;
  final String? categoryId;

  factory VodSeries.fromJson(Map<String, dynamic> json) {
    final rating = json['rating']?.toString();
    return VodSeries(
      id: int.tryParse(json['series_id']?.toString() ?? '') ?? 0,
      name: (json['name']?.toString() ?? '').trim(),
      cover: _nonEmpty(json['cover']) ?? _firstOf(json['backdrop_path']),
      rating: (rating == null || rating.isEmpty || rating == '0') ? null : rating,
      plot: _nonEmpty(json['plot']),
      categoryId: json['category_id']?.toString(),
    );
  }
}

/// Film detayları (`get_vod_info`).
class VodMovieDetails {
  const VodMovieDetails({
    this.plot,
    this.backdrop,
    this.genre,
    this.year,
    this.duration,
    this.rating,
    this.tmdbId,
    this.trailer,
    this.cast,
    this.director,
  });

  final String? plot;
  final String? backdrop;
  final String? genre;
  final String? year;
  final String? duration;
  final String? rating;
  final String? tmdbId;
  final String? trailer;
  final String? cast;
  final String? director;

  factory VodMovieDetails.fromJson(Map<String, dynamic> json) {
    final info = json['info'];
    if (info is! Map<String, dynamic>) {
      return const VodMovieDetails();
    }
    return VodMovieDetails(
      plot: _nonEmpty(info['plot']),
      backdrop: _firstOf(info['backdrop_path']) ?? _nonEmpty(info['backdrop_path']),
      genre: _nonEmpty(info['genre']),
      year: _nonEmpty(info['release_date']),
      duration: _nonEmpty(info['duration']),
      rating: _nonEmpty(info['rating']),
      tmdbId: _nonEmpty(info['tmdb_id']),
      trailer: _nonEmpty(info['youtube_trailer']),
      cast: _nonEmpty(info['cast']),
      director: _nonEmpty(info['director']),
    );
  }
}

/// Dizi detayları + sezonlar (`get_series_info`).
class SeriesInfo {
  const SeriesInfo({
    required this.seasons,
    this.plot,
    this.genre,
    this.year,
    this.rating,
    this.cast,
    this.director,
    this.backdrops = const [],
  });

  final List<VodSeason> seasons;
  final String? plot;
  final String? genre;
  final String? year;
  final String? rating;
  final String? cast;
  final String? director;
  final List<String> backdrops;

  factory SeriesInfo.fromJson(Map<String, dynamic> json) {
    final info = json['info'];
    final seasons = <VodSeason>[];

    // Xtream API: bölümler sezonların İÇİNDE değil, ayrı bir
    // "episodes" sözlüğünde tutulur: {"1": [{...}, ...], "2": [...]}.
    final allEpisodes = json['episodes'];
    final Map<String, List<VodEpisode>> episodesBySeason = {};
    if (allEpisodes is Map) {
      for (final entry in allEpisodes.entries) {
        final seasonKey = entry.key;
        final rawList = entry.value;
        if (rawList is! List) continue;
        final episodes = <VodEpisode>[];
        final seasonNum = int.tryParse(seasonKey) ?? 0;
        for (final e in rawList) {
          if (e is! Map<String, dynamic>) continue;
          final epInfo = e['info'];
          final infoMap = epInfo is Map<String, dynamic> ? epInfo : null;
          episodes.add(VodEpisode(
            id: int.tryParse(e['id']?.toString() ?? '') ?? 0,
            title: (e['title']?.toString() ?? '').trim(),
            season: seasonNum,
            episodeNum: e['episode_num']?.toString(),
            plot: infoMap?['plot'] != null
                ? infoMap!['plot'].toString()
                : (e['plot']?.toString()),
            cover: _nonEmpty(e['cover']),
            duration: infoMap?['duration']?.toString(),
            airDate: infoMap?['release_date']?.toString(),
            containerExtension: _nonEmpty(e['container_extension']),
          ));
        }
        episodesBySeason[seasonKey] = episodes;
      }
    }

    final rawSeasons = json['seasons'];
    if (rawSeasons is List) {
      for (final s in rawSeasons) {
        if (s is! Map<String, dynamic>) continue;
        final numRaw = s['season_number']?.toString() ?? s['season']?.toString() ?? '1';
        final number = int.tryParse(numRaw) ?? 1;
        // 1) Ayrı sözlükten çek (Xtream API formatı).
        var episodes = episodesBySeason[numRaw.toString()] ??
            episodesBySeason[number.toString()];
        // 2) Yedek: sezonun içindeki 'episodes' alanından çek (eski/test formatı).
        if (episodes == null && s['episodes'] is List) {
          episodes = [];
          for (final e in (s['episodes'] as List)) {
            if (e is! Map<String, dynamic>) continue;
            final epInfo = e['info'];
            final infoMap = epInfo is Map<String, dynamic> ? epInfo : null;
            episodes.add(VodEpisode(
              id: int.tryParse(e['id']?.toString() ?? '') ?? 0,
              title: (e['title']?.toString() ?? '').trim(),
              season: number,
              episodeNum: e['episode_num']?.toString(),
              plot: infoMap?['plot']?.toString() ?? e['plot']?.toString(),
              cover: _nonEmpty(e['cover']),
              duration: infoMap?['duration']?.toString(),
              airDate: infoMap?['release_date']?.toString(),
              containerExtension: _nonEmpty(e['container_extension']),
            ));
          }
        }
        seasons.add(VodSeason(number: number, name: s['name']?.toString(), episodes: episodes ?? const <VodEpisode>[]));
      }
      seasons.sort((a, b) => a.number.compareTo(b.number));
    }

    String? year;
    if (info is Map<String, dynamic>) {
      final rd = _nonEmpty(info['releaseDate']) ?? _nonEmpty(info['release_date']);
      if (rd != null && rd.length >= 4) year = rd.substring(0, 4);
    }

    return SeriesInfo(
      seasons: seasons,
      plot: info is Map<String, dynamic> ? _nonEmpty(info['plot']) : null,
      genre: info is Map<String, dynamic> ? _nonEmpty(info['genre']) : null,
      year: year,
      rating: info is Map<String, dynamic> ? _nonEmpty(info['rating']) : null,
      cast: info is Map<String, dynamic> ? _nonEmpty(info['cast']) : null,
      director: info is Map<String, dynamic> ? _nonEmpty(info['director']) : null,
      backdrops: info is Map<String, dynamic>
          ? (info['backdrop_path'] is List
              ? (info['backdrop_path'] as List)
                  .whereType<String>()
                  .where((s) => s.isNotEmpty)
                  .toList()
              : const <String>[])
          : const [],
    );
  }
}

class VodSeason {
  const VodSeason({required this.number, this.name, required this.episodes});

  final int number;
  final String? name;
  final List<VodEpisode> episodes;
}

class VodEpisode {
  const VodEpisode({
    required this.id,
    required this.title,
    required this.season,
    this.episodeNum,
    this.plot,
    this.cover,
    this.duration,
    this.airDate,
    this.containerExtension,
  });

  final int id;
  final String title;
  final int season;
  final String? episodeNum;
  final String? plot;
  final String? cover;
  final String? duration;
  final String? airDate;

  /// Bölümün dosya uzantısı (ör. "mp4", "mkv") — oynatma adresi buna göre
  /// kurulur. Boşsa m3u8 varsayılır.
  final String? containerExtension;

  String get displayNumber {
    final n = episodeNum;
    if (n != null && n.isNotEmpty) {
      final parsed = int.tryParse(n);
      return parsed != null ? '$parsed' : n;
    }
    return id.toString();
  }
}

String? _nonEmpty(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String? _firstOf(Object? v) {
  if (v is List && v.isNotEmpty) {
    return _nonEmpty(v.first);
  }
  return null;
}
