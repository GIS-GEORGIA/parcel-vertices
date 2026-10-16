import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Worker base URL. Override per build: --dart-define=API_BASE=https://api.example.com
/// (Android emulator reaches the host machine at http://10.0.2.2:8787).
const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:8787');

class ApiException implements Exception {
  /// l10n key (err_*, unauthorized, ...).
  final String key;
  final int status;
  final String detail;
  ApiException(this.key, {this.status = 0, this.detail = ''});
  @override
  String toString() => '$key ($status) $detail';
}

class Preview {
  final String code, address;
  final int vertices, cost;
  final bool demo, unlocked;
  final List<double> bbox; // minLon, minLat, maxLon, maxLat (coarse, ~100 m)
  Preview.fromJson(Map<String, dynamic> j)
      : code = j['code'],
        address = j['address'] ?? '',
        vertices = j['vertices'],
        cost = j['cost'],
        demo = j['demo'],
        unlocked = j['unlocked'],
        bbox = [for (final v in j['bbox']) (v as num).toDouble()];
}

class Product {
  final String id;
  final int credits, amountTetri;
  Product(this.id, this.credits, this.amountTetri);
}

class Unlocked {
  final String code, address, wkt;
  final int balance;
  Unlocked(this.code, this.address, this.wkt, this.balance);
}

class ApiClient {
  final http.Client _c;
  String? token;
  ApiClient([http.Client? c]) : _c = c ?? http.Client();

  Future<Map<String, dynamic>> _req(String method, String path, {Object? body}) async {
    final u = Uri.parse('$apiBase$path');
    final headers = {
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    http.Response r;
    try {
      final enc = body == null ? null : jsonEncode(body);
      r = await (method == 'GET'
              ? _c.get(u, headers: headers)
              : _c.post(u, headers: headers, body: enc ?? ''))
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw ApiException('err_network', detail: '$e');
    }
    Map<String, dynamic> j;
    try {
      j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('err_network', status: r.statusCode, detail: 'bad response');
    }
    if (r.statusCode >= 400) {
      throw ApiException('${j['error'] ?? 'internal'}', status: r.statusCode);
    }
    return j;
  }

  Future<String> register(String email, String password) async =>
      (await _req('POST', '/auth/register', body: {'email': email, 'password': password}))['token'];

  Future<String> login(String email, String password) async =>
      (await _req('POST', '/auth/login', body: {'email': email, 'password': password}))['token'];

  Future<void> logout() async {
    try {
      await _req('POST', '/auth/logout', body: {});
    } catch (_) {}
  }

  Future<({String email, int balance})> me() async {
    final j = await _req('GET', '/me');
    return (email: '${j['email']}', balance: j['balance'] as int);
  }

  Future<List<Product>> products() async {
    final j = await _req('GET', '/products');
    return [
      for (final p in j['products'] as List) Product(p['id'], p['credits'], p['amountTetri'])
    ];
  }

  Future<Preview> preview(String code) async =>
      Preview.fromJson(await _req('GET', '/parcels/${Uri.encodeComponent(code.trim())}'));

  Future<Unlocked> unlock(String code) async {
    final j = await _req('POST', '/parcels/${Uri.encodeComponent(code)}/unlock', body: {});
    return Unlocked(j['code'], j['address'] ?? '', j['wkt'], j['balance']);
  }

  Future<({String orderId, Uri checkoutUrl})> createOrder(String productId) async {
    final j = await _req('POST', '/orders', body: {'product_id': productId});
    return (orderId: '${j['order_id']}', checkoutUrl: Uri.parse('${j['checkout_url']}'));
  }

  Future<({String status, int balance})> orderStatus(String id) async {
    final j = await _req('GET', '/orders/$id');
    return (status: '${j['status']}', balance: j['balance'] as int);
  }
}
