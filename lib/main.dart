import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iptv_player/screens/home_shell.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:iptv_player/state/app_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- fvp (libmdk/FFmpeg) video oynatıcı motoru ----
  // Sadece Linux/Windows/macOS'ta kullanılır.
  // Android'de fvp ExoPlayer performansını düşürür, o yüzden aktif değil.
  if (!Platform.isAndroid) {
    fvp.registerWith();
  }

  // ---- 2GB RAM'li giriş seviyesi Box'lar için bellek yönetimi ----
  PaintingBinding.instance.imageCache.maximumSize = 240;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;

  // Güvenlik ağı: yakalanmamış hatalar uygulamayı kapatmasın.
  _initCrashLog();
  PlatformDispatcher.instance.onError = (error, stack) {
    _logCrash('Platform: $error\n$stack');
    debugPrint('Yakalanmamış hata: $error\n$stack');
    return true;
  };
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logCrash('Flutter: ${details.exception}\n${details.stack}');
    debugPrint('Flutter hatası: ${details.exception}');
  };

  runApp(const IptvApp());
}

File? _crashLogFile;

/// Çökme günlüğü dosyasını açar (uygulama veri klasöründe `crash.log`).
Future<void> _initCrashLog() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    _crashLogFile = File('${dir.path}/crash.log');
  } catch (_) {}
}

void _logCrash(String message) {
  final f = _crashLogFile;
  if (f == null) return;
  try {
    f.writeAsStringSync(
      '${DateTime.now().toIso8601String()} $message\n\n',
      mode: FileMode.append,
    );
  } catch (_) {}
}

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: MaterialApp(
        title: 'bbtv',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const HomeShell(),
      ),
    );
  }

  /// TiviMate mavisi — koyu tema vurgu rengi.
  static const _tiviMateBlue = Color(0xFF1E88E5);

  /// TiviMate koyu teması yüzey tonları.
  static const _tiviMateDarkBg = Color(0xFF0D1117);
  static const _tiviMateDarkSurface = Color(0xFF161B22);
  static const _tiviMateDarkSurfaceHigh = Color(0xFF21262D);

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _tiviMateBlue,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? _tiviMateDarkBg : scheme.surface,
      cardTheme: CardThemeData(
        elevation: isDark ? 1 : 2,
        color: isDark ? _tiviMateDarkSurface : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isDark
              ? BorderSide(color: Colors.white.withValues(alpha: 0.06))
              : BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _tiviMateDarkBg : scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? _tiviMateDarkSurface : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? _tiviMateDarkSurface : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? _tiviMateDarkSurfaceHigh.withValues(alpha: 0.6)
            : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _tiviMateDarkSurface : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
