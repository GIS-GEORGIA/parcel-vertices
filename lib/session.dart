import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  /// Opens Google sign-in in the browser and polls the Worker until it hands out a session.
  Future<void> signInWithGoogle({required bool Function() cancelled}) async {
    final b = await api.googleBegin();
    if (!await launchUrl(b.url, mode: LaunchMode.externalApplication)) {
      throw ApiException('cannot_open');
    }
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (!cancelled() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (cancelled()) return;
      try {
        final r = await api.googlePoll(b.id, b.secret);
        if (r.status == 'ok' && r.token != null) {
          await _store(r.token!);
          await refresh();
          return;
        }
        if (r.status == 'denied') throw ApiException('err_google_denied');
        if (r.status == 'failed') throw ApiException('err_google_failed');
      } on ApiException catch (e) {
        // Transient network errors: keep polling. Anything else is final.
        if (e.key != 'err_network') rethrow;
      }
    }
    if (!cancelled()) throw ApiException('err_google_timeout');
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
