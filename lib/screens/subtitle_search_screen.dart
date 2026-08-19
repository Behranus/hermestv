import 'package:flutter/material.dart';
import 'package:iptv_player/services/alternative_subtitles_service.dart';
import 'package:iptv_player/services/open_subtitles_service.dart';

/// Birleşik altyazı arama sayfası.
///
/// OpenSubtitles, YIFY Subtitles ve Subdl.com'u aynı anda sorgular,
/// sonuçları tek listede gösterir.
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

/// Tüm kaynaklardan gelen sonuçları tek tipte birleştirir.
class _UnifiedResult {
  final String id;
  final String fileName;
  final String language;
  final String languageName;
  final String source;
  final int? rating;
  final String? format;
  final String? movieName;
  final bool isOpenSubtitles;
  final AltSubtitleResult? altResult;
  final SubtitleResult? osResult;

  const _UnifiedResult({
    required this.id,
    required this.fileName,
    required this.language,
    required this.languageName,
    required this.source,
    this.rating,
    this.format,
    this.movieName,
    this.isOpenSubtitles = false,
    this.altResult,
    this.osResult,
  });
}

class _SubtitleSearchScreenState extends State<SubtitleSearchScreen> {
  final _searchController = TextEditingController();
  String _selectedLanguage = 'tr,en';
  List<_UnifiedResult> _results = [];
  bool _loading = false;
  bool _searched = false;
  String? _downloadingId;
  final Map<String, String> _sourceStatus = {};

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
      _sourceStatus.clear();
    });

    final allResults = <_UnifiedResult>[];

    // 1. OpenSubtitles
    setState(() => _sourceStatus['OpenSubtitles'] = 'Aranıyor...');
    final osFutures = [
      OpenSubtitlesService.search(
        query: query,
        imdbId: widget.imdbId,
        languages: _selectedLanguage,
        limit: 10,
      ),
    ];

    // 2. YIFY + Subdl paralel
    setState(() => _sourceStatus['YIFY'] = 'Aranıyor...');
    setState(() => _sourceStatus['Subdl'] = 'Aranıyor...');

    final altFutures = AlternativeSubtitlesService.searchAll(
      query: query,
      languages: _selectedLanguage,
      limit: 10,
    );

    // Tüm sonuçları bekle
    final osResults = await Future.wait(osFutures, eagerError: false);
    final altResults = await altFutures;

    if (!mounted) return;

    // OpenSubtitles sonuçlarını dönüştür
    for (final sub in osResults.first) {
      allResults.add(_UnifiedResult(
        id: 'os_${sub.id}',
        fileName: sub.fileName,
        language: sub.language,
        languageName: sub.languageName,
        source: 'OpenSubtitles',
        rating: sub.rating,
        format: sub.subtitleFormat,
        movieName: sub.movieName,
        isOpenSubtitles: true,
        osResult: sub,
      ));
    }

    // YIFY ve Subdl sonuçlarını dönüştür
    for (final sub in altResults) {
      allResults.add(_UnifiedResult(
        id: sub.id,
        fileName: sub.fileName,
        language: sub.language,
        languageName: sub.languageName,
        source: sub.source,
        format: sub.subtitleFormat,
        altResult: sub,
      ));
    }

    setState(() {
      _results = allResults;
      _loading = false;
      _sourceStatus['OpenSubtitles'] = '${osResults.first.length} sonuç';
      _sourceStatus['YIFY'] = altResults
          .where((r) => r.source == 'YIFY')
          .length
          .toString();
      _sourceStatus['Subdl'] = altResults
          .where((r) => r.source == 'Subdl')
          .length
          .toString();
    });
  }

  Future<void> _downloadAndUse(_UnifiedResult result) async {
    setState(() => _downloadingId = result.id);

    String? content;

    if (result.isOpenSubtitles && result.osResult != null) {
      final os = result.osResult!;
      content = await OpenSubtitlesService.downloadSubtitleContent(
        fileId: os.id.toString(),
        isRestApi: os.isRestApi,
        restDownloadUrl: os.isRestApi ? os.downloadUrl : null,
      );
    } else if (result.altResult != null) {
      content = await result.altResult!.download();
    }

    if (!mounted) return;
    setState(() => _downloadingId = null);

    if (content == null || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Altyazı indirilemedi')),
      );
      return;
    }

    Navigator.of(context).pop(SubtitleDownloadResult(
      content: content,
      fileName: result.fileName,
      format: result.format ?? 'SRT',
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

          // Kaynak durumları
          if (_searched && !_loading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (final entry in _sourceStatus.entries) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  Text(
                    '${_results.length} toplam',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
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
                              _searched ? 'Altyazı bulunamadı' : 'Film/dizi adı ile arama yapın',
                              style: const TextStyle(color: Colors.white38, fontSize: 16),
                            ),
                            if (_searched) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() => _selectedLanguage = 'tr,en,de,fr,es');
                                  _search();
                                },
                                child: const Text('Tüm dillerde ara', style: TextStyle(color: Colors.amber)),
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
                          final isDownloading = _downloadingId == sub.id;

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
                                  // Kaynak rozeti
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _sourceColor(sub.source).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      sub.source,
                                      style: TextStyle(
                                        color: _sourceColor(sub.source),
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sub.languageName,
                                    style: const TextStyle(color: Colors.amber, fontSize: 11),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sub.format ?? 'SRT',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                  if (sub.rating != null) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.star, color: Colors.amber, size: 12),
                                    Text('${sub.rating}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ],
                              ),
                              trailing: isDownloading
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber))
                                  : IconButton(
                                      onPressed: () => _downloadAndUse(sub),
                                      icon: const Icon(Icons.download, color: Colors.amber, size: 22),
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

  Color _sourceColor(String source) {
    switch (source) {
      case 'OpenSubtitles':
        return Colors.green;
      case 'YIFY':
        return Colors.orange;
      case 'Subdl':
        return Colors.cyan;
      default:
        return Colors.white54;
    }
  }

  Widget _langFlag(String code) {
    const flags = {
      'tr': '🇹🇷', 'en': '🇬🇧', 'de': '🇩🇪', 'fr': '🇫🇷',
      'es': '🇪🇸', 'it': '🇮🇹', 'pt': '🇵🇹', 'ru': '🇷🇺',
      'ar': '🇸🇦', 'ja': '🇯🇵', 'ko': '🇰🇷', 'zh': '🇨🇳',
    };
    return Container(
      width: 36, height: 36,
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
