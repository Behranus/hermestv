import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bbaiphoto/l10n/app_localizations.dart';

class LocaleProvider extends ChangeNotifier {
  String _lang = 'tr';
  String get lang => _lang;
  AppLocalizations get loc => AppLocalizations(_lang);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('lang') ?? 'tr';
    notifyListeners();
  }

  Future<void> setLocale(String lang) async {
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lang', lang);
    notifyListeners();
  }
}
