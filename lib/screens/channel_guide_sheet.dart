import 'package:flutter/material.dart';
import 'package:iptv_player/models/channel.dart';
import 'package:iptv_player/models/epg_program.dart';
import 'package:iptv_player/state/app_state.dart';

/// Kanalın EPG program çizelgesini gösteren alt sayfa.
Future<void> showChannelGuide(
  BuildContext context, {
  required Channel channel,
  required AppState state,
}) async {
  final schedule = state.schedule(channel);
  if (schedule == null || schedule.isEmpty) return;

  final now = DateTime.now();
  // Şu an + önümüzdeki programlar (en fazla 24 saat).
  final upcoming = schedule.where((p) => p.stop.isAfter(now)).toList();
  final list = upcoming.take(24).toList();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        channel.name,
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('Bu kanal için yaklaşan program yok.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final p = list[i];
                          return _ProgramTile(program: p, isNow: p.isNow);
                        },
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _ProgramTile extends StatelessWidget {
  const _ProgramTile({required this.program, required this.isNow});

  final EpgProgram program;
  final bool isNow;

  String _time(DateTime t) {
    final local = t.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final start = _time(program.start);
    final stop = _time(program.stop);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isNow ? colors.primaryContainer.withValues(alpha: 0.5) : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNow ? colors.primary : Colors.transparent,
          width: isNow ? 1.5 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isNow)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'ŞİMDİ',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.onPrimary),
                  ),
                ),
              Text(
                '$start – $stop',
                style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (program.category != null) ...[
                const Spacer(),
                Text(
                  program.category!,
                  style: theme.textTheme.labelSmall?.copyWith(color: colors.secondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            program.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: isNow ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          if (program.description != null && program.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              program.description!,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
