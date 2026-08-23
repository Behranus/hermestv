import 'package:flutter_test/flutter_test.dart';
import 'package:hermestv/models/vod.dart';
import 'package:hermestv/services/xtream_service.dart';

void main() {
  group('Xtream VOD URL uzantı mantığı', () {
    final creds = XtreamCredentials(
      server: 'https://panel.example.com',
      username: 'user',
      password: 'pass',
    );

    test('bilinen uzantı (mp4) kullanılır — her zaman m3u8 değil', () {
      final url = XtreamService.movieUrl(creds, 123, containerExtension: 'mp4');
      expect(url, 'https://panel.example.com/movie/user/pass/123.mp4');
    });

    test('m3u8 uzantısı korunur', () {
      final url = XtreamService.movieUrl(creds, 123, containerExtension: 'm3u8');
      expect(url, 'https://panel.example.com/movie/user/pass/123.m3u8');
    });

    test('uzantı yoksa m3u8 varsayılır', () {
      final url = XtreamService.movieUrl(creds, 123);
      expect(url, 'https://panel.example.com/movie/user/pass/123.m3u8');
    });

    test('boş/güvensiz uzantılar m3u8\'e düşer', () {
      expect(
        XtreamService.movieUrl(creds, 1, containerExtension: ''),
        'https://panel.example.com/movie/user/pass/1.m3u8',
      );
      expect(
        XtreamService.movieUrl(creds, 1, containerExtension: '../etc'),
        'https://panel.example.com/movie/user/pass/1.m3u8',
      );
    });

    test('dizi bölüm URL\'si de uzantıyı kullanır', () {
      final url = XtreamService.episodeUrl(creds, 99, containerExtension: 'mkv');
      expect(url, 'https://panel.example.com/series/user/pass/99.mkv');
    });

    test('VodMovie container_extension alanını ayrıştırır', () {
      final movie = VodMovie.fromJson({
        'stream_id': 42,
        'name': 'Test Filmi',
        'container_extension': 'mkv',
        'rating': '7.2',
      });
      expect(movie.id, 42);
      expect(movie.containerExtension, 'mkv');
    });

    test('VodMovie container_extension yoksa null olur', () {
      final movie = VodMovie.fromJson({'stream_id': 42, 'name': 'Test'});
      expect(movie.containerExtension, isNull);
    });
  });
}
