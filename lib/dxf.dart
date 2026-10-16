import 'geo.dart';

/// Minimal ASCII DXF (R12): boundary polylines, vertex POINTs and numbered
/// TEXT labels. X = easting/lon, Y = northing/lat.
String buildDxf(List<Ring> rings, {required bool utm, required int zone}) {
  final b = StringBuffer();
  void g(Object code, Object v) => b.write('$code\n$v\n');
  (double, double) xy(LonLat p) {
    if (!utm) return (p.lon, p.lat);
    final u = toUtm(p, zone);
    return (u.e, u.n);
  }

  final dec = utm ? 3 : 8;
  String f(double v) => v.toStringAsFixed(dec);
  final textH = utm ? 1.0 : 0.00001;

  g(0, 'SECTION');
  g(2, 'HEADER');
  g(9, '\$ACADVER');
  g(1, 'AC1009');
  g(0, 'ENDSEC');
  g(0, 'SECTION');
  g(2, 'TABLES');
  g(0, 'TABLE');
  g(2, 'LAYER');
  g(70, 3);
  for (final l in [('BOUNDARY', 7), ('VERTICES', 1), ('LABELS', 3)]) {
    g(0, 'LAYER');
    g(2, l.$1);
    g(70, 0);
    g(62, l.$2);
    g(6, 'CONTINUOUS');
  }
  g(0, 'ENDTAB');
  g(0, 'ENDSEC');
  g(0, 'SECTION');
  g(2, 'ENTITIES');
  var n = 1;
  for (final r in rings) {
    if (r.pts.length > 2) {
      g(0, 'POLYLINE');
      g(8, 'BOUNDARY');
      g(66, 1);
      g(70, 1);
      for (final p in r.pts) {
        final (x, y) = xy(p);
        g(0, 'VERTEX');
        g(8, 'BOUNDARY');
        g(10, f(x));
        g(20, f(y));
        g(30, 0);
      }
      g(0, 'SEQEND');
      g(8, 'BOUNDARY');
    }
    for (final p in r.pts) {
      final (x, y) = xy(p);
      g(0, 'POINT');
      g(8, 'VERTICES');
      g(10, f(x));
      g(20, f(y));
      g(30, 0);
      g(0, 'TEXT');
      g(8, 'LABELS');
      g(10, f(x));
      g(20, f(y));
      g(30, 0);
      g(40, textH);
      g(1, '${n++}');
    }
  }
  g(0, 'ENDSEC');
  g(0, 'EOF');
  return b.toString();
}
