import 'package:shared_preferences/shared_preferences.dart';

/// Oynatıcı bağlantı hızı seçeneği (mpv tampon süresini belirler).
class PlayerSpeed {
  const PlayerSpeed(this.label, this.bufferSecs, this.description);

  final String label;

  /// mpv `cache-secs` değeri (saniye). Küçük değer = daha hızlı kanal geçişi.
  final double bufferSecs;
  final String description;

  static const options = <PlayerSpeed>[
    PlayerSpeed('Süper Hızlı', 0.1, 'Anlık geçiş, minimal tampon'),
    PlayerSpeed('Çok Hızlı', 0.3, 'Çok hızlı geçiş, küçük tampon'),
    PlayerSpeed('Normal', 1.0, 'Dengeli geçiş hızı'),
    PlayerSpeed('Dengeli', 2.0, 'Daha akıcı, orta tampon'),
    PlayerSpeed('Geniş', 4.0, 'En akıcı, büyük tampon (yavaş ağlar)'),
    PlayerSpeed('4K Optimize', 8.0, '4K/HD için büyük tampon, maximum kalite'),
  ];
}

/// Kullanıcı ayarlarını (bağlantı hızı, ses, yetişkin içeriği) saklayan servis.
class SettingsService {
  static const _speedIndexKey = 'player_speed_index';
  static const _volumeKey = 'player_volume';
  static const _showAdultContentKey = 'show_adult_content';

  // Yetişkin içerik filtresi için kelime listesi (Türkçe + İngilizce)
  static const List<String> adultKeywords = [
    // Sadece kesinlikle yetişkin içeriği — normal filmleri ETKILEMEZ
    'xxx', 'porn', 'nsfw', 'nude', 'naked', 'hentai', 'fetish',
    'onlyfans', 'brazzers', 'bangbros', 'realitykings',
    'xvideo', 'xhamster', 'youporn', 'pornhub', 'redtube',
    'erotik film', 'erotik kanal', 'sex kanalı', 'canlı seks',
    'adult film', 'adult channel', 'adult tv', 'adult live',
    'xxx live', 'sex live', 'xxx movies', 'xxx video',
    'film porno', 'video xxx', 'film xxx',
    'erotik filmi', 'seks filmi',
  ];

  /// Yetişkin içerik gösterimi (varsayılan: false = gizli).
  static Future<bool> loadAdultContent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showAdultContentKey) ?? false;
  }

  static Future<void> saveAdultContent(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAdultContentKey, show);
  }

  /// Metnin yetişkin içeriği içerip içermediğini kontrol eder.
  static bool isAdultContent(String text) {
    final lower = text.toLowerCase();
    return adultKeywords.any((keyword) => lower.contains(keyword));
  }

  /// Kaydedilmiş bağlantı hızını döndürür (varsayılan: Normal 1 sn).
  static Future<PlayerSpeed> loadSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_speedIndexKey) ?? 3; // Varsayılan: Dengeli (2.0s)
    if (idx < 0 || idx >= PlayerSpeed.options.length) return PlayerSpeed.options[3];
    return PlayerSpeed.options[idx];
  }

  static Future<void> saveSpeed(PlayerSpeed speed) async {
    final prefs = await SharedPreferences.getInstance();
    final idx = PlayerSpeed.options.indexWhere((o) => o.bufferSecs == speed.bufferSecs);
    await prefs.setInt(_speedIndexKey, idx < 0 ? 1 : idx);
  }

  /// Kaydedilmiş ses seviyesini döndürür (varsayılan 1.0 = maksimum).
  /// Eski kayıtlı 0 değerini otomatik düzelt.
  static Future<double> loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    var v = prefs.getDouble(_volumeKey);
    if (v == null || v < 0.1) {
      // Sıfır veya çok düşük ise — maksimuma ayarla
      v = 1.0;
      await prefs.setDouble(_volumeKey, v);
    }
    return v.clamp(0.0, 1.0);
  }

  static Future<void> saveVolume(double volume) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, volume.clamp(0.0, 1.0));
  }
}
