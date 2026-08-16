/// Test bölümü için **yerleşik, yasal VOD kataloğu**.
///
/// Test sunucularının çoğu VOD sunmaz; VOD sekmesi yine de aktif olsun diye
/// bu katalog kullanılır. Tüm içerikler kamuya açık, lisanslı (Blender CC-BY)
/// veya sağlayıcıların resmi test akışlarıdır. Adresler/görseller derleme
/// sırasında canlı olarak doğrulanmıştır.
class DemoVod {
  const DemoVod({
    required this.id,
    required this.name,
    required this.url,
    this.poster,
    required this.plot,
    required this.rating,
    required this.year,
    required this.duration,
    required this.genre,
  });

  final int id;
  final String name;
  final String url;
  final String? poster;
  final String plot;
  final String rating;
  final String year;
  final String duration;
  final String genre;
}

class TestVodCatalog {
  /// Kimlikler Xtream film kimlikleriyle çakışmasın diye 900000+ aralığında.
  static const items = <DemoVod>[
    DemoVod(
      id: 900001,
      name: 'Big Buck Bunny',
      url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      poster:
          'https://commons.wikimedia.org/wiki/Special:FilePath/Big_buck_bunny_poster_big.jpg',
      plot: 'Blender Vakfı\'nın açık kaynak filmi. Kocaman yürekli dev bir tavşan, '
          'üç zorba kemirgenin gazabına uğrar — ama sonunda tam anlamıyla '
          '"Büyük Şişko Tavşan" olduğunu kanıtlar. Tamamen ücretsiz, CC-BY lisanslı.',
      rating: '7.8',
      year: '2008',
      duration: '10 dk',
      genre: 'Animasyon • Komedi',
    ),
    DemoVod(
      id: 900002,
      name: 'Sintel',
      url: 'https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4',
      poster: 'https://commons.wikimedia.org/wiki/Special:FilePath/Sintel_poster.jpg',
      plot: 'Yalnız genç bir kadın olan Sintel, kanadı yaralı bir ejderhayı bulur, '
          'iyileştirir ve ona "Scales" adını verir. Ejderha kaybolduğunda Sintel '
          'onu bulmak için tehlikeli bir yolculuğa çıkar. CC-BY lisanslı açık film.',
      rating: '7.5',
      year: '2010',
      duration: '15 dk',
      genre: 'Animasyon • Macera',
    ),
    DemoVod(
      id: 900003,
      name: 'Tears of Steel',
      url: 'https://test-streams.mux.dev/tos_ismc/main.m3u8',
      poster: 'https://commons.wikimedia.org/wiki/Special:FilePath/Tos-poster.png',
      plot: 'Gelecekte Amsterdam: robotlar dünyayı ele geçirmiştir. Bir grup savaşçı '
          've bilim insanı, insanlığın kaderini değiştirmek için Oude Kerk\'te '
          'toplanır. Blender\'ın bilim kurgu açık filmi, CC-BY lisanslı.',
      rating: '7.1',
      year: '2012',
      duration: '12 dk',
      genre: 'Bilim Kurgu • Aksiyon',
    ),
    DemoVod(
      id: 900004,
      name: "Elephant's Dream",
      // AVI ExoPlayer'da açılmıyor; Blender'ın H.264/AAC MOV sürümü kullanılır.
      url: 'https://download.blender.org/ED/elephantsdream-480-h264-st-aac.mov',
      poster:
          'https://commons.wikimedia.org/wiki/Special:FilePath/Elephants%20Dream%20-%20Final%20Poster%20Source.png',
      plot: 'Devasa, kendi kendini üreten bir makinenin içinde yaşayan iki karakter: '
          'Emo ve Proog. Tuhaf, gerçeküstü dünyalarında yolculuk ederler. Blender\'ın '
          'ilk açık filmi, CC-BY lisanslı.',
      rating: '6.6',
      year: '2006',
      duration: '11 dk',
      genre: 'Animasyon • Fantastik',
    ),
    DemoVod(
      id: 900005,
      name: 'Tears of Steel (4K Uyarlamalı)',
      url: 'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
      poster: 'https://commons.wikimedia.org/wiki/Special:FilePath/Tos-poster.png',
      plot: 'Tears of Steel\'ın çok kaliteli (multi-bitrate) HLS sürümü — Unified '
          'Streaming\'in resmi demo akışı. Bağlantı hızına göre otomatik kalite '
          'seçimi yapar; yüksek çözünürlük testi için idealdir.',
      rating: '7.1',
      year: '2012',
      duration: '12 dk',
      genre: 'Bilim Kurgu • 4K Test',
    ),
    DemoVod(
      id: 900006,
      name: 'Apple Uyarlamalı Akış (HLS Test)',
      url: 'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
      poster: null,
      plot: 'Apple\'ın resmi geliştirici test akışı. Çoklu çözünürlüklü (adaptive) '
          'HLS örneği — canlı yayın kalitesi ve ağ uyumunu test etmek için '
          'kullanılır.',
      rating: '—',
      year: '—',
      duration: '10 dk',
      genre: 'Teknik Test • HLS',
    ),
  ];

  static DemoVod? byId(int id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }
}
