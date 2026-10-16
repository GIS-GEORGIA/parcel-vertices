import 'dart:math' as math;

class LonLat {
  final double lon, lat;
  const LonLat(this.lon, this.lat);
}

/// A polygon ring with an index, used for the vertex table.
class Ring {
  final int polygon; // polygon index inside a MULTIPOLYGON
  final int ring; // 0 = outer, >0 = hole
  final List<LonLat> pts; // closing duplicate removed
  Ring(this.polygon, this.ring, this.pts);
}

final _nums = RegExp(r'-?\d+(?:\.\d+)?(?:E[-+]?\d+)?');

List<LonLat> _pts(String body) {
  final v = _nums.allMatches(body).map((m) => double.parse(m.group(0)!)).toList();
  return [for (var i = 0; i + 1 < v.length; i += 2) LonLat(v[i], v[i + 1])];
}

List<LonLat> _open(List<LonLat> p) =>
    (p.length > 1 && p.first.lon == p.last.lon && p.first.lat == p.last.lat)
        ? p.sublist(0, p.length - 1)
        : p;

/// Splits "(a),(b)" style ring lists on the "),(" separators.
List<String> _splitRings(String s) => s.split(RegExp(r'\)\s*,\s*\('));

/// Parses POINT / LINESTRING / POLYGON / MULTIPOLYGON WKT into rings of vertices.
List<Ring> parseWkt(String wkt) {
  final s = wkt.trim().toUpperCase();
  final rings = <Ring>[];
  if (s.startsWith('MULTIPOLYGON')) {
    final body = s.substring(12).trim();
    // strip outer "( ... )" then split polygons on ")),((" boundaries
    final inner = body.substring(1, body.length - 1).trim();
    final polys = inner.split(RegExp(r'\)\s*\)\s*,\s*\(\s*\('));
    for (var pi = 0; pi < polys.length; pi++) {
      final p = polys[pi].replaceAll(RegExp(r'^\s*\(\s*\(|\)\s*\)\s*$'), '');
      var ri = 0;
      for (final r in _splitRings(p)) {
        rings.add(Ring(pi, ri++, _open(_pts(r))));
      }
    }
  } else if (s.startsWith('POLYGON')) {
    final body = s.substring(7).trim();
    final inner = body.substring(2, body.length - 2);
    var ri = 0;
    for (final r in _splitRings(inner)) {
      rings.add(Ring(0, ri++, _open(_pts(r))));
    }
  } else if (s.startsWith('LINESTRING') || s.startsWith('POINT')) {
    rings.add(Ring(0, 0, _pts(s)));
  } else {
    throw FormatException('Unsupported WKT: ${wkt.substring(0, math.min(30, wkt.length))}');
  }
  return rings;
}

/// WGS84 -> UTM (Krüger series). Returns (e: easting, n: northing).
({double e, double n}) toUtm(LonLat p, int zone) {
  const a = 6378137.0, f = 1 / 298.257223563, k0 = 0.9996;
  final n = f / (2 - f);
  final aa = a / (1 + n) * (1 + n * n / 4 + n * n * n * n / 64);
  final ecc = math.sqrt(f * (2 - f));
  final lat = p.lat * math.pi / 180;
  final dl = (p.lon - ((zone - 1) * 6 - 180 + 3)) * math.pi / 180;
  final t = _sinh(_atanh(math.sin(lat)) - ecc * _atanh(ecc * math.sin(lat)));
  final xi = math.atan(t / math.cos(dl));
  final eta = _atanh(math.sin(dl) / math.sqrt(1 + t * t));
  final al = [
    n / 2 - 2 * n * n / 3 + 5 * n * n * n / 16,
    13 * n * n / 48 - 3 * n * n * n / 5,
    61 * n * n * n / 240,
  ];
  var xs = xi, es = eta;
  for (var j = 1; j <= 3; j++) {
    xs += al[j - 1] * math.sin(2 * j * xi) * _cosh(2 * j * eta);
    es += al[j - 1] * math.cos(2 * j * xi) * _sinh(2 * j * eta);
  }
  return (e: 500000 + k0 * aa * es, n: k0 * aa * xs);
}

double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));
double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;

/// Georgia: zone 37N covers lon < 42°E, 38N the rest.
int autoZone(double lon) => lon < 42 ? 37 : 38;
