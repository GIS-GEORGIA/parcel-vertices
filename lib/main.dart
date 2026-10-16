import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'dxf.dart';
import 'geo.dart';
import 'napr_client.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ნაკვეთის წვეროები',
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

enum Crs { wgs84, utm }

class _HomePageState extends State<HomePage> {
  final _code = TextEditingController();
  final _client = NaprClient();
  bool _busy = false;
  String? _error, _title;
  List<Ring> _rings = [];
  Crs _crs = Crs.utm;
  int _zone = 38;

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final m = await _client.search(_code.text);
      if (m.isEmpty) throw NaprException('კოდი ვერ მოიძებნა: ${_code.text}');
      final feats = await _client.features(m.first.lbl);
      final rings = parseWkt(feats.first.wkt);
      setState(() {
        _rings = rings;
        _title = '${m.first.code} — ${m.first.address}';
        if (rings.isNotEmpty && rings.first.pts.isNotEmpty) {
          _zone = autoZone(rings.first.pts.first.lon);
        }
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _rings = [];
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  /// (n, ring, x, y) per vertex in the selected CRS.
  List<(int, int, String, String)> get _vertices {
    final out = <(int, int, String, String)>[];
    var n = 1;
    for (final r in _rings) {
      for (final p in r.pts) {
        if (_crs == Crs.utm) {
          final u = toUtm(p, _zone);
          out.add((n++, r.ring, u.e.toStringAsFixed(3), u.n.toStringAsFixed(3)));
        } else {
          out.add((n++, r.ring, p.lon.toStringAsFixed(8), p.lat.toStringAsFixed(8)));
        }
      }
    }
    return out;
  }

  String _csv() {
    final b = StringBuffer('N,ring,${_crs == Crs.utm ? "E,N" : "lon,lat"}\n');
    for (final v in _vertices) {
      b.writeln('${v.$1},${v.$2},${v.$3},${v.$4}');
    }
    return b.toString();
  }

  String get _base {
    final s = _code.text.trim().replaceAll(RegExp(r'[^\w.]'), '_');
    return s.isEmpty ? 'parcel' : s;
  }

  Future<void> _save(String ext, String content, MimeType mt) async {
    String msg;
    try {
      final path = await FileSaver.instance.saveFile(
        name: _base,
        bytes: Uint8List.fromList(utf8.encode(content)),
        fileExtension: ext,
        mimeType: mt,
      );
      msg = 'შენახულია: $path';
    } catch (e) {
      msg = 'შენახვა ვერ მოხერხდა: $e';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: SelectableText(msg), duration: const Duration(seconds: 6)));
  }

  @override
  Widget build(BuildContext context) {
    final latlngs = [
      for (final r in _rings) for (final p in r.pts) LatLng(p.lat, p.lon)
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('ნაკვეთის წვეროები')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                decoration: const InputDecoration(
                    labelText: 'საკადასტრო კოდი',
                    hintText: '01.19.38.003.098',
                    border: OutlineInputBorder()),
                onSubmitted: (_) => _find(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _find,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('ძებნა'),
            ),
          ]),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (_rings.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_title ?? '', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SegmentedButton<Crs>(
                segments: const [
                  ButtonSegment(value: Crs.wgs84, label: Text('WGS84')),
                  ButtonSegment(value: Crs.utm, label: Text('UTM')),
                ],
                selected: {_crs},
                onSelectionChanged: (s) => setState(() => _crs = s.first),
              ),
              if (_crs == Crs.utm)
                DropdownButton<int>(
                  value: _zone,
                  items: const [
                    DropdownMenuItem(value: 37, child: Text('37N (EPSG:32637)')),
                    DropdownMenuItem(value: 38, child: Text('38N (EPSG:32638)')),
                  ],
                  onChanged: (v) => setState(() => _zone = v!),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('კოპირება'),
                onPressed: () => Clipboard.setData(ClipboardData(text: _csv())),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.table_chart),
                label: const Text('CSV'),
                onPressed: () => _save('csv', _csv(), MimeType.csv),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.architecture),
                label: const Text('DXF'),
                onPressed: () => _save('dxf',
                    buildDxf(_rings, utm: _crs == Crs.utm, zone: _zone), MimeType.other),
              ),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(builder: (c, box) {
                final wide = box.maxWidth > 700;
                final table = SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        const DataColumn(label: Text('N')),
                        const DataColumn(label: Text('რგოლი')),
                        DataColumn(label: Text(_crs == Crs.utm ? 'E (X)' : 'lon')),
                        DataColumn(label: Text(_crs == Crs.utm ? 'N (Y)' : 'lat')),
                      ],
                      rows: [
                        for (final v in _vertices)
                          DataRow(cells: [
                            DataCell(Text('${v.$1}')),
                            DataCell(Text(v.$2 == 0 ? 'გარე' : 'შიდა ${v.$2}')),
                            DataCell(SelectableText(v.$3)),
                            DataCell(SelectableText(v.$4)),
                          ]),
                      ],
                    ),
                  ),
                );
                final map = FlutterMap(
                  options: MapOptions(
                    initialCameraFit: CameraFit.coordinates(
                        coordinates: latlngs, padding: const EdgeInsets.all(30)),
                  ),
                  children: [
                    TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'ge.gisgeorgia.parcel_vertices'),
                    PolygonLayer(polygons: [
                      for (final r in _rings)
                        Polygon(
                            points: [for (final p in r.pts) LatLng(p.lat, p.lon)],
                            color: Colors.green.withValues(alpha: .25),
                            borderColor: Colors.green,
                            borderStrokeWidth: 2),
                    ]),
                    MarkerLayer(markers: [
                      for (var i = 0; i < latlngs.length; i++)
                        Marker(
                          point: latlngs[i],
                          width: 24,
                          height: 24,
                          child: CircleAvatar(
                              backgroundColor: Colors.red,
                              child: Text('${i + 1}',
                                  style: const TextStyle(fontSize: 10, color: Colors.white))),
                        ),
                    ]),
                  ],
                );
                return wide
                    ? Row(children: [Expanded(child: table), Expanded(child: map)])
                    : Column(children: [Expanded(child: map), Expanded(child: table)]);
              }),
            ),
          ],
        ]),
      ),
    );
  }
}
