import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dxf.dart';
import 'geo.dart';
import 'l10n.dart';
import 'napr_client.dart';
import 'settings.dart';
import 'settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = Settings();
  await settings.load();
  runApp(App(settings: settings));
}

class App extends StatelessWidget {
  final Settings settings;
  const App({super.key, required this.settings});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: settings,
        builder: (_, _) => MaterialApp(
          title: settings.s['app_title'],
          themeMode: settings.theme,
          theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
          darkTheme: ThemeData(
              colorSchemeSeed: Colors.green,
              brightness: Brightness.dark,
              useMaterial3: true),
          home: HomePage(settings: settings),
        ),
      );
}

class HomePage extends StatefulWidget {
  final Settings settings;
  const HomePage({super.key, required this.settings});
  @override
  State<HomePage> createState() => _HomePageState();
}

enum Crs { wgs84, utm }

class _HomePageState extends State<HomePage> {
  final _code = TextEditingController();
  final _client = NaprClient();
  S get s => widget.settings.s;
  Object? _errObj;
  bool _busy = false;
  String? _title;
  List<Ring> _rings = [];
  Crs _crs = Crs.utm;
  int _zone = 38;

  String _errText() {
    final e = _errObj;
    if (e is NaprException) return s.f(e.key, [e.detail]);
    return s.f('err_network', [e]);
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _errObj = null;
    });
    try {
      final m = await _client.search(_code.text);
      if (m.isEmpty) throw NaprException('err_not_found', _code.text);
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
        _errObj = e;
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
      final path = await FileSaver.instance.saveAs(
        name: _base,
        bytes: Uint8List.fromList(utf8.encode(content)),
        fileExtension: ext,
        mimeType: mt,
        dialogTitle: s['save_title'],
      );
      if (path == null) return; // user cancelled
      msg = s.f('saved', [path]);
    } catch (e) {
      msg = s.f('save_failed', [e]);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: SelectableText(msg), duration: const Duration(seconds: 6)));
  }


  String _shareText() {
    final b = StringBuffer('${_title ?? _base}\n');
    b.writeln(_crs == Crs.utm ? 'UTM ${_zone}N (EPSG:326$_zone)' : 'WGS84 (EPSG:4326)');
    for (final v in _vertices) {
      b.writeln('${v.$1}. ${v.$3}, ${v.$4}');
    }
    return b.toString();
  }

  Future<void> _open(Uri u) async {
    final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s['cannot_open'])));
    }
  }

  Future<void> _share(String target) async {
    final t = _shareText();
    final q = Uri.encodeComponent(t);
    switch (target) {
      case 'whatsapp':
        return _open(Uri.parse('https://wa.me/?text=$q'));
      case 'viber':
        return _open(Uri.parse('viber://forward?text=$q'));
      case 'telegram':
        return _open(Uri.parse('https://t.me/share/url?url=%20&text=$q'));
      case 'email':
        return _open(Uri.parse(
            'mailto:?subject=${Uri.encodeComponent(_title ?? _base)}&body=$q'));
      case 'sms':
        return _open(Uri.parse('sms:?body=$q'));
      default: // system sheet: Messenger, Facebook, etc., with CSV + DXF attached
        final csv = Uint8List.fromList(utf8.encode(_csv()));
        final dxf = Uint8List.fromList(utf8.encode(
            buildDxf(_rings, utm: _crs == Crs.utm, zone: _zone)));
        await SharePlus.instance.share(ShareParams(
          text: t,
          subject: _title ?? _base,
          files: [
            XFile.fromData(csv, name: '$_base.csv', mimeType: 'text/csv'),
            XFile.fromData(dxf, name: '$_base.dxf', mimeType: 'application/dxf'),
          ],
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final latlngs = [
      for (final r in _rings) for (final p in r.pts) LatLng(p.lat, p.lon)
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s['app_title']), actions: [
        IconButton(
          tooltip: s['settings'],
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(settings: widget.settings))),
        ),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                decoration: InputDecoration(
                    labelText: s['code_label'],
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
              label: Text(s['search']),
            ),
          ]),
          if (_errObj != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errText(),
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
                label: Text(s['copy']),
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
              PopupMenuButton<String>(
                tooltip: s['share'],
                onSelected: _share,
                child: Chip(avatar: const Icon(Icons.share, size: 18), label: Text(s['share'])),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                  const PopupMenuItem(value: 'viber', child: Text('Viber')),
                  const PopupMenuItem(value: 'telegram', child: Text('Telegram')),
                  PopupMenuItem(value: 'email', child: Text(s['email'])),
                  const PopupMenuItem(value: 'sms', child: Text('SMS')),
                  PopupMenuItem(value: 'system', child: Text(s['other_share'])),
                ],
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
                        DataColumn(label: Text(s['ring'])),
                        DataColumn(label: Text(_crs == Crs.utm ? 'E (X)' : 'lon')),
                        DataColumn(label: Text(_crs == Crs.utm ? 'N (Y)' : 'lat')),
                      ],
                      rows: [
                        for (final v in _vertices)
                          DataRow(cells: [
                            DataCell(Text('${v.$1}')),
                            DataCell(Text(v.$2 == 0 ? s['outer'] : s.f('inner', [v.$2]))),
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
