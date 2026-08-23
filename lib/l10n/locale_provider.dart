import 'package:flutter/material.dart';
import 'package:hermestv/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dil seçimini yöneten ChangeNotifier.
/// SharedPreferences'a kaydeder, uygulama yeniden açıldığında korunur.
class LocaleProvider extends ChangeNotifier {
  String _lang = 'tr'; // varsayılan Türkçe

  String get lang => _lang;
  AppLocalizations get loc => AppLocalizations(_lang);

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_locale');
    if (saved != null && supportedLocales.contains(saved)) {
      _lang = saved;
      notifyListeners();
    }
  }

  Future<void> setLocale(String lang) async {
    if (!supportedLocales.contains(lang) || lang == _lang) return;
    _lang = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', lang);
  }
}
