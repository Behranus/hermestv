import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Ekrandan görüntü alma servisi.
class ScreenshotService {
  /// Bir [GlobalKey] ile bağlı widget'ın ekran görüntüsünü alır.
  static Future<String?> capture(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();

      // Kayıt dizinine kaydet
      final dir = await getApplicationDocumentsDirectory();
      final screenshotDir = Directory('${dir.path}/screenshots');
      if (!await screenshotDir.exists()) {
        await screenshotDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${screenshotDir.path}/screenshot_$timestamp.png');
      await file.writeAsBytes(bytes);

      image.dispose();
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
