import 'package:flutter_test/flutter_test.dart';
import 'package:hermestv/services/epg_service.dart';

/// DateTime'i XMLTV zaman biçimine çevirir: `yyyyMMddHHmmss +0300`.
String _xmltv(DateTime utc) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${utc.year}${two(utc.month)}${two(utc.day)}${two(utc.hour)}${two(utc.minute)}00 +0000';
}

void main() {
  group('EpgService.parseXmltvTime', () {
    test('ofsetli zamanı UTC\'ye çevirir', () {
      // 2024-01-01 23:00:00 +0300 → UTC 20:00
      final t = EpgService.parseXmltvTime('20240101230000 +0300');
      expect(t.isUtc, isTrue);
      expect(t.year, 2024);
      expect(t.month, 1);
      expect(t.day, 1);
      expect(t.hour, 20);
      expect(t.minute, 0);
    });

    test('negatif ofseti işler', () {
      // 2024-01-01 01:00:00 -0500 → UTC 06:00
      final t = EpgService.parseXmltvTime('20240101010000 -0500');
      expect(t.hour, 6);
    });
  });

  group('EpgService.parse', () {
    test('kanal ve programları ayrıştırır', () {
      final now = DateTime.now().toUtc();
      final start = now.subtract(const Duration(minutes: 30));
      final stop = now.add(const Duration(minutes: 30));

      final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="TRT1.tr">
    <display-name>TRT 1</display-name>
    <icon src="http://x/trt1.png"/>
  </channel>
  <programme start="${_xmltv(start)}" stop="${_xmltv(stop)}" channel="TRT1.tr">
    <title lang="tr">Haber</title>
    <desc lang="tr">Günün haberleri</desc>
    <category lang="tr">Haber</category>
  </programme>
  <programme start="${_xmltv(stop)}" stop="${_xmltv(now.add(const Duration(hours: 1)))}" channel="TRT1.tr">
    <title lang="tr">Dizi</title>
  </programme>
</tv>
''';
      final epg = EpgService.parse(xml);
      expect(epg.channelCount, 1);
      final programs = epg.programs['TRT1.tr']!;
      expect(programs.length, 2);
      expect(programs[0].title, 'Haber');
      expect(programs[0].description, 'Günün haberleri');
      expect(programs[0].category, 'Haber');
      expect(programs[1].title, 'Dizi');
      // Zaman sırasına göre sıralı.
      expect(programs[0].start.isBefore(programs[1].start), isTrue);
      // İsim eşleme tablosu dolu.
      expect(epg.channelNames['trt 1'], 'TRT1.tr');
      // Şu an oynayan program.
      expect(epg.nowPlaying(tvgId: 'TRT1.tr')?.title, 'Haber');
    });

    test('geçmiş/gelecek penceresi dışındaki programlar atılır', () {
      final old = DateTime.now().toUtc().subtract(const Duration(days: 10));
      final xml = '''
<tv>
  <channel id="x.tr"><display-name>X</display-name></channel>
  <programme start="${_xmltv(old)}" stop="${_xmltv(old.add(const Duration(hours: 1)))}" channel="x.tr">
    <title>Eski</title>
  </programme>
</tv>
''';
      expect(() => EpgService.parse(xml), throwsA(anything));
    });

    test('geçersiz XML format hatası fırlatır', () {
      expect(() => EpgService.parse('bu xml değil'), throwsA(anything));
    });
  });
}
