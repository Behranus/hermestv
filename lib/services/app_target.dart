/// Derleme hedefi: **Android Box** veya **Android Mobil**.
///
/// Derlerken seçilir:
/// - `--dart-define=TARGET=box`    → Android Box sürümü (varsayılan)
/// - `--dart-define=TARGET=mobile` → Android Mobil sürümü
///
/// Farklar:
/// - **Box:** kumanda (D-pad) odaklı, TV launcher'ına uygun.
/// - **Mobil:** dokunmatik ekran odaklı.
///
/// Oynatıcı her iki hedefte de **ExoPlayer** (resmi video_player) — donanım
/// hızlandırmalı MediaCodec, 4K/2K/FHD akıcı; Box/Mobil arasında motor farkı yok.
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
  static const String displayName = isBox ? 'bbtv (Box)' : 'bbtv (Mobil)';
}
