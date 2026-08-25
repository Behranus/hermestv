import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Kişisel izleme listesi (My List) servisi.
///
/// Kullanıcı izlemek istediği filmleri/dizileri listeye ekleyebilir.
/// Liste SharedPreferences'da saklanır.
class WatchlistService {
  static const _key = 'hermestv_watchlist';
  static const _maxItems = 200;

  /// Listeyi yükle.
  static Future<List<WatchlistItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(WatchlistItem.fromJson).toList();
  }

  /// Öğe ekle veya güncelle.
  static Future<void> add(WatchlistItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await load();
    // Aynı id varsa kaldır
    items.removeWhere((i) => i.id == item.id);
    items.insert(0, item);
    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }
    await _save(items);
  }

  /// Öğeyi listeden çıkar.
  static Future<void> remove(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await load();
    items.removeWhere((i) => i.id == id);
    await _save(items);
  }

  /// Öğe listede mi kontrol et.
  static Future<bool> contains(int id) async {
    final items = await load();
    return items.any((i) => i.id == id);
  }

  /// Listeyi temizle.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<void> _save(List<WatchlistItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((i) => i.toJson()).toList();
    await prefs.setString(_key, jsonEncode(data));
  }
}

/// İzleme listesindeki bir öğe.
class WatchlistItem {
  const WatchlistItem({
    required this.id,
    required this.title,
    this.poster,
    this.description,
    this.rating,
    this.isMovie = true,
    required this.addedAt,
  });

  final int id;
  final String title;
  final String? poster;
  final String? description;
  final String? rating;
  final bool isMovie;
  final DateTime addedAt;

  factory WatchlistItem.fromJson(Map<String, dynamic> j) => WatchlistItem(
        id: j['id'] as int,
        title: j['title'] as String? ?? '',
        poster: j['poster'] as String?,
        description: j['description'] as String?,
        rating: j['rating'] as String?,
        isMovie: j['isMovie'] as bool? ?? true,
        addedAt: DateTime.fromMillisecondsSinceEpoch(j['addedAt'] as int? ?? 0),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'poster': poster,
        'description': description,
        'rating': rating,
        'isMovie': isMovie,
        'addedAt': addedAt.millisecondsSinceEpoch,
      };
}
