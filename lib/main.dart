import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iptv_player/screens/home_shell.dart';
import 'package:iptv_player/state/app_state.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // media_kit (libmpv) başlatılmadan önce çağrılmalıdır.
  MediaKit.ensureInitialized();

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
        title: 'IPTV Player',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        home: const HomeShell(),
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
