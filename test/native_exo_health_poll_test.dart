import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermestv/services/native_exo_stream_player.dart';
import 'package:hermestv/services/stream_player.dart';

/// Salınım penceresinde yalnızca bu salt-okunur çağrıların yapılması beklenir.
/// Oynatıcıyı yeniden hazırlayan/durduran (open/prepare/stop/seek/dispose)
/// hiçbir çağrı görünmemeli — aksi halde periyodik donma geri gelir.
const _readOnlyCalls = {
  'getPlaybackMetrics',
  'getPosition',
  'getAudioTracks',
  'getSubtitleTracks',
};

void main() {
  testWidgets('saniyelik sağlık sorgusu yalnızca salt-okunur çağrı yapar', (tester) async {
    const channel = MethodChannel('com.iptv.iptv_player/exo_player');
    final calls = <String>[];

    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'create':
          return <String, dynamic>{'textureId': 1, 'producerId': 1};
        case 'getPlaybackMetrics':
          return <String, dynamic>{
            'positionMs': 120000,
            'bufferedMs': 12000,
            'liveOffsetMs': 5000,
            'reconnectCount': 0,
          };
        case 'getPosition':
          return 120000;
        case 'getAudioTracks':
        case 'getSubtitleTracks':
          return <dynamic>[];
        default:
          return true;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final player = NativeExoStreamPlayer(bufferSecs: 1.0);
    final received = <StreamHealth>[];
    final sub = player.health.listen(received.add);
    addTearDown(sub.cancel);

    await player.open('http://example.com/live/kanal.m3u8');

    // Kurulum çağrılarını ayır — yalnızca oynatma sürerken ne olduğuna bakıyoruz.
    calls.clear();

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    // Sağlık akışı gerçekten besleniyor (poll → public stream)
    expect(received, isNotEmpty);
    expect(received.last.buffered, const Duration(milliseconds: 12000));
    expect(received.last.liveOffset, const Duration(seconds: 5));

    // 1 sn aralıkla en az 2-3 kez sorgulanmış olmalı
    expect(calls.where((m) => m == 'getPlaybackMetrics').length, greaterThanOrEqualTo(2));

    // Oynatıcıyı yeniden hazırlayan/durduran hiçbir yan etki yok
    expect(calls, isNot(contains('open')));
    expect(calls, isNot(contains('stop')));
    expect(calls, isNot(contains('seek')));
    expect(calls, isNot(contains('pause')));
    expect(calls, isNot(contains('dispose')));
    expect(calls.every(_readOnlyCalls.contains), isTrue,
        reason: 'Beklenmeyen (yan etkili) çağrı: ${calls.toSet().difference(_readOnlyCalls)}');

    await player.dispose();
  });
}
