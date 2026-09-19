import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermestv/services/stream_player.dart';
import 'package:hermestv/widgets/stream_health_badge.dart';

/// Göstergeyi gerçek widget ağacında, dışarıdan beslenen bir akışla çalıştırır.
Future<void> pumpHealth(
  WidgetTester tester,
  StreamHealth health, {
  bool isLive = true,
  bool hasError = false,
  bool panelOpen = false,
}) async {
  final ctrl = StreamController<StreamHealth>.broadcast();
  addTearDown(ctrl.close);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            StreamHealthOverlay(
              healthStream: ctrl.stream,
              isLive: isLive,
              hasError: hasError,
              panelOpen: panelOpen,
            ),
          ],
        ),
      ),
    ),
  );
  ctrl.add(health);
  await tester.pump();
}

Color dotColor(WidgetTester tester) {
  final dot = tester.widget<Container>(find.byKey(const ValueKey('stream-health-dot')));
  return (dot.decoration! as BoxDecoration).color!;
}

void main() {
  group('StreamHealthBadge içeriği', () {
    testWidgets('tampon, canlı kenar ve yeniden bağlanma metinleri gösterilir', (tester) async {
      await pumpHealth(tester, const StreamHealth(
        buffered: Duration(seconds: 12),
        liveOffset: Duration(seconds: 9),
        reconnectCount: 3,
      ));

      expect(find.textContaining('12s tampon'), findsOneWidget);
      expect(find.textContaining('canlı −9s'), findsOneWidget);
      expect(find.textContaining('⟳ 3'), findsOneWidget);
    });

    testWidgets('canlı ofset bilinmiyorsa uydurma sayı yerine "—" gösterilir', (tester) async {
      await pumpHealth(tester, const StreamHealth(
        buffered: Duration(seconds: 12),
        liveOffset: null,
      ));

      expect(find.textContaining('canlı —'), findsOneWidget);
      // "canlı −N s" biçiminde hiçbir sayı basılmamalı
      expect(find.textContaining('canlı −'), findsNothing);
    });

    testWidgets('ofset sıfırsa "canlı −0s" olarak gösterilir, "—" değil', (tester) async {
      await pumpHealth(tester, const StreamHealth(liveOffset: Duration.zero));

      expect(find.textContaining('canlı −0s'), findsOneWidget);
      expect(find.textContaining('canlı —'), findsNothing);
    });
  });

  group('Tampon sağlığı eşikleri (nokta rengi)', () {
    testWidgets('8 sn ve üzeri yeşil', (tester) async {
      await pumpHealth(tester, const StreamHealth(buffered: Duration(seconds: 8)));
      expect(dotColor(tester), const Color(0xFF4CAF50));
    });

    testWidgets('7 sn sarı', (tester) async {
      await pumpHealth(tester, const StreamHealth(buffered: Duration(seconds: 7)));
      expect(dotColor(tester), const Color(0xFFFFB300));
    });

    testWidgets('3 sn sarı (alt sınır)', (tester) async {
      await pumpHealth(tester, const StreamHealth(buffered: Duration(seconds: 3)));
      expect(dotColor(tester), const Color(0xFFFFB300));
    });

    testWidgets('2 sn kırmızı', (tester) async {
      await pumpHealth(tester, const StreamHealth(buffered: Duration(seconds: 2)));
      expect(dotColor(tester), const Color(0xFFE53935));
    });

    testWidgets('tampon yoksa kırmızı', (tester) async {
      await pumpHealth(tester, const StreamHealth());
      expect(dotColor(tester), const Color(0xFFE53935));
    });
  });

  group('Yeniden bağlanma sayacı görünümü', () {
    testWidgets('sıfırken nötr (beyaz) ve "⟳ 0"', (tester) async {
      await pumpHealth(tester, const StreamHealth(reconnectCount: 0));

      expect(find.textContaining('⟳ 0'), findsOneWidget);
      final t = tester.widget<Text>(find.textContaining('⟳ 0'));
      expect(t.style!.color, Colors.white70);
    });

    testWidgets('sıfırdan büyükse uyarı renginde', (tester) async {
      await pumpHealth(tester, const StreamHealth(reconnectCount: 5));

      expect(find.textContaining('⟳ 5'), findsOneWidget);
      final t = tester.widget<Text>(find.textContaining('⟳ 5'));
      expect(t.style!.color, const Color(0xFFFFB300));
    });
  });

  group('Görünürlük kuralı', () {
    testWidgets('canlı, hatasız ve panel kapalıyken görünür', (tester) async {
      await pumpHealth(tester, const StreamHealth(buffered: Duration(seconds: 10)));
      expect(find.byType(StreamHealthBadge), findsOneWidget);
    });

    testWidgets('kanal paneli açıkken gizlenir', (tester) async {
      await pumpHealth(tester, const StreamHealth(buffered: Duration(seconds: 10)), panelOpen: true);
      expect(find.byType(StreamHealthBadge), findsNothing);
    });

    testWidgets('hata varken gizlenir', (tester) async {
      await pumpHealth(tester, const StreamHealth(buffered: Duration(seconds: 10)), hasError: true);
      expect(find.byType(StreamHealthBadge), findsNothing);
    });

    testWidgets('canlı değilken (VOD) gizlenir', (tester) async {
      await pumpHealth(tester, const StreamHealth(buffered: Duration(seconds: 10)), isLive: false);
      expect(find.byType(StreamHealthBadge), findsNothing);
    });
  });
}
