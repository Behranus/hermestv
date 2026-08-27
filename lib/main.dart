import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hermestv/screens/home_shell.dart';
import 'package:fvp/fvp.dart' as fvp;
import 'package:hermestv/l10n/locale_provider.dart';
import 'package:hermestv/state/app_state.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Window manager başlat (Linux pencere ayarları)
  if (!Platform.isAndroid) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Color(0xFF0D0D1A),
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: true,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // ---- fvp (libmdk/FFmpeg) video oynatıcı motoru ----
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
        title: 'HermesTV',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: _buildDarkTheme(),
        home: const HomeShell(),
      ),
    );
  }

  // ── Zorin OS Renk Paleti ──
  static const Color _zorinBgDeep      = Color(0xFF1A1B2E);  // En koyu arka plan
  static const Color _zorinBgMain      = Color(0xFF1E2030);  // Ana arka plan
  static const Color _zorinSurface     = Color(0xFF24263A);  // Kart yüzeyleri
  static const Color _zorinSurfaceHigh = Color(0xFF2E3048);  // Vurgulu yüzey
  static const Color _zorinSurfaceHov  = Color(0xFF363952);  // Hover durumu
  static const Color _zorinBorder      = Color(0xFF3A3D56);  // Kenar çizgileri
  static const Color _zorinAccent      = Color(0xFF3C8AFF);  // Ana vurgu (Zorin Mavi)
  static const Color _zorinAccentSoft  = Color(0xFF2A5DB0);  // Yumuşak vurgu
  static const Color _zorinText        = Color(0xFFE8E9F0);  // Ana metin
  static const Color _zorinTextMid     = Color(0xFFA0A3B8);  // Orta metin
  static const Color _zorinTextDim     = Color(0xFF6B6E85);  // Soluk metin
  static const Color _zorinAccentRed   = Color(0xFFE54D6E);  // Kırmızı vurgu
  static const Color _zorinAccentAmber = Color(0xFFF5A623);  // Amber/Sarı
  static const Color _zorinAccentGreen = Color(0xFF40C057);  // Yeşil
  static const Color _zorinSurfaceGlass = Color(0x1AFFFFFF);  // Şeffaf overlay

  static ThemeData _buildDarkTheme() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: _zorinAccent,
      onPrimary: Colors.white,
      primaryContainer: _zorinAccentSoft,
      onPrimaryContainer: Colors.white,
      secondary: _zorinAccentRed,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF6B2535),
      onSecondaryContainer: Colors.white,
      tertiary: _zorinAccentAmber,
      onTertiary: Colors.black,
      tertiaryContainer: Color(0xFF4A3500),
      onTertiaryContainer: Colors.white,
      error: Color(0xFFFF5555),
      onError: Colors.white,
      surface: _zorinSurface,
      onSurface: _zorinText,
      onSurfaceVariant: _zorinTextMid,
      outline: _zorinBorder,
      outlineVariant: Color(0xFF2A2C42),
      shadow: Colors.black54,
      surfaceContainerHighest: _zorinSurfaceHigh,
      surfaceContainerHigh: _zorinSurface,
      surfaceContainerLow: _zorinBgDeep,
      surfaceDim: _zorinBgDeep,
      inverseSurface: _zorinText,
      inversePrimary: _zorinAccent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _zorinBgDeep,

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _zorinText,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: _zorinTextMid),
      ),

      // ── Kartlar ──
      cardTheme: CardThemeData(
        elevation: 0,
        color: _zorinSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _zorinBorder.withValues(alpha: 0.4), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Butonlar ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _zorinAccent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _zorinText,
          side: const BorderSide(color: _zorinBorder, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _zorinAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // ── Navigation Rail (Geniş ekran / TV) ──
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _zorinBgMain,
        indicatorColor: _zorinAccent.withValues(alpha: 0.2),
        selectedIconTheme: IconThemeData(color: _zorinAccent, size: 24),
        unselectedIconTheme: IconThemeData(color: _zorinTextDim, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: _zorinAccent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: _zorinTextDim,
          fontSize: 11,
        ),
        labelType: NavigationRailLabelType.all,
        minWidth: 80,
      ),

      // ── Navigation Bar (Mobil) ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _zorinBgMain,
        surfaceTintColor: Colors.transparent,
        indicatorColor: _zorinAccent.withValues(alpha: 0.2),
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      // ── Input ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _zorinSurfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _zorinBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _zorinBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _zorinAccent, width: 2),
        ),
        hintStyle: TextStyle(color: _zorinTextDim, fontSize: 14),
        labelStyle: TextStyle(color: _zorinTextMid, fontSize: 14),
        prefixIconColor: _zorinTextMid,
      ),

      // ── Chip ──
      chipTheme: ChipThemeData(
        backgroundColor: _zorinSurfaceHigh,
        selectedColor: _zorinAccent.withValues(alpha: 0.2),
        side: BorderSide(color: _zorinBorder, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelStyle: TextStyle(color: _zorinTextMid, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: _zorinBorder,
        thickness: 1,
        space: 1,
      ),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _zorinSurfaceHigh,
        contentTextStyle: const TextStyle(color: _zorinText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: _zorinSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _zorinBorder, width: 1),
        ),
      ),

      // ── PopupMenu ──
      popupMenuTheme: PopupMenuThemeData(
        color: _zorinSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── ListTile ──
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),

      // ── TabBar ──
      tabBarTheme: TabBarThemeData(
        labelColor: _zorinAccent,
        unselectedLabelColor: _zorinTextDim,
        indicatorColor: _zorinAccent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
      ),
    );
  }
}
