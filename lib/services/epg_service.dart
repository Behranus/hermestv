import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:iptv_player/models/epg_program.dart';
import 'package:xml/xml.dart';

/// XMLTV (EPG) verisini URL'den indirip ayrıştırır.
/// Düz `.xml` veya gzip'li `.xml.gz` desteklenir.
class EpgService {
  static final _timeRe = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})\s*([+-]\d{2})(\d{2})?$',
  );

  /// XMLTV zaman biçimini (`20240101230000 +0300`) UTC'ye çevirir.
  static DateTime parseXmltvTime(String raw) {
    final m = _timeRe.firstMatch(raw.trim());
    if (m == null) return DateTime.now();
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final h = int.parse(m.group(4)!);
    final mi = int.parse(m.group(5)!);
    final s = int.parse(m.group(6)!);
    final offSign = m.group(7)!.startsWith('-') ? -1 : 1;
    final offH = int.parse(m.group(7)!.substring(1, 3));
    final offMin = int.parse(m.group(8) ?? '00');
    // Yerel saat UTC + ofset ise: UTC = yerel - ofset.
    return DateTime.utc(y, mo, d, h, mi, s)
        .subtract(Duration(hours: offH * offSign, minutes: offMin * offSign));
  }

  static Future<EpgData> load(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const FormatException('Geçersiz EPG URL\'si.');
    }

    final resp = await http
        .get(uri, headers: {'User-Agent': 'IPTVPlayer/1.0'})
        .timeout(const Duration(seconds: 90));
    if (resp.statusCode != 200) {
      throw HttpException('HTTP ${resp.statusCode} hatası', uri: uri);
    }

    List<int> bytes = resp.bodyBytes;
    // `.gz` uzantılı EPG'yi çöz. (HTTP istemcisi çoktan çözdüyse hata yutarız.)
    if (url.toLowerCase().endsWith('.gz')) {
      try {
        bytes = GZipCodec().decode(bytes);
      } catch (_) {
        // zaten çözülmüş olabilir.
      }
    }

    final xml = utf8.decode(bytes, allowMalformed: true);
    // XML ayrıştırma UI izolatını bloklayabilir (büyük EPG dosyaları saniyelerce
    // donmaya neden olur — 2GB RAM'li Box'larda ANR/çökme). Arka plan izolatında çalıştır.
    return compute(EpgService.parse, xml);
  }

  /// XMLTV içeriğini ayrıştırır. Performans için programları
  /// geçmişte 6 saat / gelecekte 48 saat penceresiyle sınırlar.
  static EpgData parse(String xml) {
    final doc = XmlDocument.parse(xml);
    final programs = <String, List<EpgProgram>>{};
    final channelNames = <String, String>{};

    for (final ch in doc.findAllElements('channel')) {
      final id = ch.getAttribute('id');
      if (id == null || id.isEmpty) continue;
      final names = ch.findElements('display-name');
      if (names.isNotEmpty) {
        channelNames[names.first.innerText.trim().toLowerCase()] = id;
      }
    }

    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(hours: 6));
    final windowEnd = now.add(const Duration(hours: 48));

    for (final p in doc.findAllElements('programme')) {
      final channelId = p.getAttribute('channel');
      final startRaw = p.getAttribute('start');
      final stopRaw = p.getAttribute('stop');
      if (channelId == null || startRaw == null) continue;

      final start = parseXmltvTime(startRaw);
      final stop = stopRaw == null ? start.add(const Duration(hours: 1)) : parseXmltvTime(stopRaw);
      if (stop.isBefore(windowStart) || start.isAfter(windowEnd)) continue;

      final title = p.findElements('title').isEmpty
          ? '(Program yok)'
          : p.findElements('title').first.innerText.trim();
      final descEl = p.findElements('desc');
      final catEl = p.findElements('category');

      final program = EpgProgram(
        channelId: channelId,
        start: start,
        stop: stop,
        title: title,
        description: descEl.isEmpty ? null : descEl.first.innerText.trim(),
        category: catEl.isEmpty ? null : catEl.first.innerText.trim(),
      );
      programs.putIfAbsent(channelId, () => []).add(program);
    }

    // Zaman sırasına göre sırala.
    for (final list in programs.values) {
      list.sort((a, b) => a.start.compareTo(b.start));
    }

    if (programs.isEmpty) {
      throw const FormatException('EPG içinde program bulunamadı.');
    }
    return EpgData(programs: programs, channelNames: channelNames);
  }
}
