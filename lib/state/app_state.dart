import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/epg_program.dart';
import 'package:iptv_player/models/vod.dart';
import 'package:iptv_player/services/epg_service.dart';
import 'package:iptv_player/services/favorites_service.dart';
import 'package:iptv_player/services/playlist_service.dart';
import 'package:iptv_player/services/xtream_service.dart';

/// Uygulamanın merkezi durumu: playlist, gruplar, arama, favoriler, EPG.
class AppState extends ChangeNotifier {
  PlaylistSource? source;
  List<Channel> _channels = [];
  bool isLoading = false;
  String? error;

  Set<String> _favorites = {};
  String selectedGroup = 'all';
  String query = '';
  Channel? lastPlayed;

  // EPG
  EpgData? epg;
  bool epgLoading = false;
  String? epgError;
  String? epgUrl;

  /// Xtream olmayan kaynaklardan (URL/dosya/test) türetilen kimlik bilgileri.
  /// Örn. M3U kanalları `live/kullanıcı/şifre/…` adresleri içeriyorsa,
  /// aynı bilgilerle VOD kataloğu da açılabilir.
  XtreamCredentials? _derivedCreds;

  // VOD (Xtream)
  List<VodMovie> vodMovies = [];
  List<VodSeries> vodSeries = [];
  List<(String, String)> vodCategories = [];
  String selectedVodCategory = 'all';
  String vodQuery = '';
  bool vodLoading = false;
  String? vodError;
  final Map<int, VodMovieDetails> _vodDetailsCache = {};
  final Map<int, SeriesInfo> _seriesInfoCache = {};

  List<Channel> get channels => List.unmodifiable(_channels);

  /// Benzersiz, sıralı grup listesi.
  List<String> get groups {
    final g = <String>{};
    for (final c in _channels) {
      g.add(c.displayGroup);
    }
    final list = g.toList()..sort();
    return ['all', ...list];
  }

  bool get hasChannels => _channels.isNotEmpty;

  /// VOD kataloğu, Xtream bilgileri elde edilebildiğinde kullanılabilir:
  /// doğrudan Xtream girişi, Xtream tabanlı playlist URL'si (get.php),
  /// veya M3U kanallarının içine gömülü `live/kullanıcı/şifre` adresleri.
  bool get hasVod => _creds != null;

  bool isFavorite(Channel c) => _favorites.contains(c.url);

  /// Seçili gruba ve arama sorgusuna göre filtrelenmiş kanallar.
  List<Channel> get filteredChannels {
    var list = _channels;
    if (selectedGroup != 'all') {
      list = list.where((c) => c.displayGroup == selectedGroup).toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<Channel> get favoriteChannels =>
      _channels.where((c) => _favorites.contains(c.url)).toList();

  /// Uygulama açılışında kaydedilmiş kaynağı yükler.
  Future<void> init() async {
    _favorites = await FavoritesService.load();
    notifyListeners();
    final saved = await PlaylistService.restoreSource();
    if (saved != null) {
      await loadFromSource(saved);
    }
  }

  Future<void> loadFromSource(PlaylistSource s) async {
    isLoading = true;
    error = null;
    _derivedCreds = null;
    source = s;
    selectedGroup = 'all';
    query = '';
    notifyListeners();
    try {
      // URL alanına Xtream linki (get.php / player_api.php) yapıştırılmışsa
      // otomatik olarak Xtream girişi gibi davran: canlı + VOD + EPG yüklenir.
      if (s.type == PlaylistSourceType.url) {
        final xtreamFromUrl = XtreamService.tryParsePlaylistUrl(s.value);
        if (xtreamFromUrl != null) {
          s = PlaylistSource(
            PlaylistSourceType.xtream,
            jsonEncode(xtreamFromUrl.toJson()),
          );
          source = s;
        }
      }

      if (s.type == PlaylistSourceType.xtream) {
        final creds = XtreamCredentials.fromJson(
          jsonDecode(s.value) as Map<String, dynamic>,
        );
        if (creds == null) throw const FormatException('Xtream bilgileri eksik.');
        _channels = await XtreamService.loadLiveChannels(creds);
        await PlaylistService.saveSource(s);
        // Xtream portalı EPG'sini otomatik yüklemeyi dene (başarısızlık önemli değil).
        await _loadEpg(XtreamService.epgUrl(creds), silent: true);
        // VOD kataloğunu yükle (hata olursa kanallar yine de açık kalır).
        await _tryLoadVod();
      } else {
        _channels = await PlaylistService.load(s);
        await PlaylistService.saveSource(s);
        // M3U kanallarının içine gömülü Xtream adreslerini ara.
        // Bulunursa VOD kataloğu ve EPG de otomatik açılır.
        _derivedCreds = XtreamService.tryFromChannelUrls(_channels);
        if (_derivedCreds != null) {
          await _tryLoadVod();
          await _loadEpg(XtreamService.epgUrl(_derivedCreds!), silent: true);
        }
      }
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFromUrl(String url) =>
      loadFromSource(PlaylistSource(PlaylistSourceType.url, url.trim()));

  Future<void> loadFromFile(String path) =>
      loadFromSource(PlaylistSource(PlaylistSourceType.file, path));

  /// İnternetteki halka açık test yayınlarını yükler.
  Future<void> loadTest() =>
      loadFromSource(const PlaylistSource(PlaylistSourceType.demo, ''));

  /// Xtream hesabına giriş yapar; canlı kanalları ve VOD kataloğunu yükler.
  Future<void> loginXtream({
    required String server,
    required String username,
    required String password,
  }) async {
    final creds = XtreamCredentials(
      server: server,
      username: username,
      password: password,
    );
    // Önce girişi doğrula.
    await XtreamService.login(creds);
    await loadFromSource(PlaylistSource(
      PlaylistSourceType.xtream,
      jsonEncode(creds.toJson()),
    ));
    // VOD kataloğunu ayrıca yükle (hata olursa kanallar yine de açık kalır).
    await loadVod();
  }

  Future<void> clearPlaylist() async {
    _channels = [];
    source = null;
    _derivedCreds = null;
    error = null;
    selectedGroup = 'all';
    query = '';
    epg = null;
    epgUrl = null;
    epgError = null;
    vodMovies = [];
    vodSeries = [];
    vodCategories = [];
    selectedVodCategory = 'all';
    vodQuery = '';
    vodError = null;
    _vodDetailsCache.clear();
    _seriesInfoCache.clear();
    await PlaylistService.clearSource();
    notifyListeners();
  }

  // ---- EPG ----

  Future<void> loadEpg(String url) => _loadEpg(url, silent: false);

  Future<void> _loadEpg(String url, {required bool silent}) async {
    epgLoading = true;
    epgError = null;
    epgUrl = url;
    notifyListeners();
    try {
      epg = await EpgService.load(url);
    } catch (e) {
      epgError = e.toString();
      if (!silent) notifyListeners();
    } finally {
      epgLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearEpg() async {
    epg = null;
    epgUrl = null;
    epgError = null;
    notifyListeners();
  }

  /// Kanalın şu an yayınlanan programı (EPG varsa).
  EpgProgram? nowPlaying(Channel c) =>
      epg?.nowPlaying(tvgId: c.tvgId, name: c.name);

  /// Kanalın sıradaki programı (EPG varsa).
  EpgProgram? nextProgram(Channel c) => epg?.next(tvgId: c.tvgId, name: c.name);

  /// Kanalın tüm program çizelgesi (EPG varsa).
  List<EpgProgram>? schedule(Channel c) =>
      epg?.forChannel(tvgId: c.tvgId, name: c.name);

  // ---- VOD ----

  XtreamCredentials? get _creds {
    // Doğrudan Xtream kaynağı varsa onun bilgilerini kullan.
    if (source?.type == PlaylistSourceType.xtream) {
      try {
        final c = XtreamCredentials.fromJson(
          jsonDecode(source!.value) as Map<String, dynamic>,
        );
        if (c != null) return c;
      } catch (_) {
        // Geçersiz kayıt — türetilmiş bilgilere düş.
      }
    }
    // M3U kanallarından türetilen Xtream bilgileri (URL/dosya/test kaynakları).
    return _derivedCreds;
  }

  /// VOD'u sessizce yüklemeyi dener; hata olursa yalnızca vodError'a yazar.
  Future<void> _tryLoadVod() async {
    try {
      await loadVod();
    } catch (_) {
      // VOD yüklenemezse canlı kanallar yine de kullanılabilir.
    }
  }

  /// VOD kategorilerini, filmleri ve dizileri yükler.
  Future<void> loadVod() async {
    final creds = _creds;
    if (creds == null) return;
    vodLoading = true;
    vodError = null;
    notifyListeners();
    try {
      final cats = await XtreamService.loadVodCategories(creds);
      final movies = await XtreamService.loadVodMovies(creds);
      final series = await XtreamService.loadSeries(creds);
      vodCategories = [('all', 'Tümü'), ...cats.entries.map((e) => (e.key, e.value))];
      vodMovies = movies;
      vodSeries = series;
      _vodDetailsCache.clear();
    } catch (e) {
      vodError = e.toString();
    } finally {
      vodLoading = false;
      notifyListeners();
    }
  }

  /// Film detaylarını (önce önbellekten) getirir.
  Future<VodMovieDetails?> movieDetails(int movieId) async {
    final cached = _vodDetailsCache[movieId];
    if (cached != null) return cached;
    final creds = _creds;
    if (creds == null) return null;
    try {
      final details = await XtreamService.loadVodMovieDetails(creds, movieId);
      _vodDetailsCache[movieId] = details;
      notifyListeners();
      return details;
    } catch (_) {
      return null;
    }
  }

  VodMovieDetails? movieDetailsCached(int movieId) => _vodDetailsCache[movieId];

  /// Filmin oynatma adresi (Xtream hesabı yoksa null).
  String? moviePlayUrl(int movieId) {
    final creds = _creds;
    return creds == null ? null : XtreamService.movieUrl(creds, movieId);
  }

  /// Dizi detaylarını (sezonlar + bölümler) önbellekle getirir.
  Future<SeriesInfo?> seriesInfo(int seriesId) async {
    final cached = _seriesInfoCache[seriesId];
    if (cached != null) return cached;
    final creds = _creds;
    if (creds == null) return null;
    try {
      final info = await XtreamService.loadSeriesInfo(creds, seriesId);
      _seriesInfoCache[seriesId] = info;
      notifyListeners();
      return info;
    } catch (_) {
      return null;
    }
  }

  SeriesInfo? seriesInfoCached(int seriesId) => _seriesInfoCache[seriesId];

  /// Bölümün oynatma adresi (Xtream hesabı yoksa null).
  String? episodePlayUrl(int episodeId) {
    final creds = _creds;
    return creds == null ? null : XtreamService.episodeUrl(creds, episodeId);
  }

  String? get vodCategoryName => vodCategories
      .where((c) => c.$1 == selectedVodCategory)
      .map((c) => c.$2)
      .firstOrNull;

  List<VodMovie> get filteredVodMovies {
    var list = vodMovies;
    if (selectedVodCategory != 'all') {
      list = list.where((m) => m.categoryId == selectedVodCategory).toList();
    }
    final q = vodQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) => m.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  List<VodSeries> get filteredVodSeries {
    var list = vodSeries;
    if (selectedVodCategory != 'all') {
      list = list.where((s) => s.categoryId == selectedVodCategory).toList();
    }
    final q = vodQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((s) => s.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void setVodCategory(String id) {
    selectedVodCategory = id;
    notifyListeners();
  }

  void setVodQuery(String q) {
    vodQuery = q;
    notifyListeners();
  }

  // ---- Favoriler ----

  Future<void> toggleFavorite(Channel c) async {
    if (!_favorites.remove(c.url)) {
      _favorites.add(c.url);
    }
    await FavoritesService.save(_favorites);
    notifyListeners();
  }

  void setGroup(String group) {
    selectedGroup = group;
    notifyListeners();
  }

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void setLastPlayed(Channel c) {
    lastPlayed = c;
    notifyListeners();
  }
}
