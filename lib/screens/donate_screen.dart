import 'package:flutter/material.dart';
import 'package:hermestv/l10n/locale_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

/// Donate / Destek ekrani - modern Zorin OS tema
class DonateScreen extends StatelessWidget {
  const DonateScreen({super.key});

  static const String _githubUsername = 'Behranus';
  static const String _sponsorUrl = 'https://github.com/sponsors/$_githubUsername';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Column(
        children: [
          // Ust bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              border: Border(
                bottom: BorderSide(color: colors.outline.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE54D6E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.favorite_rounded, color: Color(0xFFE54D6E), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  context.watch<LocaleProvider>().loc.support,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),

          // Icerik
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Baslik karti
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary.withValues(alpha: 0.2),
                        const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3C8AFF), Color(0xFF6C5CE7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3C8AFF).withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.watch<LocaleProvider>().loc.supportTitle,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'HermesTV tamamen ucretsiz ve reklamsizdir.\nGelistirmeye devam etmemiz icin destekleriniz cok degerli.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // GitHub Sponsors karti
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6e40c9).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.code_rounded, color: Color(0xFF6e40c9), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('GitHub Sponsors',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('Acik kaynak gelistirmeyi destekle',
                                      style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // GitHub profil kutusu
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Color(0xFF6e40c9),
                                child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_githubUsername,
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.onSurface)),
                                    Text(_sponsorUrl,
                                        style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: colors.onSurfaceVariant),
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Sponsor ol butonu
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _sponsorUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Link kopyalandi: $_sponsorUrl'),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: Text(context.watch<LocaleProvider>().loc.supportOnGithub),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6e40c9),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _sponsorUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Link kopyalandi: $_sponsorUrl'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: Text(context.watch<LocaleProvider>().loc.copyLink),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Bu uygulamayi begendiysemiz, bir yildiz vermeyi unutmayin!\n'
                  'Tum destekleriniz gelecek surumler icin motivasyon kaynagi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
