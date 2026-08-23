import 'package:flutter_test/flutter_test.dart';
import 'package:hermestv/services/m3u_parser.dart';

void main() {
  group('M3uParser', () {
    test('tam öznitelikli kanalları ayrıştırır', () {
      const content = '''
#EXTM3U
#EXTINF:-1 tvg-id="trt1" tvg-name="TRT 1" tvg-logo="http://x/trt1.png" group-title="Türkiye",TRT 1
http://stream.example/trt1.m3u8
#EXTINF:-1 tvg-id="bein" group-title="Spor",beIN Sports
http://stream.example/bein.m3u8
''';

      final channels = M3uParser.parse(content);

      expect(channels.length, 2);
      expect(channels[0].name, 'TRT 1');
      expect(channels[0].url, 'http://stream.example/trt1.m3u8');
      expect(channels[0].group, 'Türkiye');
      expect(channels[0].logo, 'http://x/trt1.png');
      expect(channels[0].tvgId, 'trt1');
      expect(channels[0].tvgName, 'TRT 1');

      expect(channels[1].name, 'beIN Sports');
      expect(channels[1].group, 'Spor');
    });

    test('grup adı boşsa Diğer olarak gösterilir', () {
      const content = '''
#EXTM3U
#EXTINF:-1,Kanal X
http://stream.example/x.m3u8
''';
      final channels = M3uParser.parse(content);
      expect(channels.single.displayGroup, 'Diğer');
    });

    test('adı boş kanallarda URL\'den isim türetilir', () {
      const content = '''
#EXTM3U
#EXTINF:-1,
http://stream.example/trt1.m3u8
''';
      final channels = M3uParser.parse(content);
      expect(channels.single.name, 'trt1');
    });

    test('VLC ve diğer etiket satırlarını atlar', () {
      const content = '''
#EXTM3U
#EXTINF:-1 group-title="G",Kanal 1
#EXTVLCOPT:http-referrer=http://ref.example
#EXTGRP:Grup
http://stream.example/1.m3u8
#EXTINF:-1 group-title="G",Kanal 2
http://stream.example/2.m3u8
''';
      final channels = M3uParser.parse(content);
      expect(channels.length, 2);
    });

    test('boş playlist kanal döndürmez', () {
      expect(M3uParser.parse(''), isEmpty);
      expect(M3uParser.parse('#EXTM3U\n# bazı yorumlar\n'), isEmpty);
    });
  });

  group('M3uParser.parseAsync', () {
    test('kademeli ayrıştırma normal parse ile aynı sonucu verir', () async {
      final content = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 2500; i++) {
        content.writeln('#EXTINF:-1 tvg-id="k$i" group-title="Grup",Kanal $i');
        content.writeln('http://stream.example/$i.m3u8');
      }

      final expected = M3uParser.parse(content.toString());
      final actual = await M3uParser.parseAsync(content.toString());
      expect(actual.length, expected.length);
      expect(actual.length, 2500);
      expect(actual.first.name, 'Kanal 0');
      expect(actual.last.name, 'Kanal 2499');
    });

    test('ilerleme bildirir ve toplam sayıyı sonunda verir', () async {
      final content = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 2000; i++) {
        content.writeln('#EXTINF:-1,K$i');
        content.writeln('http://s/$i.m3u8');
      }
      final calls = <int>[];
      final channels = await M3uParser.parseAsync(
        content.toString(),
        onProgress: calls.add,
      );
      expect(channels.length, 2000);
      expect(calls.isNotEmpty, true);
      expect(calls.last, 2000);
    });

    test('boş içerik boş liste döner', () async {
      expect(await M3uParser.parseAsync(''), isEmpty);
    });
  });
}
