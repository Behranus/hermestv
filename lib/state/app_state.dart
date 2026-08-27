import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/models/epg_program.dart';
import 'package:hermestv/models/vod.dart';
import 'package:hermestv/services/channel_probe_service.dart';
import 'package:hermestv/services/epg_service.dart';
import 'package:hermestv/services/favorites_service.dart';
import 'package:hermestv/services/free_tv_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hermestv/services/playlist_service.dart';
import 'package:hermestv/services/test_server_service.dart';
import 'package:hermestv/services/test_vod_catalog.dart';
import 'package:hermestv/services/xtream_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermestv/services/settings_service.dart';

/// Uygulamanın merkezi durumu: playlist, gruplar, arama, favoriler, EPG.
class AppState extends ChangeNotifier {
  PlaylistSource? source;
  List<Channel> _channels = [];
  bool isLoading = false;
  String? error;
  bool _showAdultContent = false;
  bool get showAdultContent => _showAdultContent;

  // Çoklu IPTV kaynağı (TiviMate tarzı)
  List<PlaylistSource> _allSources = [];
  int _activeSourceIndex = 0;
  List<PlaylistSource> get allSources => List.unmodifiable(_allSources);
  int get activeSourceIndex => _activeSourceIndex;

  /// Devasa listelerin (iptv-org) kademeli ayrıştırmasındaki ilerleme.
  int loadProgress = 0;
  int loadTotal = 0;

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

  /// Gruplar: Türkçe en başta, Kürtçe ikinci, sonra alfabetik.
  List<String> get sortedGroups {
    final list = groups.where((g) => g != 'all').toList();
    final trGroups = <String>[];
    final kurdGroups = <String>[];
    final otherGroups = <String>[];
    for (final g in list) {
      final upper = g.toUpperCase();
      if (upper.startsWith('TR') || upper.contains('TURK') ||
          upper.contains('TÜRK') || upper.contains('ULUSAL') ||
          upper.contains('HABER') || upper.contains('SPOR') ||
          upper.contains('BELGESEL') || upper.contains('SİNEMA') ||
          upper.contains('MÜZİK') || upper.contains('EĞLENCE') ||
          upper.contains('ÇOCUK')) {
        trGroups.add(g);
      } else if (upper.contains('KÜRT') || upper.contains('KURD') ||
                 g.startsWith('🟩')) {
        kurdGroups.add(g);
      } else {
        otherGroups.add(g);
      }
    }
    return ['all', ...trGroups, ...kurdGroups, ...otherGroups..sort()];
  }

  /// Kanalları sırala: Türkçe en başta, Kürtçe ikincide, geri kalan alfabetik.
  List<Channel> _sortChannels(List<Channel> channels) {
    final turkish = <Channel>[];
    final kurdish = <Channel>[];
    final others = <Channel>[];
    for (final c in channels) {
      final g = c.displayGroup.toUpperCase();
      final n = c.name.toUpperCase();
      if (g.startsWith('TR') || g.contains('TURK') || g.contains('TÜRK') ||
          g.contains('ULUSAL') || g.contains('HABER') || g.contains('SPOR') ||
          g.contains('BELGESEL') || g.contains('SİNEMA') || g.contains('MÜZİK') ||
          g.contains('EĞLENCE') || g.contains('ÇOCUK') ||
          n.contains('TRT') || n.contains('ATV') || n.contains('KANAL D') ||
          n.contains('STAR TV') || n.contains('TV8') || n.contains('NTV') ||
          n.contains('A HABER') || n.contains('SHOW TV')) {
        turkish.add(c);
      } else if (g.contains('KÜRT') || g.contains('KURD') ||
                 g.startsWith('🟩') ||
                 n.contains('KURD') || n.contains('RUDAW') ||
                 n.contains('NRT') || n.contains('WAAR') ||
                 n.contains('NALIA') || n.contains('KURDSAT')) {
        kurdish.add(c);
      } else {
        others.add(c);
      }
    }
    return [...turkish, ...kurdish, ...others];
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
    // Yetişkin içerik filtresi: showAdultContent false ise yetişkin içerikleri filtrele
    if (!_showAdultContent) {
      list = list.where((c) => !SettingsService.isAdultContent(c.name) && !SettingsService.isAdultContent(c.group ?? '')).toList();
    }
    return _sortChannels(list);
  }

  List<Channel> get favoriteChannels => _sortChannels(
    _channels.where((c) => _favorites.contains(c.url)).toList());

  /// Uygulama açılışında kaydedilmiş kaynağı yükler.
  Future<void> init() async {
    // Eski cache dosyalarını temizle (playlist_*.json).
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().whereType<File>();
      for (final f in files) {
        if (f.path.contains('playlist_') && f.path.endsWith('.json')) {
          await f.delete();
        }
      }
    } catch (_) {}
    _favorites = await FavoritesService.load();
    _showAdultContent = await SettingsService.loadAdultContent();
    // Tüm kaynakları yükle
    _allSources = await PlaylistService.loadAllSources();
    _activeSourceIndex = await PlaylistService.loadActiveIndex();
    if (_activeSourceIndex >= _allSources.length) {
      _activeSourceIndex = _allSources.isEmpty ? 0 : 0;
    }
    notifyListeners();
    // Kayıtlı kaynaklar varsa onları yükle, yoksa ücretsiz kanalları yükle
    if (_allSources.isNotEmpty) {
      unawaited(loadAllSourcesCombined());
    } else {
      // Hiç kaynak yoksa — ücretsiz Türkçe kanalları varsayılan olarak yükle
      unawaited(_loadDefaultTurkishChannels());
    }
  }

  /// Varsayılan olarak ücretsiz Türkçe kanalları yükler.
  Future<void> _loadDefaultTurkishChannels() async {
    try {
      isLoading = true;
      notifyListeners();
      _channels = await FreeTvService.loadCuratedTurkish();
      _testSource = false;
      selectedGroup = 'all';
      isLoading = false;
      error = null;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      error = 'Kanallar yüklenemedi: $e';
      notifyListeners();
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
        // Çoklu kaynak listesini güncelle
        if (!_allSources.any((src) => src.value == s.value)) {
          _allSources.add(s);
        }
        _activeSourceIndex = _allSources.indexWhere((src) => src.value == s.value);
        if (_activeSourceIndex < 0) _activeSourceIndex = 0;
        await PlaylistService.saveAllSources(_allSources);
        await PlaylistService.saveActiveIndex(_activeSourceIndex);
        // Kanallar hazır → yükleme durumunu HEMEN kapat; kullanıcı kanalları
        // görsün. EPG/VOD/doğrulama arka planda tamamlanır (açılışta uzun
        // bekleme → 2GB Box'ta "donuyor/çöküyor" hissinin ana nedeniydi).
        isLoading = false;
        notifyListeners();
        unawaited(_loadEpg(XtreamService.epgUrl(creds), silent: true));
        unawaited(_tryLoadVod());
        // Test kaynağı: kanalları doğrula (yalnızca açılanlar listelensin —
        // günde bir kez; önbellekli).
        if (_testSource) {
          unawaited(_verifyTestChannels(creds));
        }
        return;
      } else {
        // Disk önbelleği: devasa ücretsiz kanal listeleri (iptv-org) her
        // açılışta yeniden indirilirse hem yavaşlar hem çöker. Önbellek
        // günlük yenilenir — aradaki açılışlar anında yüklenir.
        final cached = await PlaylistService.loadCached(s);
        _channels = cached ?? const [];
        if (_channels.isEmpty) {
          loadProgress = 0;
          loadTotal = 0;
          notifyListeners();
          _channels = await PlaylistService.load(
            s,
            onProgress: (done) {
              loadProgress = done;
              notifyListeners();
            },
          );
          await PlaylistService.saveCache(s, _channels);
        }
        await PlaylistService.saveSource(s);
        // Çoklu kaynak listesini güncelle
        if (!_allSources.any((src) => src.value == s.value)) {
          _allSources.add(s);
        }
        _activeSourceIndex = _allSources.indexWhere((src) => src.value == s.value);
        if (_activeSourceIndex < 0) _activeSourceIndex = 0;
        await PlaylistService.saveAllSources(_allSources);
        await PlaylistService.saveActiveIndex(_activeSourceIndex);
        isLoading = false;
        loadProgress = 0;
        loadTotal = 0;
        notifyListeners();
        // M3U kanallarının içine gömülü Xtream adreslerini ara.
        // Bulunursa VOD kataloğu ve EPG de arka planda açılır.
        _derivedCreds = XtreamService.tryFromChannelUrls(_channels);
        if (_derivedCreds != null) {
          unawaited(_tryLoadVod());
          unawaited(_loadEpg(XtreamService.epgUrl(_derivedCreds!), silent: true));
        }
        return;
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
    // Doğrulama çok ağır — sadece ilk 50 kanalı doğrula
    // (tümünü doğrulamak 2GB Box'ta ANR yapar)
    final prefs = await SharedPreferences.getInstance();
    final key = 'test_channels_'
        '${creds.server.replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
    final tsKey = '${key}_ts';

    // 24 saat içinde doğrulandıysa önbelleği kullan
    final lastRaw = prefs.getString(tsKey);
    if (lastRaw != null) {
      final last = DateTime.tryParse(lastRaw);
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 24)) {
        final cached = prefs.getString(key);
        if (cached != null) {
          final cachedChannels =
              await compute(ChannelProbeService.decode, cached);
          if (cachedChannels.isNotEmpty) {
            _channels = cachedChannels;
            notifyListeners();
            return;
          }
        }
      }
    }

    // Sadece ilk 50 kanalı doğrula (hızlı)
    final toProbe = List<Channel>.of(_channels.take(50));
    testProbeActive = true;
    testProbeDone = 0;
    testProbeTotal = toProbe.length;
    var lastNotify = DateTime.now();
    final alive = await ChannelProbeService.probeAlive(
      toProbe,
      onProgress: (d, t) {
        testProbeDone = d;
        testProbeTotal = t;
        final now = DateTime.now();
        if (now.difference(lastNotify) >= const Duration(milliseconds: 500) ||
            d == t) {
          lastNotify = now;
          notifyListeners();
        }
      },
    );
    testProbeActive = false;
    if (alive.isNotEmpty) {
      _channels = alive;
      final encoded = await compute(ChannelProbeService.encode, alive);
      await prefs.setString(key, encoded);
      await prefs.setString(tsKey, DateTime.now().toIso8601String());
    }
    notifyListeners();
  }

  // ---- Çoklu kaynak yönetimi ----

  /// Yeni bir IPTV kaynağı ekle veya mevcut olanı güncelle.
  Future<void> addIptvSource(PlaylistSource source) async {
    _allSources = await PlaylistService.addOrUpdateSource(source);
    _activeSourceIndex = _allSources.length - 1;
    await PlaylistService.saveActiveIndex(_activeSourceIndex);
    notifyListeners();
    // Yeni kaynağı yükle
    await loadFromSource(source);
  }

  /// Belirli bir indeksteki kaynağa geç.
  Future<void> switchToSource(int index) async {
    if (index < 0 || index >= _allSources.length) return;
    if (index == _activeSourceIndex) return;
    _activeSourceIndex = index;
    await PlaylistService.saveActiveIndex(index);
    notifyListeners();
    await loadFromSource(_allSources[index]);
  }

  /// Tüm kaynakları aynı anda yükle ve kanalları birleştir.
  Future<void> loadAllSourcesCombined() async {
    _allSources = await PlaylistService.loadAllSources();
    if (_allSources.isEmpty) return;

    // 1) Önce TÜM kaynaklardan cache'lenmiş kanalları hemen göster (ANR yok)
    final allChannels = <Channel>[];
    for (var i = 0; i < _allSources.length; i++) {
      final src = _allSources[i];
      if (!src.isActive) { _allSources[i] = src.copyWith(channelCount: 0); continue; }
      try {
        final cached = await PlaylistService.loadCached(src);
        if (cached != null && cached.isNotEmpty) {
          _allSources[i] = src.copyWith(channelCount: cached.length);
          allChannels.addAll(cached);
        }
      } catch (_) {}
    }
    if (allChannels.isNotEmpty) {
      final seen = <String>{};
      _channels = [];
      for (final c in allChannels) {
        if (!seen.contains(c.url)) { seen.add(c.url); _channels.add(c); }
      }
      isLoading = false;
      selectedGroup = 'all';
      notifyListeners();
    }

    // 2) Arka planda her kaynağı yenile (UI bloklanmaz)
    _refreshAllSourcesInBackground();
  }

  /// Arka planda tüm kaynakları yenile — UI thread'i tıkamaz.
  Future<void> _refreshAllSourcesInBackground() async {
    final refreshedChannels = <Channel>[];
    for (var i = 0; i < _allSources.length; i++) {
      final src = _allSources[i];
      if (!src.isActive) continue;
      try {
        List<Channel> channels = [];
        if (src.type == PlaylistSourceType.xtream) {
          final creds = XtreamCredentials.fromJson(jsonDecode(src.value) as Map<String, dynamic>);
          if (creds != null) channels = await XtreamService.loadLiveChannels(creds);
        } else if (src.type == PlaylistSourceType.url) {
          final xt = XtreamService.tryParsePlaylistUrl(src.value);
          if (xt != null) { channels = await XtreamService.loadLiveChannels(xt); }
          else { channels = await PlaylistService.load(src); }
          if (channels.isNotEmpty) await PlaylistService.saveCache(src, channels);
        } else {
          channels = await PlaylistService.load(src);
          if (channels.isNotEmpty) await PlaylistService.saveCache(src, channels);
        }
        _allSources[i] = src.copyWith(channelCount: channels.length);
        refreshedChannels.addAll(channels);
      } catch (_) {
        _allSources[i] = src.copyWith(channelCount: 0);
      }
    }
    if (refreshedChannels.isNotEmpty) {
      await PlaylistService.saveAllSources(_allSources);
      final seen = <String>{};
      _channels = [];
      for (final c in refreshedChannels) {
        if (!seen.contains(c.url)) { seen.add(c.url); _channels.add(c); }
      }
      selectedGroup = 'all';
      notifyListeners();
    }
  }

  /// Kaynağın aktif/pasif durumunu değiştir.
  Future<void> toggleSource(int index) async {
    if (index < 0 || index >= _allSources.length) return;
    final src = _allSources[index];
    _allSources[index] = src.copyWith(isActive: !src.isActive);
    await PlaylistService.saveAllSources(_allSources);
    notifyListeners();
    // Aktif kaynakları yeniden yükle
    await loadAllSourcesCombined();
  }

  /// Belirli bir indeksteki kaynağı sil.
  Future<void> removeIptvSource(int index) async {
    _allSources = await PlaylistService.removeSource(index);
    if (_activeSourceIndex >= _allSources.length) {
      _activeSourceIndex = _allSources.isEmpty ? -1 : 0;
    }
    await PlaylistService.saveActiveIndex(_activeSourceIndex);
    notifyListeners();
    // Aktif kaynakları yeniden yükle
    await loadAllSourcesCombined();
  }

  Future<void> clearPlaylist() async {
    _channels = [];
    source = null;
    loadProgress = 0;
    loadTotal = 0;
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
    _allSources = [];
    _activeSourceIndex = 0;
    await PlaylistService.saveAllSources([]);
    await PlaylistService.saveActiveIndex(0);
    notifyListeners();
  }

  // ---- EPG ----

  Future<void> loadEpg(String url) => _loadEpg(url, silent: false);

  Future<void> _loadEpg(String url, {required bool silent}) async {
    epgLoading = true;
    epgError = null;
    epgUrl = url;
    try {
      epg = await EpgService.load(url);
    } catch (e) {
      epgError = e.toString();
    } finally {
      epgLoading = false;
      // Sadece sessiz olmayan yüklemelerde rebuild tetikle
      if (!silent) notifyListeners();
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
      // Yetişkin içerikleri yükleme sırasında filtrele
      if (!_showAdultContent) {
        vodMovies = movies.where((m) => !SettingsService.isAdultContent(m.name)).toList();
        vodSeries = series.where((s) => !SettingsService.isAdultContent(s.name)).toList();
      } else {
        vodMovies = movies;
        vodSeries = series;
      }
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
    if (creds == null) return null;
    // Sunucunun bildirdiği dosya uzantısını (mp4/mkv…) bul — ExoPlayer
    // uzantıya göre çözer; yanlış uzantı filmi açmaz.
    String? ext;
    for (final m in vodMovies) {
      if (m.id == movieId) {
        ext = m.containerExtension;
        break;
      }
    }
    return XtreamService.movieUrl(creds, movieId, containerExtension: ext);
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
  String? episodePlayUrl(int episodeId, {String? containerExtension}) {
    final creds = _creds;
    return creds == null
        ? null
        : XtreamService.episodeUrl(
            creds,
            episodeId,
            containerExtension: containerExtension,
          );
  }

  String? get vodCategoryName => vodCategories
      .where((c) => c.$1 == selectedVodCategory)
      .map((c) => c.$2)
      .firstOrNull;

  List<(String, String)> get filteredVodCategories {
    if (_showAdultContent) return vodCategories;
    return vodCategories
        .where((c) => !SettingsService.isAdultContent(c.$1) && !SettingsService.isAdultContent(c.$2))
        .toList();
  }

  List<VodMovie> get filteredVodMovies {
    var list = vodMovies;
    if (selectedVodCategory != 'all') {
      list = list.where((m) => m.categoryId == selectedVodCategory).toList();
    }
    final q = vodQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) => m.name.toLowerCase().contains(q)).toList();
    }
    // Yetişkin içerik filtresi: hem film ismi hem kategori ismini kontrol et
    if (!_showAdultContent) {
      list = list.where((m) {
        // Film ismini kontrol et
        if (SettingsService.isAdultContent(m.name)) return false;
        // Kategori ismini kontrol et (categoryId -> categoryName eşleme)
        final catName = vodCategories
            .where((c) => c.$1 == m.categoryId)
            .map((c) => c.$2)
            .join();
        if (SettingsService.isAdultContent(catName)) return false;
        return true;
      }).toList();
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
    // Yetişkin içerik filtresi: hem dizi ismi hem kategori ismini kontrol et
    if (!_showAdultContent) {
      list = list.where((s) {
        // Dizi ismini kontrol et
        if (SettingsService.isAdultContent(s.name)) return false;
        // Kategori ismini kontrol et
        final catName = vodCategories
            .where((c) => c.$1 == s.categoryId)
            .map((c) => c.$2)
            .join();
        if (SettingsService.isAdultContent(catName)) return false;
        return true;
      }).toList();
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

  void setShowAdultContent(bool show) {
    _showAdultContent = show;
    notifyListeners();
  }
}
