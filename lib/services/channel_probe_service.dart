import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:hermestv/models/channel.dart';

/// Kanal adreslerini hızlıca canlı kontrol eder ve listeyi filtreler.
///
/// Ücretsiz kanal katalogları (iptv-org vb.) çok sayıda ölü/eriyen akış
/// içerir. Bunları listelemek hem "kanal açılmıyor" hissi yaratır hem de
/// 2GB RAM'li cihazlarda gereksiz bellek harcar. Bu servis, yalnızca o an
/// açılabilen kanalları döndürür; sonuç günlük önbelleklenir.
class ChannelProbeService {
  static const _timeout = Duration(seconds: 4);
  // 2GB RAM'li Box'larda 24 eşzamanlı bağlantı + sürekli bildirim rebuild
  // fırtınası yaratıp donmaya yol açabiliyordu. Daha küçük parti + parti
  // arası kısa duraklama: ağ ve UI üzerindeki baskı çok daha düşük.
  static const _batch = 8;
  static const _betweenBatches = Duration(milliseconds: 120);
  static const _ua =
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0 Mobile Safari/537.36';

  /// [channels] içinden o an açılabilenleri döndürür.
  ///
  /// Kanallar paralel partiler halinde kontrol edilir; her parti sonunda
  /// [onProgress](tamamlanan, toplam) çağrılır (ilerleme çubuğu için).
  static Future<List<Channel>> probeAlive(
    List<Channel> channels, {
    void Function(int done, int total)? onProgress,
  }) async {
    final alive = <Channel>[];
    final total = channels.length;
    if (total == 0) return alive;

    var done = 0;
    for (var i = 0; i < total; i += _batch) {
      final end = (i + _batch) > total ? total : (i + _batch);
      final batch = channels.sublist(i, end);
      final results = await Future.wait(batch.map(_check));
      for (var j = 0; j < batch.length; j++) {
        if (results[j]) alive.add(batch[j]);
      }
      done += batch.length;
      onProgress?.call(done, total);
      if (end < total) {
        // Ağ/soket baskısını düşür: her partiden sonra kısa nefes.
        await Future<void>.delayed(_betweenBatches);
      }
    }
    return alive;
  }

  /// Tek kanal: `Range: bytes=0-0` isteğiyle ilk yanıta bakar.
  /// 200/206 dönen (HLS listesi veya aralık desteği olan akış) canlı sayılır.
  static Future<bool> _check(Channel c) async {
    try {
      final resp = await http
          .get(
            Uri.parse(c.url),
            headers: {'Range': 'bytes=0-0', 'User-Agent': _ua},
          )
          .timeout(_timeout);
      return (resp.statusCode == 200 || resp.statusCode == 206) &&
          resp.bodyBytes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ---- Günlük önbellek (kanal listesi kodlama) ----

  static String encode(List<Channel> channels) => jsonEncode([
        for (final c in channels)
          {
            'name': c.name,
            'url': c.url,
            'group': c.group,
            'logo': c.logo,
            'tvgId': c.tvgId,
            'tvgName': c.tvgName,
            'sub': c.subtitleUrl,
          }
      ]);

  static List<Channel> decode(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map((m) => Channel(
                name: (m['name'] as String?) ?? '',
                url: (m['url'] as String?) ?? '',
                group: m['group'] as String?,
                logo: m['logo'] as String?,
                tvgId: m['tvgId'] as String?,
                tvgName: m['tvgName'] as String?,
                subtitleUrl: m['sub'] as String?,
              ))
          .where((c) => c.url.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
