import 'package:flutter_test/flutter_test.dart';
import 'package:parcel_vertices/dxf.dart';
import 'package:parcel_vertices/geo.dart';

void main() {
  test('polygon parse drops closing vertex', () {
    final r = parseWkt('POLYGON((44 41,44.1 41,44.1 41.1,44 41))');
    expect(r.single.pts.length, 3);
  });
  test('multipolygon with hole', () {
    final r = parseWkt(
        'MULTIPOLYGON(((0 0,10 0,10 10,0 0),(1 1,2 1,2 2,1 1)),((20 20,21 20,21 21,20 20)))');
    expect(r.length, 3);
    expect(r[1].ring, 1);
    expect(r[2].polygon, 1);
    expect(r[2].pts.length, 3);
  });
  test('UTM central meridian gives 500000', () {
    expect(toUtm(const LonLat(45, 0), 38).e, closeTo(500000, 0.001));
  });
  test('UTM 38N Tbilisi plausible', () {
    final u = toUtm(const LonLat(44.8, 41.7), 38);
    expect(u.e, closeTo(483400, 500));
    expect(u.n, closeTo(4617500, 1500));
  });
  test('dxf ends with EOF', () {
    final d = buildDxf(parseWkt('POLYGON((44 41,44.1 41,44.1 41.1,44 41))'),
        utm: true, zone: 38);
    expect(d.trim().endsWith('EOF'), isTrue);
    expect('POINT'.allMatches(d).length, 3);
  });
}
