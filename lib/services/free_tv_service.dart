import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/services/m3u_parser.dart';

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

/// iptv-org kaynaklarından (https://iptv-org.github.io/iptv/)
/// ücretsiz ve yasal kanal listelerini çeker.
///
/// Bu kaynak yalnızca yayıncıların kendilerinin ücretsiz sunduğu
/// (public broadcaster / free-to-air) kanalları içerir.
class FreeTvService {
  static const baseUrl = 'https://iptv-org.github.io/iptv/';

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
  static Future<List<Channel>> loadM3u(String url) async {
    final resp = await http
        .get(Uri.parse(url), headers: {'User-Agent': 'IPTVPlayer/1.0'})
        .timeout(const Duration(seconds: 60));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} hatası: $url');
    }
    // M3U ayrıştırma arka plan izolatında çalışır — UI izolatı binlerce
    // kanallık listelerde donmasın (2GB RAM'li Box'larda çökme nedeni).
    final channels =
        await compute(M3uParser.parse, utf8.decode(resp.bodyBytes));
    if (channels.isEmpty) {
      throw const FormatException('Kanal bulunamadı.');
    }
    return channels;
  }
}
