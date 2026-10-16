// ignore_for_file: avoid_print
import 'package:parcel_vertices/geo.dart';
import 'package:parcel_vertices/napr_client.dart';

Future<void> main(List<String> a) async {
  final c = NaprClient();
  final m = await c.search(a.first);
  print('matches: ${m.length} ${m.first.code} ${m.first.address}');
  final f = await c.features(m.first.lbl);
  final rings = parseWkt(f.first.wkt);
  for (final r in rings) {
    print('ring ${r.ring}: ${r.pts.length} vertices');
    for (final p in r.pts.take(3)) {
      final u = toUtm(p, autoZone(p.lon));
      print('  ${p.lon},${p.lat} -> ${u.e.toStringAsFixed(3)}, ${u.n.toStringAsFixed(3)}');
    }
  }
}
