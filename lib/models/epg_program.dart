/// XMLTV (EPG) içindeki tek bir program kaydı.
class EpgProgram {
  const EpgProgram({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.description,
    this.category,
  });

  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;
  final String? category;

  bool get isNow {
    final now = DateTime.now();
    return start.isBefore(now) && stop.isAfter(now);
  }
}

/// Yüklenmiş EPG verisi: kanal kimliğine göre programlar + isim eşleme.
class EpgData {
  EpgData({
    required this.programs,
    required this.channelNames,
  });

  /// Kanal kimliği (XMLTV `channel id` / M3U `tvg-id`) → program listesi.
  final Map<String, List<EpgProgram>> programs;

  /// Kanal adı → kanal kimliği (adla eşleştirme için).
  final Map<String, String> channelNames;

  int get channelCount => programs.length;

  List<EpgProgram>? forChannelId(String? id) {
    if (id == null || id.isEmpty) return null;
    return programs[id];
  }

  /// M3U kanalındaki `tvg-id` veya kanal adıyla program listesini bulur.
  List<EpgProgram>? forChannel({String? tvgId, String? name}) {
    final byId = forChannelId(tvgId);
    if (byId != null) return byId;
    if (name == null || name.isEmpty) return null;
    final normalized = name.toLowerCase().trim();
    final channelId = channelNames[normalized];
    if (channelId == null) return null;
    return programs[channelId];
  }

  /// Şu an yayında olan program (yoksa null).
  EpgProgram? nowPlaying({String? tvgId, String? name}) {
    final list = forChannel(tvgId: tvgId, name: name);
    if (list == null) return null;
    final now = DateTime.now();
    for (final p in list) {
      if (p.start.isBefore(now) && p.stop.isAfter(now)) return p;
    }
    return null;
  }

  /// Şu andan sonra başlayan ilk program (yoksa null).
  EpgProgram? next({String? tvgId, String? name}) {
    final list = forChannel(tvgId: tvgId, name: name);
    if (list == null) return null;
    final now = DateTime.now();
    for (final p in list) {
      if (p.start.isAfter(now)) return p;
    }
    return null;
  }
}
