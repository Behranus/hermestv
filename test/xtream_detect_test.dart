import 'package:flutter_test/flutter_test.dart';
import 'package:hermestv/models/channel.dart';
import 'package:hermestv/services/xtream_service.dart';

void main() {
  group('tryParsePlaylistUrl', () {
    test('get.php adresinden kimlik bilgilerini çıkarır', () {
      final creds = XtreamService.tryParsePlaylistUrl(
        'http://sunucu:8080/get.php?username=user1&password=pass1&type=m3u_plus',
      );
      expect(creds, isNotNull);
      expect(creds!.server, 'http://sunucu:8080');
      expect(creds.username, 'user1');
      expect(creds.password, 'pass1');
    });

    test('player_api.php adresini tanır', () {
      final creds = XtreamService.tryParsePlaylistUrl(
        'https://portal.example.com/player_api.php?username=ali&password=sifre',
      );
      expect(creds, isNotNull);
      expect(creds!.server, 'https://portal.example.com');
      expect(creds.username, 'ali');
      expect(creds.password, 'sifre');
    });

    test('sıradan M3U adresini reddeder', () {
      expect(
        XtreamService.tryParsePlaylistUrl('https://ornek.com/playlist.m3u8'),
        isNull,
      );
      expect(
        XtreamService.tryParsePlaylistUrl('https://ornek.com/list.m3u'),
        isNull,
      );
    });

    test('eksik şifreli adresi reddeder', () {
      expect(
        XtreamService.tryParsePlaylistUrl(
          'http://sunucu:8080/get.php?username=user1&type=m3u_plus',
        ),
        isNull,
      );
    });

    test('geçersiz adresi reddeder', () {
      expect(XtreamService.tryParsePlaylistUrl(''), isNull);
      expect(XtreamService.tryParsePlaylistUrl('abc'), isNull);
    });
  });

  group('tryFromChannelUrls', () {
    test('live/kullanıcı/şifre adreslerinden kimlik çıkarır', () {
      final channels = [
        const Channel(
          name: 'TRT 1',
          url: 'http://sunucu:8080/live/mehmet/sifre123/123.m3u8',
        ),
        const Channel(
          name: 'Kanal D',
          url: 'http://sunucu:8080/live/mehmet/sifre123/456.ts',
        ),
      ];
      final creds = XtreamService.tryFromChannelUrls(channels);
      expect(creds, isNotNull);
      expect(creds!.server, 'http://sunucu:8080');
      expect(creds.username, 'mehmet');
      expect(creds.password, 'sifre123');
    });

    test('movie ve series adreslerini de tanır', () {
      final channels = [
        const Channel(
          name: 'Film',
          url: 'https://portal.com/movie/user/pass/99.m3u8',
        ),
      ];
      final creds = XtreamService.tryFromChannelUrls(channels);
      expect(creds, isNotNull);
      expect(creds!.server, 'https://portal.com');
      expect(creds.username, 'user');
      expect(creds.password, 'pass');
    });

    test('Xtream olmayan kanallarda null döner', () {
      final channels = [
        const Channel(name: 'Radyo', url: 'https://cdn.example.com/stream.mp3'),
        const Channel(name: 'Test', url: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'),
      ];
      expect(XtreamService.tryFromChannelUrls(channels), isNull);
    });

    test('boş listede null döner', () {
      expect(XtreamService.tryFromChannelUrls([]), isNull);
    });
  });
}
