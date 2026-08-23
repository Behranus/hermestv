import 'package:flutter_test/flutter_test.dart';
import 'package:hermestv/services/stream_player.dart';

void main() {
  group('SRT altyazı ayrıştırma', () {
    test('standart SRT zaman damgalarını çözer', () {
      const raw = '''
1
00:00:01,000 --> 00:00:04,000
Merhaba dünya

2
00:00:05,500 --> 00:00:08,000
İkinci satır
çok satırlı

''';
      final cues = parseSubtitleCues(raw);
      expect(cues, hasLength(2));
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(seconds: 4));
      expect(cues[0].text, 'Merhaba dünya');
      expect(cues[1].start, const Duration(seconds: 5, milliseconds: 500));
      expect(cues[1].text, 'İkinci satır\nçok satırlı');
    });

    test('Windows satır sonlarını (CRLF) kabul eder', () {
      const raw = '1\r\n00:00:00,100 --> 00:00:02,000\r\nTest\r\n';
      final cues = parseSubtitleCues(raw);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'Test');
    });
  });

  group('WebVTT altyazı ayrıştırma', () {
    test('nokta ayraçlı zamanları ve başlığı destekler', () {
      const raw = '''
WEBVTT

intro
00:00:01.000 --> 00:00:03.000 align:start position:0%
İlk parça

00:00:04.000 --> 00:00:06.000
İkinci parça
''';
      final cues = parseSubtitleCues(raw);
      expect(cues, hasLength(2));
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].text, 'İlk parça');
      expect(cues[1].end, const Duration(seconds: 6));
    });
  });

  group('Altyazı konumu', () {
    test('süresi 0 olan akışta (canlı) altyazı yok', () {
      // Canlı akışta pozisyon her zaman sıfır olacağı için altyazı
      // eşleşmemeli — parser'ın ürettiği aralıklarla doğrula.
      final cues = parseSubtitleCues('1\n00:00:10,000 --> 00:00:12,000\nGeç');
      final hasCueAtZero = cues.any((c) => Duration.zero >= c.start && Duration.zero <= c.end);
      expect(hasCueAtZero, isFalse);
    });
  });
}
