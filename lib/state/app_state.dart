import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/epg_program.dart';
import 'package:iptv_player/models/vod.dart';
import 'package:iptv_player/services/channel_probe_service.dart';
import 'package:iptv_player/services/epg_service.dart';
import 'package:iptv_player/services/favorites_service.dart';
import 'package:iptv_player/services/playlist_service.dart';
import 'package:iptv_player/services/test_server_service.dart';
import 'package:iptv_player/services/test_vod_catalog.dart';
import 'package:iptv_player/services/xtream_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Kaynak test bölümünden mi yüklendi? (sunucu VOD'suzsa yerleşik
  /// yasal test VOD kataloğu devreye girer)
  bool _testSource = false;

  // Ücretsiz/test kanallarının canlılık doğrulaması (günlük yenileme)
  bool testProbeActive = false;
  int testProbeDone = 0;
  int testProbeTotal = 0;

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

  /// VOD kataloğu, Xtream bilgileri elde edilebildiğinde — veya test kaynağında
  /// yerleşik yasal test kataloğu yüklendiğinde — kullanılabilir.
  bool get hasVod =>
      _creds != null || vodMovies.isNotEmpty || vodSeries.isNotEmpty;

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
    _testSource = s.isTest;
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
        // Test kaynağı: kanalları doğrula (yalnızca açılanlar listelensin —
        // günde bir kez; önbellekli). Ölü kanallar hem "açılmıyor" hissi
        // yaratır hem de 2GB RAM'de gereksiz bellek harcar.
        if (_testSource) {
          await _verifyTestChannels(creds);
        }
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

  /// Test yayınlarını yükler.
  ///
  /// Önce internetten Xtream test sunucu havuzu tazelenir (her gün + kullanıcı
  /// her bastığında). Çalışan en iyi sunucu varsa canlı + VOD ile yüklenir;
  /// yoksa doğrudan HLS test yayınlarına düşülür.
  Future<void> loadTest() async {
    List<TestServer> servers;
    try {
      servers = await TestServerService.refresh(force: true);
    } catch (_) {
      servers = const [];
    }
    final best = servers.where((s) => s.working && s.liveCount > 0).firstOrNull;
    if (best != null) {
      await loginXtream(
        server: best.server,
        username: best.username,
        password: best.password,
        isTest: true,
      );
      return;
    }
    // Xtream sunucusu yoksa doğrudan HLS test yayınlarına düş.
    await loadFromSource(
      const PlaylistSource(PlaylistSourceType.demo, '', isTest: true),
    );
  }

  /// Xtream hesabına giriş yapar; canlı kanalları ve VOD kataloğunu yükler.
  Future<void> loginXtream({
    required String server,
    required String username,
    required String password,
    bool isTest = false,
  }) async {
    final creds = XtreamCredentials(
      server: server,
      username: username,
      password: password,
    );
    // Önce girişi doğrula.
    await XtreamService.login(creds);
    await loadFromSource(
      PlaylistSource(
        PlaylistSourceType.xtream,
        jsonEncode(creds.toJson()),
        isTest: isTest,
      ),
    );
    // VOD kataloğunu ayrıca yükle (hata olursa kanallar yine de açık kalır).
    await loadVod();
  }

  /// Test kaynağının kanallarını doğrular: yalnızca o an açılabilenleri
  /// listede tutar. Sonuç **günde bir kez** yeniden doğrulanır (önbellek).
  Future<void> _verifyTestChannels(XtreamCredentials creds) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'test_channels_'
        '${creds.server.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final tsKey = '${key}_ts';

    // 24 saat içinde doğrulandıysa önbelleği kullan — günlük yenileme.
    final lastRaw = prefs.getString(tsKey);
    if (lastRaw != null) {
      final last = DateTime.tryParse(lastRaw);
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 24)) {
        final cached = prefs.getString(key);
        if (cached != null) {
          final cachedChannels = ChannelProbeService.decode(cached);
          if (cachedChannels.isNotEmpty) {
            _channels = cachedChannels;
            notifyListeners();
            return;
          }
        }
      }
    }

    // Taze doğrulama (ilerleme çubuğu için alanlar güncellenir).
    final toProbe = List<Channel>.of(_channels);
    testProbeActive = true;
    testProbeDone = 0;
    testProbeTotal = toProbe.length;
    notifyListeners();
    final alive = await ChannelProbeService.probeAlive(
      toProbe,
      onProgress: (d, t) {
        testProbeDone = d;
        testProbeTotal = t;
        notifyListeners();
      },
    );
    testProbeActive = false;
    if (alive.isNotEmpty) {
      _channels = alive;
      await prefs.setString(key, ChannelProbeService.encode(alive));
      await prefs.setString(tsKey, DateTime.now().toIso8601String());
    }
    notifyListeners();
  }

  Future<void> clearPlaylist() async {
    _channels = [];
    source = null;
    _derivedCreds = null;
    _testSource = false;
    testProbeActive = false;
    testProbeDone = 0;
    testProbeTotal = 0;
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

  /// Yerleşik yasal test VOD kataloğunu yükler (Xtream gerekmez).
  void _loadDemoVod() {
    vodMovies = TestVodCatalog.items
        .map((d) => VodMovie(
              id: d.id,
              name: d.name,
              poster: d.poster,
              rating: d.rating,
              categoryId: 'demo',
              directUrl: d.url,
            ))
        .toList();
    vodSeries = [];
    vodCategories = [('all', 'Tümü'), ('demo', 'Test Filmleri')];
    selectedVodCategory = 'all';
    vodError = null;
  }

  /// VOD kategorilerini, filmleri ve dizileri yükler.
  ///
  /// Test kaynağıysa: sunucunun VOD'u varsa onu kullanır; yoksa (çoğu test
  /// sunucusu VOD sunmaz) yerleşik yasal test kataloğu devreye girer.
  Future<void> loadVod() async {
    final creds = _creds;
    if (creds == null) {
      if (_testSource) _loadDemoVod();
      return;
    }
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
      // Test kaynağı ve sunucu VOD sunmuyor → yerleşik yasal test kataloğu.
      if (_testSource && vodMovies.isEmpty && vodSeries.isEmpty) {
        _loadDemoVod();
      }
    } catch (e) {
      vodError = e.toString();
      if (_testSource) _loadDemoVod();
    } finally {
      vodLoading = false;
      notifyListeners();
    }
  }

  /// Film detaylarını (önce önbellekten) getirir.
  Future<VodMovieDetails?> movieDetails(int movieId) async {
    final cached = _vodDetailsCache[movieId];
    if (cached != null) return cached;
    // Yerleşik test kataloğu filmi mi?
    final demo = TestVodCatalog.byId(movieId);
    if (demo != null) {
      final details = VodMovieDetails(
        plot: demo.plot,
        backdrop: demo.poster,
        genre: demo.genre,
        year: demo.year,
        duration: demo.duration,
        rating: demo.rating,
      );
      _vodDetailsCache[movieId] = details;
      notifyListeners();
      return details;
    }
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

  /// Filmin oynatma adresi. Yerleşik test kataloğu filmi için doğrudan
  /// adres döner; diğerleri için Xtream adresi (hesap yoksa null).
  String? moviePlayUrl(int movieId) {
    final demo = TestVodCatalog.byId(movieId);
    if (demo != null) return demo.url;
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
