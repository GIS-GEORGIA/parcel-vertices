import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

/// Signed-in user + credit balance. The token lives in shared_preferences
/// (plain storage; move to flutter_secure_storage before a public launch).
class Session extends ChangeNotifier {
  final api = ApiClient();
  String? email;
  int balance = 0;
  bool ready = false;

  bool get loggedIn => api.token != null;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      api.token = p.getString('token');
      if (api.token != null) {
        final m = await api.me();
        email = m.email;
        balance = m.balance;
      }
    } on ApiException catch (e) {
      // Only a rejected token logs out; being offline keeps the session.
      if (e.status == 401) await _clear();
    } catch (_) {}
    ready = true;
    notifyListeners();
  }

  Future<void> _store(String token) async {
    api.token = token;
    try {
      (await SharedPreferences.getInstance()).setString('token', token);
    } catch (_) {}
  }

  Future<void> _clear() async {
    api.token = null;
    email = null;
    balance = 0;
    try {
      (await SharedPreferences.getInstance()).remove('token');
    } catch (_) {}
  }

  Future<void> signIn(String email, String password, {required bool register}) async {
    final t = register ? await api.register(email, password) : await api.login(email, password);
    await _store(t);
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final m = await api.me();
      email = m.email;
      balance = m.balance;
    } on ApiException catch (e) {
      if (e.status == 401) await _clear();
    }
    notifyListeners();
  }

  void setBalance(int b) {
    balance = b;
    notifyListeners();
  }

  /// Call when any request returns 401.
  Future<void> expire() async {
    await _clear();
    notifyListeners();
  }

  Future<void> signOut() async {
    await api.logout();
    await _clear();
    notifyListeners();
  }
}
