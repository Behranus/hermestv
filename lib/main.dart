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

  ThemeData _buildTheme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : scheme.surface,
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
