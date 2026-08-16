import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/models/vod.dart';

void main() {
  group('VodMovie.fromJson', () {
    test('standart alanları ayrıştırır', () {
      final m = VodMovie.fromJson({
        'stream_id': 42,
        'name': 'Inception',
        'stream_icon': 'http://x/inception.jpg',
        'rating': '8.8',
        'category_id': '5',
      });
      expect(m.id, 42);
      expect(m.name, 'Inception');
      expect(m.poster, 'http://x/inception.jpg');
      expect(m.rating, '8.8');
      expect(m.categoryId, '5');
    });

    test('boş puanı null yapar', () {
      final m = VodMovie.fromJson({'stream_id': 1, 'name': 'X', 'rating': ''});
      expect(m.rating, isNull);
    });
  });

  group('VodSeries.fromJson', () {
    test('kapak ve puanı ayrıştırır', () {
      final s = VodSeries.fromJson({
        'series_id': 7,
        'name': 'Breaking Bad',
        'cover': 'http://x/bb.jpg',
        'rating': '9.5',
        'plot': 'Bir kimya öğretmeninin hikayesi',
        'category_id': '2',
      });
      expect(s.id, 7);
      expect(s.name, 'Breaking Bad');
      expect(s.cover, 'http://x/bb.jpg');
      expect(s.rating, '9.5');
      expect(s.plot, 'Bir kimya öğretmeninin hikayesi');
    });

    test('kapak yoksa backdrop kullanılır', () {
      final s = VodSeries.fromJson({
        'series_id': 7,
        'name': 'BB',
        'backdrop_path': ['http://x/bg1.jpg', 'http://x/bg2.jpg'],
      });
      expect(s.cover, 'http://x/bg1.jpg');
    });
  });

  group('SeriesInfo.fromJson', () {
    test('sezonları ve bölümleri ayrıştırır', () {
      final info = SeriesInfo.fromJson({
        'info': {
          'name': 'BB',
          'plot': 'Plot',
          'genre': 'Drama, Crime',
          'releaseDate': '2008-01-20',
          'rating': '9.5',
          'backdrop_path': ['http://x/bg.jpg'],
        },
        'seasons': [
          {
            'season_number': '1',
            'name': 'Season 1',
            'episodes': [
              {
                'id': 101,
                'episode_num': '1',
                'title': 'Pilot',
                'info': {'duration': '00:58:00', 'plot': 'İlk bölüm', 'release_date': '2008-01-20'},
              },
              {
                'id': 102,
                'episode_num': '2',
                'title': 'Cat\'s in the Bag',
                'info': {'duration': '00:47:00'},
              },
            ],
          },
          {
            'season_number': '2',
            'name': 'Season 2',
            'episodes': [
              {'id': 201, 'episode_num': '1', 'title': 'No Más'},
            ],
          },
        ],
      });

      expect(info.seasons.length, 2);
      expect(info.seasons[0].number, 1);
      expect(info.seasons[0].episodes.length, 2);
      expect(info.seasons[0].episodes[0].title, 'Pilot');
      expect(info.seasons[0].episodes[0].duration, '00:58:00');
      expect(info.seasons[0].episodes[0].displayNumber, '1');
      expect(info.genre, 'Drama, Crime');
      expect(info.year, '2008');
      expect(info.rating, '9.5');
      expect(info.backdrops, ['http://x/bg.jpg']);
    });

    test('boş yanıt boş sezon döndürür', () {
      final info = SeriesInfo.fromJson({});
      expect(info.seasons, isEmpty);
    });
  });
}
