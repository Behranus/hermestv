/// Derleme hedefi: **Android Box** veya **Android Mobil**.
///
/// Derlerken seçilir:
/// - `--dart-define=TARGET=box`    → Android Box sürümü (varsayılan)
/// - `--dart-define=TARGET=mobile` → Android Mobil sürümü
///
/// Farklar:
/// - **Box:** tunnel modu açık — MediaCodec doğrudan surface'a çıkar
///   (OpenGL kopyası yok) → zayıf Box GPU'sunda Full HD/2K/4K akıcı oynar.
///   TV launcher'ı için leanback amaçlıdır; kumanda (D-pad) odaklı.
/// - **Mobil:** tunnel kapalı — tüm kodlayıcılar + HDR ton eşleme + snapshot
///   desteklenir; dokunmatik ekran odaklı.
abstract final class AppTarget {
  static const String target =
      String.fromEnvironment('TARGET', defaultValue: 'box');

  /// Android Box sürümü mü?
  static const bool isBox = target == 'box';

  /// Android Mobil sürümü mü?
  static const bool isMobile = !isBox;

  /// Şifre kilidi kapalı sürüm (`--dart-define=NO_LOCK=true`).
  static const bool isNoLock = bool.fromEnvironment('NO_LOCK');

  /// Kullanıcıya gösterilen uygulama adı.
  static const String displayName =
      isBox ? 'IPTV Player (Box)' : 'IPTV Player (Mobil)';

  /// fvp (libmdk) tunnel modu: Box'ta açık, Mobil'de kapalı.
  static const bool useTunnel = isBox;
}
