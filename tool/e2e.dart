// ignore_for_file: avoid_print
// End-to-end check of the app's ApiClient against a local Worker (npm run dev in worker/).
import 'package:http/http.dart' as http;
import 'package:parcel_vertices/api.dart';
import 'package:parcel_vertices/geo.dart';

Future<void> main() async {
  final api = ApiClient();
  final email = 'e2e${DateTime.now().millisecondsSinceEpoch}@example.com';
  api.token = await api.register(email, 'password123');
  print('registered, balance ${(await api.me()).balance}');

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
  print('order ${o.orderId} -> ${o.checkoutUrl}');
  print('status: ${(await api.orderStatus(o.orderId)).status}');
  // Simulate the gateway page being paid (mock provider only).
  final r = await http.post(o.checkoutUrl);
  print('mock pay: ${r.statusCode} ${r.body}');
  final st = await api.orderStatus(o.orderId);
  print('status: ${st.status}, balance ${st.balance}');
  final u2 = await api.unlock('01.16.03.010.076');
  print('paid unlock ok, balance ${u2.balance}');
  await api.logout();
  try {
    await api.me();
  } on ApiException catch (e) {
    print('after logout -> ${e.key} (${e.status})');
  }
}

