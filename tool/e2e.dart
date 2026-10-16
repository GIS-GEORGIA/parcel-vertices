// ignore_for_file: avoid_print
// End-to-end check of the app's ApiClient against a LOCAL Worker with DEV_LOGIN=1
// (cd worker && npm run dev). Run: dart run tool/e2e.dart --dart-define=API_BASE=http://localhost:8787
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:parcel_vertices/api.dart';
import 'package:parcel_vertices/geo.dart';

Future<void> main() async {
  const base = apiBase;
  final api = ApiClient();
  final email = 'e2e${DateTime.now().millisecondsSinceEpoch}@example.com';
  final r0 = await http.post(Uri.parse('$base/auth/dev-login'), body: jsonEncode({'email': email}));
  api.token = (jsonDecode(r0.body) as Map)['token'];
  print('signed in (dev), balance ${(await api.me()).balance}');

  final p = await api.preview('03.03.26.242');
  print('preview: ${p.vertices} vertices, demo=${p.demo}, unlocked=${p.unlocked}');
  final u = await api.unlock(p.code);
  print('demo unlock: ${parseWkt(u.wkt).first.pts.length} pts, balance ${u.balance}');

  try {
    await api.unlock('01.16.03.010.076');
  } on ApiException catch (e) {
    print('paid unlock without credits -> ${e.key} (${e.status})');
  }

  final o = await api.createOrder('pack10');
  print('status: ${(await api.orderStatus(o.orderId)).status}');
  final r = await http.post(o.checkoutUrl); // mock gateway page (local only)
  print('mock pay: ${r.statusCode}');
  final st = await api.orderStatus(o.orderId);
  print('status: ${st.status}, balance ${st.balance}');
  print('paid unlock ok, balance ${(await api.unlock('01.16.03.010.076')).balance}');

  final g = await api.googleBegin();
  print('google url ok: ${g.url.host}, poll: ${(await api.googlePoll(g.id, g.secret)).status}');
  await api.logout();
  try {
    await api.me();
  } on ApiException catch (e) {
    print('after logout -> ${e.key} (${e.status})');
  }
}
