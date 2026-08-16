import 'package:shared_preferences/shared_preferences.dart';

/// Oynatıcı bağlantı hızı seçeneği (mpv tampon süresini belirler).
class PlayerSpeed {
  const PlayerSpeed(this.label, this.bufferSecs, this.description);

  final String label;

  /// mpv `cache-secs` değeri (saniye). Küçük değer = daha hızlı kanal geçişi.
  final double bufferSecs;
  final String description;

  static const options = <PlayerSpeed>[
    PlayerSpeed('Çok Hızlı', 0.3, 'Anlık geçiş, çok küçük tampon'),
    PlayerSpeed('Hızlı', 0.5, 'Hızlı geçiş, küçük tampon'),
    PlayerSpeed('Normal', 1.0, 'Dengeli geçiş hızı'),
    PlayerSpeed('Dengeli', 2.0, 'Daha akıcı, orta tampon'),
    PlayerSpeed('Geniş', 4.0, 'En akıcı, büyük tampon (yavaş ağlar)'),
  ];
}

/// Kullanıcı ayarlarını (bağlantı hızı, ses) saklayan servis.
class SettingsService {
  static const _speedIndexKey = 'player_speed_index';
  static const _volumeKey = 'player_volume';

  /// Kaydedilmiş bağlantı hızını döndürür (varsayılan: Hızlı 0.5 sn).
  static Future<PlayerSpeed> loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_speedIndexKey) ?? 1;
    if (idx < 0 || idx >= PlayerSpeed.options.length) return PlayerSpeed.options[1];
    return PlayerSpeed.options[idx];
  }

  static Future<void> saveSpeed(PlayerSpeed speed) async {
    final prefs = await SharedPreferences.getInstance();
    final idx = PlayerSpeed.options.indexWhere((o) => o.bufferSecs == speed.bufferSecs);
    await prefs.setInt(_speedIndexKey, idx < 0 ? 1 : idx);
  }

  /// Kaydedilmiş ses seviyesini döndürür (varsayılan 0.8).
  static Future<double> loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_volumeKey) ?? 0.8;
    return v.clamp(0.0, 1.0);
  }

  static Future<void> saveVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, volume.clamp(0.0, 1.0));
  }
}
