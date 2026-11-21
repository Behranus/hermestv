import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

const String kApiBase = String.fromEnvironment(
  'HERMES_API_URL',
  defaultValue: 'https://hermeshaber-di6195-preview.freebuff.site',
);

const List<({String id, String label, String icon})> kRegions = [
  (id: 'all', label: 'Tümü', icon: '🌐'),
  (id: 'europe', label: 'Avrupa', icon: '🇪🇺'),
  (id: 'usa', label: 'ABD', icon: '🇺🇸'),
  (id: 'canada', label: 'Kanada', icon: '🇨🇦'),
  (id: 'latam', label: 'Latin Amerika', icon: '🌎'),
  (id: 'africa', label: 'Afrika', icon: '🌍'),
  (id: 'middleeast', label: 'Orta Doğu', icon: '🕌'),
  (id: 'turkey', label: 'Türkiye', icon: '🇹🇷'),
  (id: 'china', label: 'Çin', icon: '🇨🇳'),
  (id: 'russia', label: 'Rusya', icon: '🇷🇺'),
  (id: 'southasia', label: 'Güney Asya', icon: '🇮🇳'),
  (id: 'eastasia', label: 'Doğu Asya', icon: '🇯🇵'),
  (id: 'seasia', label: 'Güneydoğu Asya', icon: '🇸🇬'),
  (id: 'oceania', label: 'Okyanusya', icon: '🇦🇺'),
];

const List<({String id, String label, String icon})> kCategories = [
  (id: 'all', label: 'Gündem', icon: '📰'),
  (id: 'politics', label: 'Siyaset', icon: '🏛️'),
  (id: 'business', label: 'Ekonomi', icon: '📈'),
  (id: 'tech', label: 'Teknoloji', icon: '💻'),
  (id: 'science', label: 'Bilim', icon: '🔬'),
  (id: 'health', label: 'Sağlık', icon: '🩺'),
  (id: 'climate', label: 'İklim', icon: '🌱'),
  (id: 'sport', label: 'Spor', icon: '⚽'),
  (id: 'culture', label: 'Kültür', icon: '🎭'),
];

// ---------------- renkler ----------------
const kBg = Color(0xFF0B0F14);
const kPanel = Color(0xFF141C25);
const kPanel2 = Color(0xFF1A242F);
const kLine = Color(0xFF212C38);
const kLine2 = Color(0xFF2C3A49);
const kInk = Color(0xFFF2F5F9);
const kInk2 = Color(0xFFB5C2CF);
const kInk3 = Color(0xFF7B8B9C);
const kGold = Color(0xFFE0B872);
const kGold2 = Color(0xFFB9873F);

void main() => runApp(const HermesHaberApp());

class HermesHaberApp extends StatelessWidget {
  const HermesHaberApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'HermesHaber',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: kBg,
        colorScheme: base.colorScheme.copyWith(
          primary: kGold,
          secondary: kGold,
          surface: kPanel,
          onSurface: kInk,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        textSelectionTheme: const TextSelectionThemeData(cursorColor: kGold, selectionColor: Color(0x55339DDC)),
      ),
      home: const HomePage(),
    );
  }
}

// ---------------- modeller ----------------
class NewsItem {
  final String id, title, titleTr, summary, summaryTr, link, image, sourceName, country, flag, region, category, lang, trSource;
  final int publishedAt;

  NewsItem({
    required this.id,
    required this.title,
    required this.titleTr,
    required this.summary,
    required this.summaryTr,
    required this.link,
    required this.image,
    required this.sourceName,
    required this.country,
    required this.flag,
    required this.region,
    required this.category,
    required this.lang,
    required this.trSource,
    required this.publishedAt,
  });

  bool get isTranslated => titleTr.isNotEmpty && titleTr != title;
  String get displayTitle => titleTr.isNotEmpty ? titleTr : title;
  String get displaySummary => summaryTr.isNotEmpty ? summaryTr : summary;

  static String _s(dynamic v) => v == null ? '' : v.toString();

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: _s(j['id']),
        title: _s(j['title']),
        titleTr: _s(j['titleTr']),
        summary: _s(j['summary']),
        summaryTr: _s(j['summaryTr']),
        link: _s(j['link']),
        image: _s(j['image']),
        sourceName: _s(j['sourceName']),
        country: _s(j['country']),
        flag: _s(j['flag']),
        region: _s(j['region']),
        category: _s(j['category']),
        lang: _s(j['lang']),
        trSource: _s(j['trSource']),
        publishedAt: (j['publishedAt'] as num?)?.toInt() ?? 0,
      );
}

class SourceInfo {
  final String id, name, country, flag, region, category;
  final int count;
  SourceInfo({
    required this.id,
    required this.name,
    required this.count,
    required this.country,
    required this.flag,
    required this.region,
    required this.category,
  });

  factory SourceInfo.fromJson(Map<String, dynamic> j) => SourceInfo(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        country: j['country']?.toString() ?? '',
        flag: j['flag']?.toString() ?? '',
        region: j['region']?.toString() ?? '',
        category: j['category']?.toString() ?? 'world',
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

String categoryLabel(String id) {
  for (final c in kCategories) {
    if (c.id == id) return c.label;
  }
  return id;
}

String timeAgo(int ts) {
  if (ts <= 0) return '';
  final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
  if (diff.inMinutes < 1) return 'şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays < 30) return '${diff.inDays} gün önce';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  return '${d.day}.${d.month}.${d.year}';
}

String fullDate(int ts) {
  if (ts <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  const months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year} · $h:$m';
}

// ---------------- ana sayfa ----------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _region = 'all';
  String _category = 'all';
  bool _loading = true;
  String? _error;
  List<NewsItem> _items = const [];
  List<SourceInfo> _sources = const [];
  String _query = '';
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = {'accept': 'application/json'};
      // Sunucu "Tümü" isteğinde bölgeler arasında dengeli örnekleme yapıyor: tek istek yeter.
      final uri = Uri.parse('$kApiBase/api/feed?region=$_region&category=$_category${refresh ? '&refresh=1' : ''}');
      final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 150));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      final items = <NewsItem>[];
      final sources = <SourceInfo>[];
      for (final raw in (data['items'] as List? ?? const [])) {
        final item = NewsItem.fromJson(raw as Map<String, dynamic>);
        if (item.title.isNotEmpty) items.add(item);
      }
      for (final raw in (data['sources'] as List? ?? const [])) {
        sources.add(SourceInfo.fromJson(raw as Map<String, dynamic>));
      }
      items.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      if (!mounted) return;
      setState(() {
        _items = items;
        _sources = sources;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<NewsItem> get _visible {
    final q = _query.trim().toLowerCase();
    return _items.where((it) {
      if (_region != 'all' && it.region != _region) return false;
      if (q.isEmpty) return true;
      return '${it.displayTitle} ${it.title} ${it.displaySummary} ${it.sourceName} ${it.country}'.toLowerCase().contains(q);
    }).toList();
  }

  int get _sourceCount => _sources.where((s) => _region == 'all' ? true : s.region == _region).where((s) => s.count > 0).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kGold, kGold2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Image.asset('assets/tulip_ink.png', width: 21, height: 21, filterQuality: FilterQuality.high),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('HermesHaber', style: TextStyle(color: kInk, fontSize: 16.5, fontWeight: FontWeight.w700)),
                Text('DÜNYA BASINI · TÜRKÇE', style: TextStyle(color: kInk3, fontSize: 9, letterSpacing: 1.6)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Dünya radyoları',
            icon: const Icon(Icons.radio, color: kInk2),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RadioPage())),
          ),
          IconButton(
            tooltip: 'Ara',
            icon: Icon(_searchOpen ? Icons.close : Icons.search, color: kInk2),
            onPressed: () {
              setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchCtrl.clear();
                  _query = '';
                }
              });
            },
          ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh, color: kInk2),
            onPressed: _loading ? null : () => _load(refresh: true),
          ),
          const SizedBox(width: 6),
        ],
        bottom: _searchOpen
            ? PreferredSize(
                preferredSize: const Size.fromHeight(54),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: kInk, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Haberlerde ara…',
                      hintStyle: const TextStyle(color: kInk3, fontSize: 14),
                      prefixIcon: const Icon(Icons.search, size: 18, color: kInk3),
                      filled: true,
                      fillColor: kPanel,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLine)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kGold2)),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          _regionBar(),
          _categoryBar(),
          _statusBar(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _regionBar() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        itemCount: kRegions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final r = kRegions[i];
          final active = r.id == _region;
          return GestureDetector(
            onTap: () {
              if (_region == r.id) return;
              setState(() => _region = r.id);
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? null : kPanel,
                gradient: active ? const LinearGradient(colors: [kGold, Color(0xFFCFA257)]) : null,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: active ? Colors.transparent : kLine),
              ),
              child: Text(
                '${r.icon}  ${r.label}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? const Color(0xFF14100A) : kInk2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _categoryBar() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
        itemCount: kCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final c = kCategories[i];
          final active = c.id == _category;
          return GestureDetector(
            onTap: () {
              if (_category == c.id) return;
              setState(() => _category = c.id);
              _load();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? kPanel2 : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: active ? kGold2 : kLine),
              ),
              child: Text(
                '${c.icon}  ${c.label}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? kGold : kInk3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusBar() {
    final count = _visible.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4FBF7C), shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(
            '$count haber · $_sourceCount kaynak${_category == 'all' ? '' : ' · ${categoryLabel(_category)}'}',
            style: const TextStyle(color: kInk3, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: kGold, strokeWidth: 2));
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, color: kInk3, size: 40),
              const SizedBox(height: 12),
              const Text('Haberler yüklenemedi', style: TextStyle(color: kInk2, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kInk3, fontSize: 12)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: () => _load(), child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    }
    final items = _visible;
    if (items.isEmpty) {
      return const Center(child: Text('Haber bulunamadı', style: TextStyle(color: kInk3)));
    }
    final hero = _query.trim().isEmpty ? items.firstWhere((it) => it.image.isNotEmpty, orElse: () => items.first) : null;
    final rest = hero == null ? items : items.where((it) => it != hero).toList();

    return RefreshIndicator(
      color: kGold,
      backgroundColor: kPanel,
      onRefresh: () => _load(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        itemCount: rest.length + (hero != null ? 2 : 0),
        itemBuilder: (context, i) {
          if (hero != null) {
            if (i == 0) return _HeroCard(item: hero);
            if (i == 1) return const Padding(padding: EdgeInsets.fromLTRB(2, 20, 2, 10), child: _SectionTitle('Son haberler'));
            return _NewsRow(item: rest[i - 2]);
          }
          return _NewsRow(item: rest[i]);
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(color: kInk3, fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w600),
    );
  }
}

// ---------------- öne çıkan kart ----------------
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderPage(item: item))),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: kPanel),
        child: SizedBox(
          height: (MediaQuery.of(context).size.width * 11 / 16).clamp(220.0, 380.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.image.isNotEmpty)
                Image.network(
                  item.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: kPanel2),
                  loadingBuilder: (c, child, progress) => progress == null ? child : Container(color: kPanel2),
                )
              else
                Container(color: kPanel2),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xF206090D), Color(0xB306090D), Color(0x0006090D)],
                    stops: [0, 0.55, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(item.flag, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          item.sourceName.toUpperCase(),
                          style: const TextStyle(color: kGold, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      item.displayTitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kInk, fontSize: 20, height: 1.25, fontWeight: FontWeight.w700),
                    ),
                    if (item.displaySummary.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        item.displaySummary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xD9F2F5F9), fontSize: 12.5, height: 1.45),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${timeAgo(item.publishedAt)} · ${item.country}',
                      style: const TextStyle(color: Color(0x99F2F5F9), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- satır kart ----------------
class _NewsRow extends StatelessWidget {
  const _NewsRow({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderPage(item: item))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kPanel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kLine),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.flag, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          item.sourceName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kGold, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.displayTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInk, fontSize: 14.5, height: 1.34, fontWeight: FontWeight.w600),
                  ),
                  if (item.displaySummary.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.displaySummary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kInk2, fontSize: 12.3, height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Text(
                    '${timeAgo(item.publishedAt)} · ${item.country}',
                    style: const TextStyle(color: kInk3, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (item.image.isNotEmpty) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  item.image,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(width: 90, height: 90, color: kPanel2),
                  loadingBuilder: (c, child, progress) => progress == null ? child : Container(width: 90, height: 90, color: kPanel2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------- okuyucu ----------------
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key, required this.item});
  final NewsItem item;
  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  String _body = '';
  String _original = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadArticle();
  }

  Future<void> _loadArticle() async {
    final url = widget.item.link;
    if (url.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Bu haber için bağlantı yok.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lang = widget.item.lang.isEmpty ? 'auto' : widget.item.lang;
      final uri = Uri.parse('$kApiBase/api/read?url=${Uri.encodeComponent(url)}&lang=$lang');
      final res = await http.get(uri).timeout(const Duration(seconds: 150));
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = (data['message'] ?? data['error'] ?? 'HTTP ${res.statusCode}').toString();
        });
        return;
      }
      setState(() {
        _body = (data['translated'] ?? '').toString().trim();
        _original = (data['original'] ?? '').toString().trim();
        _loading = false;
        _error = _body.isEmpty && _original.isEmpty ? 'Okunabilir metin bulunamadı.' : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final text = _body.isNotEmpty ? _body : _original;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.sourceName, style: const TextStyle(color: kInk2, fontSize: 14, fontWeight: FontWeight.w500)),
        actions: [
          IconButton(
            tooltip: 'Bağlantıyı kopyala',
            icon: const Icon(Icons.link, color: kInk2),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: item.link));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
            },
          ),
          IconButton(
            tooltip: 'Orijinali aç',
            icon: const Icon(Icons.open_in_new, color: kInk2),
            onPressed: item.link.isEmpty ? null : () => launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (item.image.isNotEmpty)
            SizedBox(
              height: (MediaQuery.of(context).size.width * 9 / 16).clamp(180.0, 330.0),
              width: double.infinity,
              child: Image.network(
                item.image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(color: kPanel2),
                loadingBuilder: (c, child, progress) => progress == null ? child : Container(color: kPanel2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item.flag, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      item.sourceName.toUpperCase(),
                      style: const TextStyle(color: kGold, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 1.1),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '· ${item.country}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kInk3, fontSize: 10.5, letterSpacing: .6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  item.displayTitle,
                  style: const TextStyle(color: kInk, fontSize: 24, height: 1.26, fontWeight: FontWeight.w700, letterSpacing: -.3),
                ),
                if (item.isTranslated) ...[
                  const SizedBox(height: 9),
                  Text(item.title, style: const TextStyle(color: kInk3, fontSize: 12.5, fontStyle: FontStyle.italic, height: 1.5)),
                ],
                const SizedBox(height: 12),
                Text(fullDate(item.publishedAt), style: const TextStyle(color: kInk3, fontSize: 11.5)),
                if (item.displaySummary.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.only(left: 14),
                    decoration: const BoxDecoration(border: Border(left: BorderSide(color: kGold2, width: 2))),
                    child: Text(
                      item.displaySummary,
                      style: const TextStyle(color: kInk, fontSize: 14.5, height: 1.6),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_loading)
                  const Row(
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kGold)),
                      SizedBox(width: 10),
                      Text('Haber metni getiriliyor…', style: TextStyle(color: kInk3, fontSize: 12.5)),
                    ],
                  )
                else if (text.isNotEmpty) ...[
                  _SectionTitle(_body.isNotEmpty ? 'Türkçe metin' : 'Orijinal metin'),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: const TextStyle(color: Color(0xFFDAE2EC), fontSize: 15.5, height: 1.75),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _body.isNotEmpty
                        ? 'Metin otomatik çevrildi; özgün metnin yerini tutmaz.'
                        : 'Çeviri tamamlanamadı, metin özgün dilinde gösteriliyor.',
                    style: TextStyle(color: _body.isNotEmpty ? kInk3 : kGold, fontSize: 11.5, height: 1.6),
                  ),
                ] else if (_error != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Metin alınamadı: $_error', style: const TextStyle(color: kGold, fontSize: 12.5, height: 1.5)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: widget.item.link.isEmpty
                                ? null
                                : () => launchUrl(Uri.parse(widget.item.link), mode: LaunchMode.externalApplication),
                            style: FilledButton.styleFrom(backgroundColor: kGold, foregroundColor: const Color(0xFF14100A)),
                            icon: const Icon(Icons.open_in_new, size: 17),
                            label: const Text('Haberi kaynağında aç'),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(onPressed: _loadArticle, child: const Text('Tekrar dene')),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- dünya radyoları ----------------

class RadioStation {
  final String id, name, country, flag, genre, url, favicon;
  final int bitrate;
  final bool hls;

  const RadioStation({
    required this.id,
    required this.name,
    required this.country,
    required this.flag,
    required this.genre,
    required this.url,
    required this.favicon,
    required this.bitrate,
    required this.hls,
  });

  static String _s(dynamic v) => v == null ? '' : v.toString();

  factory RadioStation.fromJson(Map<String, dynamic> j) => RadioStation(
        id: _s(j['id']),
        name: _s(j['name']),
        country: _s(j['country']),
        flag: _s(j['flag']),
        genre: _s(j['genre']),
        url: _s(j['url']),
        favicon: _s(j['favicon']),
        bitrate: (j['bitrate'] as num?)?.toInt() ?? 0,
        hls: j['hls'] == true,
      );
}

class RadioCountry {
  final String code, name, flag;
  const RadioCountry({required this.code, required this.name, required this.flag});

  factory RadioCountry.fromJson(Map<String, dynamic> j) => RadioCountry(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        flag: j['flag']?.toString() ?? '🌍',
      );
}

class RadioPage extends StatefulWidget {
  const RadioPage({super.key});
  @override
  State<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends State<RadioPage> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _sub;

  bool _showFeatured = true;
  List<RadioStation> _featured = const [];
  List<RadioCountry> _countries = const [];
  List<RadioStation> _stations = const [];
  RadioCountry? _country;
  RadioStation? _current;
  bool _loading = true;
  bool _playing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sub = _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
    });
    _loadFeatured();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$kApiBase/api/radio?kind=featured'), headers: {'accept': 'application/json'})
          .timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      setState(() {
        _featured = (data['stations'] as List? ?? const [])
            .map((e) => RadioStation.fromJson(e as Map<String, dynamic>))
            .toList();
        _countries = (data['countries'] as List? ?? const [])
            .map((e) => RadioCountry.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Radyo listesi alınamadı: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _loadCountry(RadioCountry c) async {
    setState(() {
      _country = c;
      _stations = const [];
      _loading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(Uri.parse('$kApiBase/api/radio?kind=country&country=${c.code}'), headers: {'accept': 'application/json'})
          .timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      setState(() {
        _stations = (data['stations'] as List? ?? const [])
            .map((e) {
              final s = RadioStation.fromJson(e as Map<String, dynamic>);
              return RadioStation(
                id: s.id,
                name: s.name,
                country: c.name,
                flag: c.flag,
                genre: s.genre,
                url: s.url,
                favicon: s.favicon,
                bitrate: s.bitrate,
                hls: s.hls,
              );
            })
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'İstasyonlar alınamadı: ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _toggle(RadioStation st) async {
    if (_current?.url == st.url) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      return;
    }
    setState(() {
      _current = st;
      _busy = true;
      _error = null;
    });
    try {
      await _player.setUrl(st.url);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Bu yayın açılamadı. Başka bir istasyon deneyin.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    await _player.stop();
    if (!mounted) return;
    setState(() => _current = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dünya Radyoları', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(
              children: [
                _tabChip('⭐  Öne çıkanlar', _country == null && _showFeatured, () {
                  setState(() {
                    _country = null;
                    _showFeatured = true;
                  });
                }),
                const SizedBox(width: 8),
                _tabChip('🌍  Ülkeler', _country == null && !_showFeatured, () {
                  setState(() {
                    _country = null;
                    _showFeatured = false;
                  });
                }),
                if (_country != null) ...[
                  const SizedBox(width: 8),
                  _tabChip('${_country!.flag}  ${_country!.name}', true, () => setState(() => _country = null)),
                ],
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          if (_current != null) _playerBar(),
        ],
      ),
    );
  }

  Widget _tabChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? kPanel2 : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: active ? kGold2 : kLine),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.5, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? kGold : kInk3),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: kGold, strokeWidth: 2));
    if (_error != null && _stations.isEmpty && _featured.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.radio, color: kInk3, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kInk2, fontSize: 13)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _loadFeatured, child: const Text('Tekrar dene')),
            ],
          ),
        ),
      );
    }

    if (_country != null) {
      if (_stations.isEmpty) {
        return const Center(child: Text('Bu ülke için uygun yayın bulunamadı', style: TextStyle(color: kInk3)));
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        itemCount: _stations.length + 1,
        itemBuilder: (context, i) {
          if (i == _stations.length) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                'Yayınlar radio-browser.info dizininden geliyor; bazı istasyonlar yayın saatlerine göre kapalı olabilir.',
                style: TextStyle(color: kInk3, fontSize: 11, height: 1.5),
              ),
            );
          }
          return _stationTile(_stations[i]);
        },
      );
    }

    if (_showFeatured) {
      final list = _featured.where((s) => !s.hls).toList();
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        itemCount: list.length + 1,
        itemBuilder: (context, i) {
          if (i == list.length) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                'Kamu yayıncıları ve güvenilir istasyonlar. “Ülkeler” sekmesinden dünyanın her yerinden radyo dinleyebilirsiniz.',
                style: TextStyle(color: kInk3, fontSize: 11, height: 1.5),
              ),
            );
          }
          return _stationTile(list[i]);
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 48,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _countries.length,
      itemBuilder: (context, i) {
        final c = _countries[i];
        return GestureDetector(
          onTap: () => _loadCountry(c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: kPanel,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: kLine),
            ),
            child: Row(
              children: [
                Text(c.flag, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInk2, fontSize: 13),
                  ),
                ),
                Text(c.code, style: const TextStyle(color: kInk3, fontSize: 10, letterSpacing: 1)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stationTile(RadioStation st) {
    final playing = _current?.url == st.url && _playing;
    return GestureDetector(
      onTap: () => _toggle(st),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kPanel,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _current?.url == st.url ? kGold2 : kLine),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kPanel2, borderRadius: BorderRadius.circular(11)),
              child: st.favicon.isEmpty
                  ? Text(st.flag.isEmpty ? '📻' : st.flag, style: const TextStyle(fontSize: 17))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.network(
                        st.favicon,
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text(st.flag.isEmpty ? '📻' : st.flag, style: const TextStyle(fontSize: 17)),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    st.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInk, fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [st.country, st.genre, st.bitrate > 0 ? '${st.bitrate} kbps' : ''].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInk3, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: playing ? kGold : kPanel2,
                shape: BoxShape.circle,
                border: Border.all(color: playing ? Colors.transparent : kLine2),
              ),
              child: Icon(
                playing ? Icons.pause : Icons.play_arrow,
                size: 18,
                color: playing ? const Color(0xFF14100A) : kGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerBar() {
    final st = _current!;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: const BoxDecoration(
        color: kPanel2,
        border: Border(top: BorderSide(color: kLine)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggle(st),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kGold, Color(0xFFCFA257)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF14100A)))
                    : Icon(_playing ? Icons.pause : Icons.play_arrow, size: 20, color: const Color(0xFF14100A)),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    st.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [st.flag, st.country, st.genre].where((e) => e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kInk3, fontSize: 10.5),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Radyoyu kapat',
              onPressed: _stop,
              icon: const Icon(Icons.close, size: 19, color: kInk2),
            ),
          ],
        ),
      ),
    );
  }
}
