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
  static const extraSources = <(String label, String url)>[
    // ---- Spor ----
    ('⚽ Spor Kanalları Dünya (462)',
        '${baseUrl}categories/sports.m3u'),
    // ---- Haber ----
    ('📰 Haber Kanalları Dünya (963)',
        '${baseUrl}categories/news.m3u'),
    // ---- Film ----
    ('🎬 Film Kanalları Dünya (731)',
        '${baseUrl}categories/movies.m3u'),
    // ---- Belgesel ----
    ('📚 Belgesel Kanalları (241)',
        '${baseUrl}categories/documentary.m3u'),
    // ---- Çocuk ----
    ('👶 Çocuk Kanalları (370)',
        '${baseUrl}categories/kids.m3u'),
    // ---- Ülke Bazlı (TR ve Kürdistan hariç) ----
    ('🇩🇪 Almanya (294)',
        '${baseUrl}countries/de.m3u'),
    ('🇺🇸 ABD (1462)',
        '${baseUrl}countries/us.m3u'),
    ('🇫🇷 Fransa (215)',
        '${baseUrl}countries/fr.m3u'),
    ('🇰🇷 Güney Kore (73)',
        '${baseUrl}countries/kr.m3u'),
    ('🇮🇳 Hindistan (722)',
        '${baseUrl}countries/in.m3u'),
    ('🇧🇷 Brezilya (392)',
        '${baseUrl}countries/br.m3u'),
    ('🇷🇺 Rusya (452)',
        '${baseUrl}countries/ru.m3u'),
    ('🇮🇹 İtalya (310)',
        '${baseUrl}countries/it.m3u'),
    // ---- Dil Bazlı ----
    ('🇸🇦 Arapça',
        '${baseUrl}languages/ara.m3u'),
    ('🇬🇧 İngilizce',
        '${baseUrl}languages/eng.m3u'),
    ('🇩🇪 Almanca',
        '${baseUrl}languages/deu.m3u'),
    ('🇫🇷 Fransızca',
        '${baseUrl}languages/fra.m3u'),
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
    // ── ULUSAL KANALLAR (en çok izlenen) ──
    ('📺 Ulusal', 'TRT 1', 'https://tv-trt1.medya.trt.com.tr/master.m3u8'),
    ('📺 Ulusal', 'ATV', 'https://rnttwmjcin.turknet.ercdn.net/lcpmvefbyo/atv/atv_1080p.m3u8'),
    ('📺 Ulusal', 'Kanal D', 'https://demiroren.daioncdn.net/kanald/kanald.m3u8?app=kanald_web&ce=32c97d0518e2ea74c8ea70f8075ac150'),
    ('📺 Ulusal', 'Star TV', 'https://dogus.daioncdn.net/startv/startv_720p.m3u8?app=a20ac41e-bdc3-4aa1-934d-2ee97828304d'),
    ('📺 Ulusal', 'A2TV', 'https://tvnet-live.daioncdn.net/a2tv/a2tv_1080p.m3u8?app=a2tv_web'),
    ('📺 Ulusal', 'Beyaz TV', 'https://beyaztv-live.daioncdn.net/beyaz/beyaz.m3u8'),
    ('📺 Ulusal', 'TV8', 'https://tv8-live.daioncdn.net/tv8/tv8.m3u8'),
    // ── HABER KANALLARI ──
    ('📰 Haber', 'NTV', 'https://dogus.daioncdn.net/ntv/ntv.m3u8?app=ntv_web'),
    ('📰 Haber', 'A Haber', 'https://rnttwmjcin.turknet.ercdn.net/lcpmvefbyo/ahaber/ahaber.m3u8'),
    ('📰 Haber', 'Habertürk TV', 'https://tv.ensonhaber.com/haberturk/haberturk.m3u8'),
    ('📰 Haber', 'TRT Haber', 'https://tv-trthaber.medya.trt.com.tr/master.m3u8'),
    ('📰 Haber', 'BloombergHT', 'https://ciner-live.daioncdn.net/bloomberght/bloomberght.m3u8'),
    ('📰 Haber', '360 TV', 'https://turkmedya-live.ercdn.net/tv360/tv360.m3u8'),
    ('📰 Haber', 'TGRT Haber', 'https://canli.tgrthaber.com/tgrt.m3u8'),
    ('📰 Haber', 'Haber Global', 'https://tv.ensonhaber.com/haberglobal/haberglobal.m3u8'),
    // ── SPOR KANALLARI ──
    ('⚽ Spor', 'TRT Spor', 'https://corestream.siteyaptim.live/trt-spor/index.m3u8'),
    ('⚽ Spor', 'A Spor', 'https://rnttwmjcin.turknet.ercdn.net/lcpmvefbyo/aspor/aspor.m3u8'),
    ('⚽ Spor', 'FB TV', 'http://1hskrdto.rocketcdn.com/fenerbahcetv.smil/playlist.m3u8'),
    // ── BELGESEL KANALLARI ──
    ('📚 Belgesel', 'BBC Earth Türkiye', 'https://nord.ayakkabiparti.lol/bbc/index.m3u8'),
    ('📚 Belgesel', 'National Geographic', 'https://saran-live.ercdn.net/natgeohd/index.m3u8'),
    ('📚 Belgesel', 'GZT', 'https://gzttv-live.lg.mncdn.com/gzttv/gzttv/playlist.m3u8'),
    // ── SİNEMA KANALLARI ──
    ('🎬 Sinema', 'beIN Movies Stars', 'https://nord.ayakkabiparti.lol/bsaction1/index.m3u8'),
    ('🎬 Sinema', 'beIN Movies Turk', 'https://nord.ayakkabiparti.lol/bsturk/index.m3u8'),
    ('🎬 Sinema', 'FilmBox', 'http://46.149.191.219:9100/play/a015'),
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
