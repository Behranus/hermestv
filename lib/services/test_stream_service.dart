import 'package:http/http.dart' as http;

/// İnternette herkese açık, kararlı ücretsiz test yayınları.
///
/// Her "Test Yayınları" basışında adaylar **canlı olarak tek tek kontrol edilir**
/// ve yalnızca o an çalışanlar listeye eklenir — liste kendini günceller.
class TestStreamService {
  static const _timeout = Duration(seconds: 10);

  /// Aday test yayınları. `live` alanı Canlı/VOD grubunu belirler.
  static const candidates = <TestStreamCandidate>[
    // ---- Canlı test kanalları (global) ----
    TestStreamCandidate(
      'Akamai Live Test 1',
      'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'Akamai Live Test 2',
      'https://moctobpltc-i.akamaihd.net/hls/live/571329/eight/playlist.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'NASA TV (Canlı)',
      'https://ntv1.akamaized.net/hls/live/2014075/NASA-NTV1-HLS/master.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'DW English (Canlı)',
      'https://dwamdstream102.akamaized.net/hls/live/2015525/dwstream102/index.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'France 24 English (Canlı)',
      'https://static.france24.com/live/F24_EN_LO_HLS/live_web.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'Al Jazeera English',
      'https://live-hls-web-aje.getaj.net/AJE/index.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'Euronews English',
      'https://euronews-euronews-english-2-us.plex.wurl.tv/playlist.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'Bloomberg TV',
      'https://cdn.livepeer.com/hls/index.m3u8',
      live: true,
    ),
    // ---- Ekstra Haber Kanalları ----
    TestStreamCandidate(
      'Sky News Live',
      'https://edge-audio-03-gos2.shadмеда.net/skynews/skynews_main_sdl_hls.smil/playlist.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'NHK World Japan',
      'https://nhkwlive-ojp.akamaized.net/hls/live/2003459/nhkwjp-ojp-en/index.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      'CGTN English',
      'https://english.cctv.com/live/cctv_English/index.m3u8',
      live: true,
    ),
    // ---- 4K Test Akışları ----
    TestStreamCandidate(
      '4K Demo (Akamai)',
      'https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8',
      live: true,
    ),
    TestStreamCandidate(
      '4K Tears of Steel',
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
      live: false,
    ),
    TestStreamCandidate(
      '4K Sintel',
      'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
      live: false,
    ),
    // ---- VOD / demo akışları ----
    TestStreamCandidate(
      'Big Buck Bunny (Mux)',
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
      live: false,
    ),
    TestStreamCandidate(
      'Tears of Steel (Mux)',
      'https://test-streams.mux.dev/tos_ismc/main.m3u8',
      live: false,
    ),
    TestStreamCandidate(
      'Apple Advanced Stream',
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8',
      live: false,
    ),
    TestStreamCandidate(
      'Apple Bipbop Variant',
      'https://d2zihajmogu5jn.cloudfront.net/bipbop-advanced/bipbop_16x9_variant.m3u8',
      live: false,
    ),
    TestStreamCandidate(
      'Apple Bipbop Basic',
      'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear0/prog_index.m3u8',
      live: false,
    ),
    TestStreamCandidate(
      'Big Buck Bunny (Bitmovin)',
      'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
      live: false,
    ),
    TestStreamCandidate(
      'Elephant Dream',
      'https://download.blender.org/edBigBuckBunny/bigbuckbunny_machine-260216.mp4',
      live: false,
    ),
    TestStreamCandidate(
      'HLS Test (Wowza)',
      'https://demo.streamcast.tech/live/live.stream/playlist.m3u8',
      live: true,
    ),
  ];

  /// Adayları paralel kontrol eder, o an çalışanları M3U içeriği olarak döndürür.
  ///
  /// Her çağrıda taze kontrol yapılır → liste kendini günceller.
  static Future<String> fetchPlaylist() async {
    final results = await Future.wait(
      candidates.map(_check),
    );
    final working = <TestStreamCandidate>[];
    for (final (candidate, ok) in results) {
      if (ok) working.add(candidate);
    }
    if (working.isEmpty) {
      throw Exception(
        'Test yayınlarına şu an ulaşılamadı. İnternet bağlantını kontrol edip tekrar dene.',
      );
    }

    final buffer = StringBuffer('#EXTM3U\n');
    for (final c in working) {
      final group = c.live ? 'Test — Canlı' : 'Test — VOD';
      buffer.writeln(
        '#EXTINF:-1 tvg-id="${_slug(c.name)}" group-title="$group",${c.name}',
      );
      buffer.writeln(c.url);
    }
    return buffer.toString();
  }

  static Future<(TestStreamCandidate, bool)> _check(TestStreamCandidate c) async {
    try {
      final resp = await http
          .get(
            Uri.parse(c.url),
            headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36'},
          )
          .timeout(_timeout);
      final ok = resp.statusCode == 200 &&
          resp.bodyBytes.isNotEmpty &&
          String.fromCharCodes(resp.bodyBytes.take(32)).contains('#');
      return (c, ok);
    } catch (_) {
      return (c, false);
    }
  }

  static String _slug(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
}

/// Aday test yayını.
class TestStreamCandidate {
  const TestStreamCandidate(this.name, this.url, {required this.live});

  final String name;
  final String url;

  /// true ise canlı yayın (CANLI rozeti gösterilir), false ise VOD benzeri.
  final bool live;
}
