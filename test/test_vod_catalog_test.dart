import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/services/test_vod_catalog.dart';

void main() {
  test('test VOD kataloğu boş değil ve kimlikler benzersiz', () {
    expect(TestVodCatalog.items, isNotEmpty);
    final ids = TestVodCatalog.items.map((d) => d.id).toSet();
    expect(ids.length, TestVodCatalog.items.length, reason: 'kimlikler benzersiz olmalı');
    // Kimlikler Xtream film kimlikleriyle çakışmasın (900000+).
    for (final d in TestVodCatalog.items) {
      expect(d.id, greaterThanOrEqualTo(900001));
      expect(d.id, lessThan(1000000));
    }
  });

  test('her öğenin oynatma adresi ve açıklaması var', () {
    for (final d in TestVodCatalog.items) {
      expect(d.url, isNotEmpty, reason: '${d.name} oynatma adresi olmalı');
      expect(d.url.startsWith('http'), isTrue, reason: '${d.name} geçerli URL olmalı');
      expect(d.plot, isNotEmpty);
      expect(d.rating, isNotEmpty);
    }
  });

  test('byId bilinen ve bilinmeyen kimlikler için doğru sonuç verir', () {
    expect(TestVodCatalog.byId(900001)?.name, 'Big Buck Bunny');
    expect(TestVodCatalog.byId(42), isNull);
  });
}
