import 'package:media_kit/media_kit.dart';

/// Oynatıcıyı IPTV için ideal performansa ayarlar.
///
/// Hedef: TiviMate gibi hızlı kanal geçişi + Enigma cihazları gibi görüntü
/// kalitesi, donma/kasılmaya yol açan ayarlardan kaçınarak.
///
/// Not: media_kit varsayılanları `scale=bilinear` (bulanık görüntü) ve
/// `cache-on-disk=yes` (yavaş Box hafızasında takılma) kullanır — ikisi de
/// burada düzeltilir.
class MpvTuning {
  /// Ayarları uygular. `bufferSecs` kullanıcının seçtiği bağlantı hızıdır
  /// (küçük değer = daha hızlı kanal geçişi).
  static void apply(Player player, {required double bufferSecs}) {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
      // ---- Hızlı kanal geçişi (TiviMate tarzı) ----
      // Küçük hedef önbellek; ilk kare gelir gelmez oynatmaya başla.
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-secs', bufferSecs.toString());
      // Önbellek dolmadan başlat — geçiş gecikmesini kaldırır.
      platform.setProperty('cache-pause-initial', 'no');
      // Disk önbelleği yavaş flash bellekli Box'larda mikro takılma yapar.
      platform.setProperty('cache-on-disk', 'no');
      // Kanallar arası geçişte gereksiz ön okumayı sınırla.
      platform.setProperty('demuxer-max-bytes', '8388608');
      // Yavaş ağlarda erken hata vermesin (media_kit 5sn'ye düşürürdü).
      platform.setProperty('network-timeout', '15');
      // youtube-dl/youtube-dl çözümlemesi IPTV'de gecikme yaratır.
      platform.setProperty('ytdl', 'no');
      // Bazı sağlayıcılar boş/bilinmeyen User-Agent'ı reddeder.
      platform.setProperty(
        'http-header-fields',
        'User-Agent: Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
      );

      // ---- Görüntü kalitesi (Enigma cihazları gibi) ----
      // media_kit'in varsayılan bilinear ölçekleyicisi yerine yüksek kalite.
      platform.setProperty('scale', 'ewa_lanczossharp');
      platform.setProperty('cscale', 'ewa_lanczossharp');
      platform.setProperty('dscale', 'mitchell');
      // Büyütme/küçültmede doğru renk ve keskinlik.
      platform.setProperty('correct-downscaling', 'yes');
      platform.setProperty('linear-downscaling', 'yes');
      platform.setProperty('sigmoid-upscaling', 'yes');
      // HDR içerikte parlaklık bandını doğru hesapla.
      platform.setProperty('hdr-compute-peak', 'yes');
      // Renk bandı (posterization) giderimi.
      platform.setProperty('deband', 'yes');
      // TV'ye sınırlı (16-235) seviye çıkışı — doğru siyahlar.
      platform.setProperty('video-output-levels', 'limited');
      // Alt yazı donanım hızlandırma.
      platform.setProperty('hwdec-codecs', 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1');
    } catch (_) {
      // Ayar yapılamazsa varsayılanlarla devam et (çökme olmaz).
    }
  }
}
