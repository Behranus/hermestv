import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Gerçek zamanlı Ses → Altyazı (Speech-to-Text) servisi.
///
/// Google Cloud Speech-to-Text API kullanarak oynatılan sesi
/// gerçek zamanlı olarak altyazıya dönüştürür.
///
/// Ücretsiz deneme: https://cloud.google.com/speech-to-text
/// Aylık 60 dakika ücretsiz.
class SpeechToTextService {
  /// Google Cloud STT API key — ayarlardan girilmeli.
  static String? _apiKey;

  /// AktifSTT oturumu.
  static Timer? _pollTimer;
  static bool _active = false;
  static String? _lastText;
  static DateTime? _lastChange;

  /// Ses dosyası geçici dizini.
  static late Directory _tempDir;

  /// STT'yi başlat.
  static Future<void> start({String? apiKey}) async {
    _apiKey = apiKey;
    _active = true;
    _tempDir = await Directory.systemTemp.createTemp('hermestv_stt_');
  }

  /// STT'yi durdur.
  static void stop() {
    _active = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _lastText = null;
  }

  /// API key ayarla.
  static void setApiKey(String key) {
    _apiKey = key;
  }

  /// API key mevcut mu?
  static bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// API key durumu mesajı.
  static String get statusMessage {
    if (!hasApiKey) {
      return 'Google Cloud STT API key gerekli.\n'
          'https://cloud.google.com/speech-to-text adresinden '
          'ücretsiz deneme alın.';
    }
    return 'STT aktif — ses altyazıya dönüştürülüyor.';
  }

  /// Ses verisini Google Cloud STT API'sine gönder ve metin döndür.
  static Future<String?> transcribeAudio(Uint8List audioBytes, {
    String languageCode = 'en-US',
  }) async {
    if (!hasApiKey || audioBytes.isEmpty) return null;

    try {
      // WebM/OGG ses formatında Base64 kodlama
      final audioBase64 = base64Encode(audioBytes);

      final url = Uri.parse(
        'https://speech.googleapis.com/v1/speech:recognize?key=$_apiKey',
      );

      final body = json.encode({
        'config': {
          'encoding': 'WEBM_OPUS',
          'sampleRateHertz': 48000,
          'languageCode': languageCode,
          'enableAutomaticPunctuation': true,
          'model': 'latest_short',
          'useEnhanced': true,
        },
        'audio': {
          'content': audioBase64,
        },
      });

      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          final alternatives = results[0]['alternatives'] as List?;
          if (alternatives != null && alternatives.isNotEmpty) {
            final transcript = alternatives[0]['transcript'] as String?;
            if (transcript != null && transcript.trim().isNotEmpty) {
              return transcript.trim();
            }
          }
        }
      } else {
        // API hatası
        print('STT API hatası: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      print('STT hatası: $e');
    }
    return null;
  }

  /// Metin değişikliğini dinle (Stream).
  static final _textController = StreamController<String?>.broadcast();
  static Stream<String?> get textStream => _textController.stream;

  /// Metin变了 tetikle.
  static void _emitText(String? text) {
    if (_textController.isClosed) return;
    _textController.add(text);
  }

  /// Servisi kapat.
  static Future<void> dispose() async {
    stop();
    if (!_textController.isClosed) await _textController.close();
    try {
      await _tempDir.delete(recursive: true);
    } catch (_) {}
  }
}

/// STT API key'ini saklayan servis (SharedPreferences ile).
class SttSettingsService {
  static const _apiKeyKey = 'stt_api_key';

  static Future<String?> loadApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_apiKeyKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveApiKey(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_apiKeyKey, key);
    } catch (_) {}
  }
}
