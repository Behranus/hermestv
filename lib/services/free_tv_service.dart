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
    // ---- Türkçe Kanallar (Premium benzeri) ----
    ('🇹🇷 Türkçe Tüm Kanallar (174)',
        '${baseUrl}countries/tr.m3u'),
    ('🇹🇷 TURKTV (55)',
        'https://itasli.github.io/TURKTV/index.m3u'),
    ('🇹🇷 Türkçe Haber',
        '${baseUrl}categories/news/tr.m3u'),
    ('🇹🇷 Türkçe Müzik',
        '${baseUrl}categories/music/tr.m3u'),
    ('🇹🇷 Türkçe Eğlence',
        '${baseUrl}categories/entertainment/tr.m3u'),
    // ---- Türkçe Sinema/Film Kanalları ----
    ('🎬 Türkçe Film Kanalları (7)',
        '${baseUrl}countries/tr.m3u'),  // Movies grubu
    ('🎬 Dünya Film Kanalları (731)',
        '${baseUrl}categories/movies.m3u'),
    // ---- Kürtçe Kanallar ----
    ('🏴 Kürtçe Kanallar (34)',
        '${baseUrl}languages/kur.m3u'),
    // ---- Spor (Premium benzeri) ----
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
    // ---- Ülke Bazlı Premium Benzeri ----
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
    FreeTvCountry('kur', 'Kürdistan', '🏴'),
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

  /// Ülkenin (veya dilin) tüm kanalları.
  /// Kürtçe özel durum: iptv-org dil bazlı playlist kullanır.
  static String countryM3u(String code) {
    if (code == 'kur') return '${baseUrl}languages/kur.m3u';
    return '${baseUrl}countries/$code.m3u';
  }

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
}
