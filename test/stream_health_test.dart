import 'package:flutter_test/flutter_test.dart';
import 'package:hermestv/services/stream_player.dart';

void main() {
  group('streamHealthFromMetrics — plugin metrik eşlemesi', () {
    test('tam metrik haritası doğru çevrilir', () {
      final h = streamHealthFromMetrics({
        'positionMs': 120000,
        'bufferedMs': 14000,
        'liveOffsetMs': 12000,
        'reconnectCount': 3,
      });

      expect(h.buffered, const Duration(seconds: 14));
      expect(h.liveOffset, const Duration(seconds: 12));
      expect(h.reconnectCount, 3);
    });

    test('C.TIME_UNSET (negatif) canlı kenar mesafesini bilinmiyor yapar', () {
      // ExoPlayer canlı değilken C.TIME_UNSET = -9223372036854775807 döner.
      final h = streamHealthFromMetrics({
        'bufferedMs': 5000,
        'liveOffsetMs': -9223372036854775807,
        'reconnectCount': 0,
      });

      expect(h.liveOffset, isNull);
      expect(h.buffered, const Duration(seconds: 5));
    });

    test('sıfır canlı ofset "canlı kenarda" olarak korunur, bilinmiyor sayılmaz', () {
      final h = streamHealthFromMetrics({'liveOffsetMs': 0});
      expect(h.liveOffset, Duration.zero);
    });

    test('eksik alanlar güvenli varsayılanlara düşer', () {
      final h = streamHealthFromMetrics(const {});

      expect(h.buffered, Duration.zero);
      expect(h.liveOffset, isNull);
      expect(h.reconnectCount, 0);
    });

    test('yeniden bağlanma sayısı negatif ofsetten bağımsız taşınır', () {
      final h = streamHealthFromMetrics({
        'liveOffsetMs': -9223372036854775807,
        'reconnectCount': 7,
      });

      expect(h.liveOffset, isNull);
      expect(h.reconnectCount, 7);
    });

    test('varsayılan StreamHealth güvenli — sıfır tampon, bilinmeyen canlı ofset', () {
      const h = StreamHealth();
      expect(h.buffered, Duration.zero);
      expect(h.liveOffset, isNull);
      expect(h.reconnectCount, 0);
    });
  });
}
