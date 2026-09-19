import 'package:flutter/material.dart';
import 'package:hermestv/services/stream_player.dart';

/// Tampon sağlığına göre renk: 8 sn ve üzeri sağlıklı (yeşil),
/// 3 sn ve üzeri zayıf (sarı), altı kritik (kırmızı).
Color bufferHealthColor(int bufferedSeconds) {
  if (bufferedSeconds >= 8) return const Color(0xFF4CAF50);
  if (bufferedSeconds >= 3) return const Color(0xFFFFB300);
  return const Color(0xFFE53935);
}

/// Kalıcı yayın sağlığı göstergesi: tampon süresi, canlı kenardan uzaklık ve
/// yeniden bağlanma sayısı. Oynatıcının `health` akışını kendi içinde dinler,
/// böylece saniyede bir tüm ekranı yeniden çizmez.
class StreamHealthBadge extends StatelessWidget {
  const StreamHealthBadge({super.key, required this.healthStream});

  final Stream<StreamHealth> healthStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<StreamHealth>(
      stream: healthStream,
      initialData: const StreamHealth(),
      builder: (context, snap) {
        final h = snap.data ?? const StreamHealth();
        final bufferedSecs = h.buffered.inSeconds;
        final live = h.liveOffset;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('stream-health-dot'),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: bufferHealthColor(bufferedSecs),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text('${bufferedSecs}s tampon',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
              // Canlı kenar mesafesi — bilinmiyorsa uydurma sayı yerine "—"
              Text('  ·  canlı ${live == null ? '—' : '−${live.inSeconds}s'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
              Text('  ·  ⟳ ${h.reconnectCount}',
                  style: TextStyle(
                    color: h.reconnectCount > 0
                        ? const Color(0xFFFFB300)
                        : Colors.white70,
                    fontSize: 11,
                  )),
            ],
          ),
        );
      },
    );
  }
}

/// Göstergenin yerleşimi ve görünürlük kuralı: yalnızca canlı yayında, hata
/// yokken ve kanal paneli kapalıyken görünür. Aksi halde hiç yer kaplamaz.
class StreamHealthOverlay extends StatelessWidget {
  const StreamHealthOverlay({
    super.key,
    required this.healthStream,
    required this.isLive,
    required this.hasError,
    required this.panelOpen,
  });

  final Stream<StreamHealth> healthStream;
  final bool isLive;
  final bool hasError;
  final bool panelOpen;

  @override
  Widget build(BuildContext context) {
    if (!isLive || hasError || panelOpen) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          // TV overscan payı — ekranın diğer HUD'larıyla aynı 16px
          padding: const EdgeInsets.fromLTRB(16, 12, 0, 0),
          child: IgnorePointer(
            child: StreamHealthBadge(healthStream: healthStream),
          ),
        ),
      ),
    );
  }
}
