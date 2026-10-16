import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

class Settings extends ChangeNotifier {
  String lang = 'ka';
  ThemeMode theme = ThemeMode.system;

  S get s => S(lang);

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      lang = p.getString('lang') ?? lang;
      theme = ThemeMode.values.firstWhere(
        (m) => m.name == p.getString('theme'),
        orElse: () => ThemeMode.system,
      );
    } catch (_) {}
  }

  Future<void> setLang(String v) async {
    lang = v;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setString('lang', v);
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode v) async {
    theme = v;
    notifyListeners();
    try {
      (await SharedPreferences.getInstance()).setString('theme', v.name);
    } catch (_) {}
  }
}
