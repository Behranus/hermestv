import 'package:media_kit/media_kit.dart';

/// Oynatıcıyı **TiviMate** tarzı çalışacak şekilde ayarlar.
///
/// Temel prensip: ağır işleme filtresi YOK (zayıf Android Box GPU'sunu
/// yormaz → donma/kasma olmaz), görüntü net (lanczos), ses güvenilir
/// (stereo + 48 kHz). Önceki sürümdeki `ewa_lanczossharp + sigmoid +
/// deband + hdr-compute-peak` kombinasyonu Box'larda kare düşürüp hem
/// kasılmaya hem kötü görüntüye yol açıyordu — kaldırıldı.
class MpvTuning {
  /// Ayarları uygular. `bufferSecs` kullanıcının seçtiği bağlantı hızıdır
  /// (küçük değer = daha hızlı kanal geçişi).
  static void apply(Player player, {required double bufferSecs}) {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
      // ---- Hızlı kanal geçişi (TiviMate tarzı) ----
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-secs', bufferSecs.toString());
      // Önbellek dolmadan ilk kare gelir gelmez başlat — geçiş gecikmesini kaldırır.
      platform.setProperty('cache-pause-initial', 'no');
      // Disk önbelleği yavaş flash bellekli Box'larda mikro takılma yapar.
      platform.setProperty('cache-on-disk', 'no');
      // Kanallar arası geçişte gereksiz ön okumayı sınırla.
      platform.setProperty('demuxer-max-bytes', '8388608');
      // Yavaş ağlarda erken hata vermesin.
      platform.setProperty('network-timeout', '12');
      // youtube-dl çözümlemesi IPTV'de gecikme yaratır.
      platform.setProperty('ytdl', 'no');
      // Bazı sağlayıcılar boş/bilinmeyen User-Agent'ı reddeder.
      platform.setProperty(
        'http-header-fields',
        'User-Agent: Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
      );

      // ---- Görüntü: hafif ama net (TiviMate gibi) ----
      // ewa_lanczossharp yerine lanczos: zayıf GPU'da bile akıcı, keskin.
      platform.setProperty('scale', 'lanczos');
      platform.setProperty('cscale', 'lanczos');
      platform.setProperty('dscale', 'lanczos');
      // Ağır işlemler kapalı — donma/kasmanın asıl nedeni bunlardı.
      platform.setProperty('correct-downscaling', 'no');
      platform.setProperty('linear-downscaling', 'no');
      platform.setProperty('sigmoid-upscaling', 'no');
      platform.setProperty('deband', 'no');
      platform.setProperty('hdr-compute-peak', 'no');
      // TV'ye sınırlı (16-235) seviye çıkışı — doğru siyahlar, doğru renk.
      platform.setProperty('video-output-levels', 'limited');

      // ---- Ses: Box'larda "ses yok / bozuk / çatırdama" sorunlarını çözer ----
      // 5.1/AC3 akışlarda bazı Box'lar ses veremez; TiviMate gibi stereo çık.
      platform.setProperty('audio-channels', '2');
      // 44.1 kHz akışlarda bazı Box'lar bozuk/hatalı ses üretir; 48 kHz'e sabitle.
      platform.setProperty('audio-samplerate', '48000');
    } catch (_) {
      // Ayar yapılamazsa varsayılanlarla devam et (çökme olmaz).
    }
  }
}
