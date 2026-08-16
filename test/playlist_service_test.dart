import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/services/m3u_parser.dart';
import 'package:iptv_player/services/playlist_service.dart';

void main() {
  group('PlaylistService.decodeContent', () {
    test('UTF-8 içeriği çözer', () {
      final bytes = utf8.encode('#EXTINF:-1,Türkçe Kanal\nhttp://x/y.m3u8');
      expect(PlaylistService.decodeContent(bytes), contains('Türkçe Kanal'));
    });

    test('UTF-8 olmayan (Latin-1) içeriği çözer ve çökmez', () {
      // 'Kanal Özel' latin1 baytları: Ö = 0xD6
      final bytes = [
        ...'#EXTINF:-1,Kanal '.codeUnits,
        0xD6,
        ...'zel\n'.codeUnits,
        ...'http://x/y.m3u8\n'.codeUnits,
      ];
      final text = PlaylistService.decodeContent(bytes);
      expect(text, contains('Kanal'));
      // Latin-1 çözümünde Ö doğru görünür.
      expect(text, contains('\u00D6zel'));
    });

    test('BOM işaretini kaldırır', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('#EXTM3U\n#EXTINF:-1,Kanal\nhttp://x/y.m3u8\n')];
      final text = PlaylistService.decodeContent(bytes);
      expect(text.startsWith('\uFEFF'), isFalse);
    });
  });

  group('Latin-1 kaynaklı içerik uçtan uca', () {
    test('bozuk UTF-8 baytlı M3U kanalları ayrıştırılır', () {
      final bytes = [
        ...'#EXTM3U\n'.codeUnits,
        ...'#EXTINF:-1 tvg-id="trt" group-title="T'.codeUnits, // 'Türkçe' başlangıcı
        0xFC, // ü (latin1)
        ...'rke",TRT 1\n'.codeUnits,
        ...'http://stream.example/trt1.m3u8\n'.codeUnits,
      ];
      final text = PlaylistService.decodeContent(bytes);
      final channels = M3uParser.parse(text);
      expect(channels.length, 1);
      expect(channels[0].name, 'TRT 1');
      expect(channels[0].group, 'Türke'); // latin1'de ü=0xFC → ü
    });
  });
}
