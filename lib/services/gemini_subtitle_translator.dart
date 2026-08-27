import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hermestv/config.dart';
import 'package:hermestv/services/stream_player.dart';

/// Gemini AI ile anlık altyazı çeviri servisi.
/// Canlı TV ve VOD için çalışır.
class GeminiSubtitleTranslator {
  static bool _enabled = false;
  static String _targetLanguage = 'Türkçe';
  static int _batchSize = 5; // Kaç satır birlikte çevrilecek

  static bool get isEnabled => _enabled;
  static String get targetLanguage => _targetLanguage;

  /// Çeviriyi aç/kapat
  static void toggle() {
    _enabled = !_enabled;
  }

  /// Hedef dili değiştir
  static void setTargetLanguage(String lang) {
    _targetLanguage = lang;
  }

  /// Desteklenen diller
  static const Map<String, String> supportedLanguages = {
    'tr': 'Türkçe',
    'en': 'İngilizce',
    'de': 'Almanca',
    'fr': 'Fransızca',
    'es': 'İspanyolca',
    'it': 'İtalyanca',
    'ru': 'Rusça',
    'ar': 'Arapça',
    'fa': 'Farsça',
    'zh': 'Çince',
    'ja': 'Japonca',
    'ko': 'Korece',
    'pt': 'Portekizce',
    'nl': 'Felemenkçe',
    'sv': 'İsveççe',
    'pl': 'Lehçe',
  };

  /// Tek bir altyazı satırını çevir
  static Future<String> translateLine(String text) async {
    if (text.trim().isEmpty) return text;
    if (geminiApiKey.isEmpty) return text;

    try {
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey';
      final prompt = 'You are a professional subtitle translator. Translate the following subtitle text to $_targetLanguage. Keep the timing and formatting. Only output the translated text, nothing else:\n\n$text';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}]
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? text;
      }
      return text;
    } catch (e) {
      return text;
    }
  }

  /// Toplu altyazı çevirisi (VOD için)
  static Future<List<SubtitleCue>> translateCues(List<SubtitleCue> cues) async {
    if (!_enabled || cues.isEmpty || geminiApiKey.isEmpty) return cues;

    final translated = <SubtitleCue>[];
    for (var i = 0; i < cues.length; i += _batchSize) {
      final batch = cues.sublist(i, (i + _batchSize).clamp(0, cues.length));
      final texts = batch.map((c) => c.text).join('\n---\n');
      
      final translatedText = await translateLine(texts);
      final translatedLines = translatedText.split('\n---\n');
      
      for (var j = 0; j < batch.length; j++) {
        final text = j < translatedLines.length ? translatedLines[j].trim() : batch[j].text;
        translated.add(SubtitleCue(Duration.zero, Duration.zero, text));
      }
      
      // API rate limit için kısa bekleme
      if (i + _batchSize < cues.length) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    
    return translated;
  }

  /// Canlı TV için altyazı çevirisi (tek satır)
  static Future<String> translateLiveSubtitle(String original, {String? fromLanguage}) async {
    if (!_enabled || original.trim().isEmpty || geminiApiKey.isEmpty) return original;
    return translateLine(original);
  }

  /// VOD için dosya tabanlı altyazı çevirisi
  static Future<String> translateSubtitleContent(String srtContent) async {
    if (!_enabled || geminiApiKey.isEmpty) return srtContent;

    // SRT formatını parse et
    final blocks = _parseSRT(srtContent);
    if (blocks.isEmpty) return srtContent;

    // Tüm satırları topla
    final allTexts = blocks.map((b) => b.text).join('\n');
    final translatedAll = await translateLine(allTexts);
    final translatedLines = translatedAll.split('\n');

    // Çevrilmiş satırları bloklara ata
    var lineIndex = 0;
    for (var i = 0; i < blocks.length; i++) {
      if (lineIndex < translatedLines.length) {
        blocks[i] = SrtBlock(
          index: blocks[i].index,
          time: "00:00:00,000 --> 00:00:10,000",
          text: translatedLines[lineIndex].trim(),
        );
        lineIndex++;
      }
    }

    // SRT formatına geri çevir
    return _buildSRT(blocks);
  }

  /// SRT dosyasını parse et
  static List<SrtBlock> _parseSRT(String content) {
    final blocks = <SrtBlock>[];
    final lines = content.split('\n');
    
    var i = 0;
    while (i < lines.length) {
      // Blok numarası
      final index = int.tryParse(lines[i].trim());
      if (index == null) { i++; continue; }
      i++;
      
      // Zaman çizelgesi
      final timeLine = lines[i].trim();
      i++;
      
      // Metin satırları
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        textLines.add(lines[i]);
        i++;
      }
      i++; // Boş satırı geç
      
      blocks.add(SrtBlock(
        index: index,
        time: timeLine,
        text: textLines.join('\n'),
      ));
    }
    
    return blocks;
  }

  /// SRT dosyası oluştur
  static String _buildSRT(List<SrtBlock> blocks) {
    final buffer = StringBuffer();
    for (var i = 0; i < blocks.length; i++) {
      buffer.writeln(blocks[i].index);
      buffer.writeln(blocks[i].time);
      buffer.writeln(blocks[i].text);
      if (i < blocks.length - 1) buffer.writeln();
    }
    return buffer.toString();
  }
}

/// SRT blok modeli
class SrtBlock {
  final int index;
  final String? time;
  final String text;

  const SrtBlock({
    required this.index,
    this.time,
    required this.text,
  });
}
