import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

/// YouTube benzeri gerçek zamanlı ses → altyazı çevirici.
///
/// Cihaz mikrofonundan sesi dinler, Gemini API ile tanıtır,
/// ardından MyMemory ile Türkçeye çevirir.
class GeminiSttService {
  static final GeminiSttService _instance = GeminiSttService._();
  factory GeminiSttService() => _instance;
  GeminiSttService._();

  final SpeechToText _stt = SpeechToText();
  bool _initialized = false;
  bool _listening = false;

  /// Son üretilen altyazı metni.
  String? lastSubtitle;

  /// dinleme durumunda tetiklenir.
  final StreamController<String?> _subtitleController =
      StreamController<String?>.broadcast();
  Stream<String?> get subtitleStream => _subtitleController.stream;

  bool get isListening => _listening;

  /// STT motorunu başlat.
  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = await _stt.initialize(
      onError: (e) => print('[STT] Hata: ${e.errorMsg}'),
      onStatus: (s) {
        if (s == 'notListening' || s == 'done') {
          _listening = false;
        }
      },
    );
    return _initialized;
  }

  /// Dinlemeyi başlat — her sonuç geldiğinde Gemini'ye gönderip çevirir.
  Future<void> startListening({
    String targetLang = 'tr',
    String sourceLang = 'en',
  }) async {
    if (!_initialized) await init();
    if (!_initialized) return;
    _listening = true;

    await _stt.listen(
      onResult: (SpeechRecognitionResult result) async {
        if (result.recognizedWords.trim().isEmpty) return;

        // Önce orijinal dilden altyazı üret (zaten STT yapıyor)
        final original = result.recognizedWords;

        // Eğer hedef dil farklıysa çevir
        if (targetLang != sourceLang) {
          final translated = await _translateWithGemini(
            original,
            sourceLang: sourceLang,
            targetLang: targetLang,
          );
          lastSubtitle = translated ?? original;
        } else {
          lastSubtitle = original;
        }
        _subtitleController.add(lastSubtitle);
      },
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 3),
      localeId: _localeId(sourceLang),
      cancelOnError: false,
    );
  }

  /// Dinlemeyi durdur.
  Future<void> stopListening() async {
    _listening = false;
    await _stt.stop();
    lastSubtitle = null;
    _subtitleController.add(null);
  }

  /// Gemini API ile çeviri yapar.
  Future<String?> _translateWithGemini(
    String text, {
    String sourceLang = 'en',
    String targetLang = 'tr',
  }) async {
    if (geminiApiKey.isEmpty || text.trim().isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$geminiApiKey',
      );

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text':
                    'Translate the following text from $sourceLang to $targetLang. '
                        'Only return the translation, nothing else. '
                        'Keep it concise and natural.\n\n$text',
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 200,
        },
      });

      final resp = await http
          .post(url, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final candidates = data['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final parts =
              candidates[0]['content']?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text']?.toString().trim();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  String _localeId(String lang) {
    switch (lang) {
      case 'tr':
        return 'tr-TR';
      case 'en':
        return 'en-US';
      case 'ar':
        return 'ar-SA';
      case 'ku':
        return 'tr-TR'; // Kürtçe için Türkçe motoru kullanılır
      default:
        return 'en-US';
    }
  }

  void dispose() {
    _stt.cancel();
    _subtitleController.close();
  }
}
