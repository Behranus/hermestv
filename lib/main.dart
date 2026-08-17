import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iptv_player/screens/home_shell.dart';
import 'package:iptv_player/screens/lock_screen.dart';
import 'package:iptv_player/services/app_target.dart';
import 'package:iptv_player/services/lock_service.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // ---- 2GB RAM'li giriş seviyesi Box'lar için bellek yönetimi ----
  // Test sunucusu gibi binlerce kanallı listelerde logolar belleği şişirip
  // (OOM/GC baskısı) tüm uygulamayı — video dahil — kasabilir. Görsel
  // önbelleğini sıkı tutarız: en fazla 240 görsel / 48 MB.
  PaintingBinding.instance.imageCache.maximumSize = 240;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;

  // Güvenlik ağı: yakalanmamış hatalar uygulamayı kapatmasın, loglansın.
  // (Ağ hatası/bozuk akış gibi durumlarda uygulama sessizce kapanmaz.)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Yakalanmamış hata: $error\n$stack');
    return true;
  };
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter hatası: ${details.exception}');
  };

  runApp(const IptvApp());
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
        home: const _LockGate(),
      ),
    );
  }

  /// Zorin OS mavisi — masaüstü deneyimindeki vurgu rengi.
  static const _zorinBlue = Color(0xFF2C79EA);

  /// Zorin OS koyu teması yüzey tonları.
  static const _zorinDarkBg = Color(0xFF191C1F);
  static const _zorinDarkSurface = Color(0xFF23272B);
  static const _zorinDarkSurfaceHigh = Color(0xFF2C3136);

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _zorinBlue,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: isDark ? _zorinDarkBg : scheme.surface,
      // Zorin tarzı: köşeler yumuşak, vurgu mavi, yüzeyler hafif katmanlı.
      cardTheme: CardThemeData(
        elevation: isDark ? 1 : 2,
        color: isDark ? _zorinDarkSurface : scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isDark
              ? BorderSide(color: Colors.white.withValues(alpha: 0.06))
              : BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _zorinDarkBg : scheme.surface,
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
        backgroundColor: isDark ? _zorinDarkSurface : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? _zorinDarkSurface : scheme.surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? _zorinDarkSurfaceHigh.withValues(alpha: 0.6)
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
        backgroundColor: isDark ? _zorinDarkSurface : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Şifre kilit kapısı: kilit açıksa önce [LockScreen] gösterilir;
/// doğru şifreyle açılınca [HomeShell]'e geçer ve oturum boyunca açık kalır.
class _LockGate extends StatefulWidget {
  const _LockGate();

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  /// null = henüz kontrol ediliyor, false = kilitli, true = açık.
  bool? _unlocked;

  @override
  void initState() {
    super.initState();
    if (AppTarget.isNoLock) {
      _unlocked = true;
    } else {
      _check();
    }
  }

  Future<void> _check() async {
    final enabled = await LockService.isEnabled();
    if (!mounted) return;
    setState(() => _unlocked = !enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unlocked!) return const HomeShell();
    return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
  }
}
