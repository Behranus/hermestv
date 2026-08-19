import 'package:flutter/material.dart';
import 'package:iptv_player/services/open_subtitles_service.dart';

/// OpenSubtitles altyazı arama sayfası.
///
/// Film/dizi adına göre arama yapar, sonuçları listeler ve kullanıcının
/// seçtiği altyazıyı SRT olarak indirir.
class SubtitleSearchScreen extends StatefulWidget {
  const SubtitleSearchScreen({
    super.key,
    required this.movieName,
    this.imdbId,
    this.isMovie = true,
  });

  final String movieName;
  final String? imdbId;
  final bool isMovie;

  @override
  State<SubtitleSearchScreen> createState() => _SubtitleSearchScreenState();
}

class _SubtitleSearchScreenState extends State<SubtitleSearchScreen> {
  final _searchController = TextEditingController();
  String _selectedLanguage = 'tr,en';
  List<SubtitleResult> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _downloadingId;

  // Popüler diller
  static const _languages = [
    {'code': 'tr,en', 'label': '🇹🇷 Türkçe + 🇬🇧 İngilizce'},
    {'code': 'tr', 'label': '🇹🇷 Sadece Türkçe'},
    {'code': 'en', 'label': '🇬🇧 Sadece İngilizce'},
    {'code': 'de', 'label': '🇩🇪 Almanca'},
    {'code': 'fr', 'label': '🇫🇷 Fransızca'},
    {'code': 'es', 'label': '🇪🇸 İspanyolca'},
    {'code': 'ar', 'label': '🇸🇦 Arapça'},
    {'code': 'tr,en,de,fr,es', 'label': '🌍 Tüm Diller'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.movieName;
    // Otomatik ara
    Future.microtask(_search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _results = [];
      _searched = true;
    });

    final results = await OpenSubtitlesService.search(
      query: query,
      imdbId: widget.imdbId,
      languages: _selectedLanguage,
      limit: 15,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  Future<void> _downloadAndUse(SubtitleResult sub) async {
    setState(() => _downloadingId = sub.id.toString());

    final content = await OpenSubtitlesService.downloadSubtitleContent(
      fileId: sub.id.toString(),
    );

    if (!mounted) return;

    setState(() => _downloadingId = null);

    if (content == null || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Altyazı indirilemedi')),
      );
      return;
    }

    // Altyazı içeriğini geri döndür (VOD oynatıcı yükleyecek)
    Navigator.of(context).pop(SubtitleDownloadResult(
      content: content,
      fileName: sub.fileName,
      format: sub.subtitleFormat,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Altyazı Ara', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Dil seçici
          PopupMenuButton<String>(
            icon: const Icon(Icons.language, color: Colors.white70),
            onSelected: (lang) {
              setState(() => _selectedLanguage = lang);
              _search();
            },
            itemBuilder: (_) => _languages
                .map((l) => PopupMenuItem(
                      value: l['code'],
                      child: Text(
                        l['label']!,
                        style: TextStyle(
                          color: l['code'] == _selectedLanguage
                              ? theme.colorScheme.primary
                              : Colors.white,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Arama kutusu
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Film/dizi adı yazın...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                        )
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
          ),

          // Dil rozeti
          if (_searched && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.language, color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Dil: ${_selectedLanguage.replaceAll(',', ', ')}  •  ${_results.length} sonuç',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Sonuçlar
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_searched ? Icons.subtitles_off : Icons.subtitles,
                                color: Colors.white24, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _searched
                                  ? 'Altyazı bulunamadı'
                                  : 'Film/dizi adı ile arama yapın',
                              style: const TextStyle(color: Colors.white38, fontSize: 16),
                            ),
                            if (_searched) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() => _selectedLanguage = 'tr,en,de,fr,es');
                                  _search();
                                },
                                child: const Text('Tüm dillerde ara',
                                    style: TextStyle(color: Colors.amber)),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final sub = _results[i];
                          final isDownloading = _downloadingId == sub.id.toString();

                          return Card(
                            color: Colors.white.withValues(alpha: 0.06),
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: _langFlag(sub.language),
                              title: Text(
                                sub.movieName ?? sub.fileName,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    sub.languageName,
                                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sub.subtitleFormat,
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11),
                                  ),
                                  if (sub.rating != null) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.star, color: Colors.amber, size: 12),
                                    Text(
                                      '${sub.rating}',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                  if (sub.season != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'S${sub.season}E${sub.episode ?? '?'}',
                                      style: const TextStyle(
                                          color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: isDownloading
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.amber))
                                  : IconButton(
                                      onPressed: () => _downloadAndUse(sub),
                                      icon: const Icon(Icons.download,
                                          color: Colors.amber, size: 22),
                                      tooltip: 'İndir ve kullan',
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _langFlag(String code) {
    const flags = {
      'tr': '🇹🇷',
      'en': '🇬🇧',
      'de': '🇩🇪',
      'fr': '🇫🇷',
      'es': '🇪🇸',
      'it': '🇮🇹',
      'pt': '🇵🇹',
      'ru': '🇷🇺',
      'ar': '🇸🇦',
      'ja': '🇯🇵',
      'ko': '🇰🇷',
      'zh': '🇨🇳',
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(flags[code] ?? '🌐', style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

/// Altyazı indirme sonucu.
class SubtitleDownloadResult {
  final String content;
  final String fileName;
  final String format;

  const SubtitleDownloadResult({
    required this.content,
    required this.fileName,
    required this.format,
  });
}
