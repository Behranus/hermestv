import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// VOD izleme geçmişini ve kaldığın yer bilgisini saklar.
class ResumeService {
  static const _key = 'hermestv_resume_history';
  static const _maxItems = 50;

  /// Bir izleme kaydı.
  static ResumeRecord fromJson(Map<String, dynamic> j) => ResumeRecord(
        id: j['id'] as int,
        title: j['title'] as String? ?? '',
        poster: j['poster'] as String?,
        url: j['url'] as String? ?? '',
        position: Duration(milliseconds: j['positionMs'] as int? ?? 0),
        duration: Duration(milliseconds: j['durationMs'] as int? ?? 0),
        isMovie: j['isMovie'] as bool? ?? true,
        watchedAt: DateTime.fromMillisecondsSinceEpoch(j['watchedAt'] as int? ?? 0),
      );

  /// Kayıtları yükle (en son izlenen en üstte).
  static Future<List<ResumeRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final records = list.map(fromJson).toList();
    // En son izlenen en üstte
    records.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    return records;
  }

  /// Bir kaydı kaydet veya güncelle (aynı id varsa üzerine yaz).
  static Future<void> save(ResumeRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();
    // Aynı id varsa kaldır
    records.removeWhere((r) => r.id == record.id);
    records.insert(0, record);
    // Maksimum kayıt sayısı
    if (records.length > _maxItems) {
      records.removeRange(_maxItems, records.length);
    }
    final data = records.map((r) => {
      'id': r.id,
      'title': r.title,
      'poster': r.poster,
      'url': r.url,
      'positionMs': r.position.inMilliseconds,
      'durationMs': r.duration.inMilliseconds,
      'isMovie': r.isMovie,
      'watchedAt': r.watchedAt.millisecondsSinceEpoch,
    }).toList();
    await prefs.setString(_key, jsonEncode(data));
  }

  /// Bir kaydı sil.
  static Future<void> remove(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final records = await load();
    records.removeWhere((r) => r.id == id);
    final data = records.map((r) => {
      'id': r.id,
      'title': r.title,
      'poster': r.poster,
      'url': r.url,
      'positionMs': r.position.inMilliseconds,
      'durationMs': r.duration.inMilliseconds,
      'isMovie': r.isMovie,
      'watchedAt': r.watchedAt.millisecondsSinceEpoch,
    }).toList();
    await prefs.setString(_key, jsonEncode(data));
  }

  /// Tüm geçmişi temizle.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

/// Tek bir izleme kaydı.
class ResumeRecord {
  const ResumeRecord({
    required this.id,
    required this.title,
    this.poster,
    required this.url,
    required this.position,
    required this.duration,
    required this.isMovie,
    required this.watchedAt,
  });

  final int id;
  final String title;
  final String? poster;
  final String url;
  final Duration position;
  final Duration duration;
  final bool isMovie;
  final DateTime watchedAt;

  /// Yüzde olarak ilerleme (0.0 - 1.0).
  double get progress {
    if (duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  /// Bitişe ne kadar süre kaldı.
  Duration get remaining => duration - position;

  /// Tamamlandı sayılır mı? (%90'dan fazla izlendiyse).
  bool get isCompleted => progress > 0.9;

  /// Kalan süreyi okunabilir formata çevir.
  String get remainingText {
    final m = remaining.inMinutes;
    final s = remaining.inSeconds.remainder(60);
    if (m > 60) {
      final h = m ~/ 60;
      return '${h}sa ${m.remainder(60)}dk kaldı';
    }
    return '${m}dk ${s}s kaldı';
  }

  /// Konumu okunabilir formata çevir.
  String get positionText {
    final m = position.inMinutes;
    final s = position.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Süreyi okunabilir formata çevir.
  String get durationText {
    final m = duration.inMinutes;
    final s = duration.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
