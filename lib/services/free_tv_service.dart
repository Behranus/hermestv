import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/services/m3u_parser.dart';

/// iptv-org kategorisi (yalnızca ücretsiz/yasal yayınlar).
class FreeTvCategory {
  const FreeTvCategory(this.slug, this.label, this.icon);

  final String slug;
  final String label;
  final IconData icon;
}

/// iptv-org ülkesi.
class FreeTvCountry {
  const FreeTvCountry(this.code, this.label, this.flag);

  final String code;
  final String label;
  final String flag;
}

/// Ücretsiz IPTV kaynaklarından kanal listelerini çeker.
///
/// Kaynaklar:
/// - iptv-org: world'un en büyük ücretsiz IPTV depoası (1000+ kanal)
/// - free-tv/iptv: HD/4K odaklı, kalite öncelikli ücretsiz kanallar
/// - Ülkelere göre kanallar, dil bazlı kanallar, kategori bazlı kanallar
///
/// Bu kaynak yalnızca yayıncıların kendilerinin ücretsiz sunduğu
/// (public broadcaster / free-to-air) kanalları içerir.
class FreeTvService {
  static const baseUrl = 'https://iptv-org.github.io/iptv/';

  /// Ek ücretsiz HD/4K kanal kaynakları.
  /// Her biri bir M3U playlist URL'si.
  /// Ek ücretsiz HD/4K kanal kaynakları.
  /// iptv-org (8000+), free-tv, apsattv ve özel kaynaklardan.
  static const extraSources = <(String label, String url)>[
    // ═══ KÜRT / KÜRDISTAN ═══
    ('🟩 Kürtçe TV',
        'https://kurdtvs.net/iptv.php'),
    // ═══ SPOR (global) ═══
    ('⚽ Spor Kanalları Dünya',
        '${baseUrl}categories/sports.m3u'),
    ('⚽ FIFA World TV',
        'https://cdn-static.waves.com/fifaplus/index.m3u8'),
    // ═══ HABER (global) ═══
    ('📰 Haber Kanalları Dünya',
        '${baseUrl}categories/news.m3u'),
    // ═══ FİLM (global) ═══
    ('🎬 Film Kanalları Dünya',
        '${baseUrl}categories/movies.m3u'),
    // ═══ BELGESEL ═══
    ('📚 Belgesel Kanalları',
        '${baseUrl}categories/documentary.m3u'),
    // ═══ ÇOCUK ═══
    ('👶 Çocuk Kanalları',
        '${baseUrl}categories/kids.m3u'),
    // ═══ EĞLENCE / MÜZİK ═══
    ('🎵 Müzik Kanalları',
        '${baseUrl}categories/music.m3u'),
    ('🎭 Eğlence Kanalları',
        '${baseUrl}categories/entertainment.m3u'),
    // ═══ ÜLKE BAZLI ═══
    ('🇩🇪 Almanya',
        '${baseUrl}countries/de.m3u'),
    ('🇺🇸 ABD',
        '${baseUrl}countries/us.m3u'),
    ('🇬🇧 İngiltere',
        '${baseUrl}countries/gb.m3u'),
    ('🇫🇷 Fransa',
        '${baseUrl}countries/fr.m3u'),
    ('🇮🇹 İtalya',
        '${baseUrl}countries/it.m3u'),
    ('🇪🇸 İspanya',
        '${baseUrl}countries/es.m3u'),
    ('🇵🇱 Polonya',
        '${baseUrl}countries/pl.m3u'),
    ('🇧🇷 Brezilya',
        '${baseUrl}countries/br.m3u'),
    ('🇷🇺 Rusya',
        '${baseUrl}countries/ru.m3u'),
    ('🇰🇷 Güney Kore',
        '${baseUrl}countries/kr.m3u'),
    ('🇮🇳 Hindistan',
        '${baseUrl}countries/in.m3u'),
    ('🇯🇵 Japonya',
        '${baseUrl}countries/jp.m3u'),
    ('🇲🇽 Meksika',
        '${baseUrl}countries/mx.m3u'),
    ('🇦🇷 Arjantin',
        '${baseUrl}countries/ar.m3u'),
    // ═══ FREE-TV (HD/4K odaklı) ═══
    ('📺 Free-TV Tümü',
        'https://raw.githubusercontent.com/Free-TV/IPTV/master/streams/streams.m3u'),
    // ═══ APSATTV (Xiaomi, global) ═══
    ('📱 Xiaomi TV Plus',
        'https://www.apsattv.com/xiaomi.m3u'),
    ('📱 Samsung TV Plus',
        'https://www.apsattv.com/samsung.m3u'),
    ('📺 Local Now',
        'https://www.apsattv.com/localnow.m3u'),
    // ═══ GLOBAL IPTV (iptv-org world) ═══
    ('🌍 Tüm Dünya Kanalları (8000+)',
        '${baseUrl}index.m3u'),
  ];

  static const categories = <FreeTvCategory>[
    FreeTvCategory('news', 'Haber', Icons.newspaper),
    FreeTvCategory('sports', 'Spor', Icons.sports_soccer),
    FreeTvCategory('music', 'Müzik', Icons.music_note),
    FreeTvCategory('movies', 'Film', Icons.movie),
    FreeTvCategory('series', 'Dizi', Icons.tv),
    FreeTvCategory('kids', 'Çocuk', Icons.child_care),
    FreeTvCategory('documentary', 'Belgesel', Icons.travel_explore),
    FreeTvCategory('education', 'Eğitim', Icons.school),
    FreeTvCategory('culture', 'Kültür', Icons.theater_comedy),
    FreeTvCategory('entertainment', 'Eğlence', Icons.celebration),
    FreeTvCategory('comedy', 'Komedi', Icons.mood),
    FreeTvCategory('animation', 'Animasyon', Icons.animation),
    FreeTvCategory('cooking', 'Mutfak', Icons.restaurant),
    FreeTvCategory('science', 'Bilim', Icons.science),
    FreeTvCategory('religious', 'Dini', Icons.temple_buddhist),
    FreeTvCategory('shop', 'Alışveriş', Icons.shopping_cart),
    FreeTvCategory('travel', 'Seyahat', Icons.flight),
    FreeTvCategory('weather', 'Hava', Icons.cloud),
    FreeTvCategory('relax', 'Rahatlama', Icons.spa),
    FreeTvCategory('general', 'Genel', Icons.public),
  ];

  static const countries = <FreeTvCountry>[
    FreeTvCountry('tr', 'Türkiye', '🇹🇷'),
    FreeTvCountry('us', 'ABD', '🇺🇸'),
    FreeTvCountry('gb', 'İngiltere', '🇬🇧'),
    FreeTvCountry('de', 'Almanya', '🇩🇪'),
    FreeTvCountry('fr', 'Fransa', '🇫🇷'),
    FreeTvCountry('es', 'İspanya', '🇪🇸'),
    FreeTvCountry('it', 'İtalya', '🇮🇹'),
    FreeTvCountry('gr', 'Yunanistan', '🇬🇷'),
    FreeTvCountry('ru', 'Rusya', '🇷🇺'),
    FreeTvCountry('br', 'Brezilya', '🇧🇷'),
    FreeTvCountry('mx', 'Meksika', '🇲🇽'),
    FreeTvCountry('nl', 'Hollanda', '🇳🇱'),
    FreeTvCountry('be', 'Belçika', '🇧🇪'),
    FreeTvCountry('ch', 'İsviçre', '🇨🇭'),
    FreeTvCountry('at', 'Avusturya', '🇦🇹'),
    FreeTvCountry('pl', 'Polonya', '🇵🇱'),
    FreeTvCountry('pt', 'Portekiz', '🇵🇹'),
    FreeTvCountry('se', 'İsveç', '🇸🇪'),
    FreeTvCountry('no', 'Norveç', '🇳🇴'),
    FreeTvCountry('dk', 'Danimarka', '🇩🇰'),
    FreeTvCountry('fi', 'Finlandiya', '🇫🇮'),
    FreeTvCountry('au', 'Avustralya', '🇦🇺'),
    FreeTvCountry('ca', 'Kanada', '🇨🇦'),
    FreeTvCountry('jp', 'Japonya', '🇯🇵'),
    FreeTvCountry('kr', 'Güney Kore', '🇰🇷'),
    FreeTvCountry('in', 'Hindistan', '🇮🇳'),
  ];

  /// Kategori listesi adresi. `country` verilirse o ülkenin alt kategorisi
  /// (`categories/{kategori}/{ülke}.m3u`), verilmezse tüm dünya çekilir.
  static String categoryM3u(String slug, {String? country}) => country == null
      ? '${baseUrl}categories/$slug.m3u'
      : '${baseUrl}categories/$slug/$country.m3u';

  /// Ülkenin tüm kanalları.
  static String countryM3u(String code) => '${baseUrl}countries/$code.m3u';

  static const allM3u = '${baseUrl}index.m3u';

  /// iptv-org grup adlarının Türkçe karşılıkları.
  static const _groupTranslations = <String, String>{
    'News': 'Haber',
    'Sports': 'Spor',
    'Music': 'Müzik',
    'Movies': 'Film',
    'Series': 'Dizi',
    'Kids': 'Çocuk',
    'Documentary': 'Belgesel',
    'Education': 'Eğitim',
    'Culture': 'Kültür',
    'Entertainment': 'Eğlence',
    'Comedy': 'Komedi',
    'Animation': 'Animasyon',
    'Cooking': 'Mutfak',
    'Science': 'Bilim',
    'Religious': 'Dini',
    'Shop': 'Alışveriş',
    'Travel': 'Seyahat',
    'Weather': 'Hava',
    'Relax': 'Rahatlama',
    'General': 'Genel',
    'Lifestyle': 'Yaşam',
    'Business': 'İş Dünyası',
    'Undefined': 'Diğer',
  };

  /// iptv-org grup adını Türkçeye çevirir (bilinmeyen ad aynen döner).
  static String translateGroup(String group) => _groupTranslations[group] ?? group;

  /// Ülkenin tüm kanallarını indirir ve gruplarına (kategorilerine) göre böler.
  ///
  /// iptv-org ülkeye özel kategori dosyası sunmadığı için ülke M3U'sundaki
  /// `group-title` alanları kategori olarak kullanılır. Dönen harita
  /// grup adı → kanal sayısı biçimindedir ve büyük gruplar önce gelir.
  static Future<Map<String, int>> loadCountryCategories(String code) async {
    final channels = await loadM3u(countryM3u(code));
    final counts = <String, int>{};
    for (final c in channels) {
      counts.update(c.displayGroup, (n) => n + 1, ifAbsent: () => 1);
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  /// M3U'yu indirir ve kanallara ayrıştırır.
  ///
  /// İndirme + UTF-8 çözümleme + ayrıştırma **arka plan izolatında** yapılır
  /// (devasa dünya listelerinde UI izolatı asla bloklanmaz — 2GB RAM'li
  /// Box'larda donma/çökmenin ana nedeni buydu).
  static Future<List<Channel>> loadM3u(String url) async {
    final channels = await compute(_fetchAndParse, url);
    if (channels.isEmpty) {
      throw const FormatException('Kanal bulunamadı.');
    }
    return channels;
  }

  /// [compute] geri çağrısı: tek izolatta indir + çöz + ayrıştır.
  ///
  /// User-Agent, çoğu CDN'in reddettiği basit agent yerine tarayıcı
  /// benzeri bir değer kullanır — bazı 4K/HD kanalları bunu ister.
  static Future<List<Channel>> _fetchAndParse(String url) async {
    final resp = await http
        .get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              'Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.8',
        })
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} hatası: $url');
    }
    return M3uParser.parse(utf8.decode(resp.bodyBytes));
  }

  /// Kategorili Türkçe kanal listesi: Ulusal → Haber → Spor → Belgesel → Sinema
  /// En çok izlenen ulusal kanallar en başta.
  static const curatedTurkishChannels = <(
    String category,
    String name,
    String url,
  )>[
    // ── ULUSAL (sadece çalışanlar — test: 2026-08-18) ──
    ('📺 Ulusal', 'TRT 1', 'https://tv-trt1.medya.trt.com.tr/master.m3u8'),
    ('📺 Ulusal', 'ATV', 'https://rnttwmjcin.turknet.ercdn.net/lcpmvefbyo/atv/atv_1080p.m3u8'),
    ('📺 Ulusal', 'Kanal D', 'https://demiroren.daioncdn.net/kanald/kanald.m3u8?app=kanald_web&ce=32c97d0518e2ea74c8ea70f8075ac150'),
    // ── HABER ──
    ('📰 Haber', 'NTV', 'https://dogus.daioncdn.net/ntv/ntv.m3u8?app=ntv_web'),
    ('📰 Haber', 'A Haber', 'https://rnttwmjcin.turknet.ercdn.net/lcpmvefbyo/ahaber/ahaber.m3u8'),
    ('📰 Haber', 'Habertürk TV', 'https://tv.ensonhaber.com/haberturk/haberturk.m3u8'),
    ('📰 Haber', 'TRT Haber', 'https://tv-trthaber.medya.trt.com.tr/master.m3u8'),
    ('📰 Haber', '360 TV', 'https://turkmedya-live.ercdn.net/tv360/tv360.m3u8'),
    ('📰 Haber', 'TGRT Haber', 'https://canli.tgrthaber.com/tgrt.m3u8'),
    ('📰 Haber', 'Haber Global', 'https://tv.ensonhaber.com/haberglobal/haberglobal.m3u8'),
    // ── SPOR ──
    ('⚽ Spor', 'A Spor', 'https://rnttwmjcin.turknet.ercdn.net/lcpmvefbyo/aspor/aspor.m3u8'),
    // ── BELGESEL ──
    ('📚 Belgesel', 'GZT', 'https://gzttv-live.lg.mncdn.com/gzttv/gzttv/playlist.m3u8'),
    // ── ÇOCUK ──
    ('👶 Çocuk', 'TRT Çocuk', 'https://tv-trtcocuk.medya.trt.com.tr/master.m3u8'),
    // ═══ KÜRTÇE ═══
    ('🟩 Kürtçe', 'Rudaw TV HD', 'https://live.rudaw.net/rudawtv.m3u8'),
    ('🟩 Kürtçe', 'Rudaw Arabi', 'https://live.rudaw.net/rudawarabi/rudawarabi.m3u8'),
    ('🟩 Kürtçe', 'Rudaw Turkmen', 'https://live.rudaw.net/rudawturkmen/rudawturkmen.m3u8'),
    // ═══ DÜNYA ═══
    ('🌍 Dünya Haber', 'DW English', 'https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8'),
    ('🌍 Dünya Haber', 'France 24 English', 'https://static.france24.com/live/F24_EN_LO_HLS/live_web.m3u8'),
    ('🌍 Dünya Haber', 'TRT World', 'https://tv-trtworld.medya.trt.com.tr/master.m3u8'),
    ('🌍 Eğlence', 'NASA TV', 'https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8'),
  ];

  /// Kategorili Türkçe kanalları yükle.
  static Future<List<Channel>> loadCuratedTurkish() async {
    final channels = <Channel>[];
    for (final entry in curatedTurkishChannels) {
      final (category, name, url) = entry;
      channels.add(Channel(
        name: name,
        url: url,
        group: category,
        logo: '',
      ));
    }
    return channels;
  }
}
