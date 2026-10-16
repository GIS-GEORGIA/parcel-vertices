import 'dart:convert';
import 'package:http/http.dart' as http;

/// Public cadastre (maps.gov.ge) client — port of napr_client.py from the
/// georgian_cadastre QGIS plugin. Geometry is always WGS84 WKT.
class NaprException implements Exception {
  /// l10n key (err_*) plus optional detail substituted for {0}.
  final String key;
  final String detail;
  NaprException(this.key, [this.detail = '']);
  @override
  String toString() => '$key $detail';
}

class ParcelMatch {
  final String lbl, code, address;
  ParcelMatch(this.lbl, this.code, this.address);
}

class ParcelFeature {
  final String id, code, wkt;
  ParcelFeature(this.id, this.code, this.wkt);
}

class NaprClient {
  static const _search = 'https://maps.gov.ge/map/portal/search';
  static const _getinfo = 'https://maps.gov.ge/lr/bo/mg/getinfo.alpha';
  static const _headers = {
    'User-Agent': 'ParcelVertices/0.1 (+https://github.com/GIS-GEORGIA)',
    'Accept': 'application/json, text/plain, */*',
    'Referer': 'https://maps.gov.ge/map/portal/',
  };

  final http.Client _c;
  NaprClient([http.Client? c]) : _c = c ?? http.Client();

  Future<String> _text(Uri u, {Map<String, String>? form}) async {
    try {
      final r = form == null
          ? await _c.get(u, headers: _headers).timeout(const Duration(seconds: 20))
          : await _c.post(u, headers: _headers, body: form).timeout(const Duration(seconds: 20));
      final t = utf8.decode(r.bodyBytes, allowMalformed: true);
      final lead = t.trimLeft();
      final head = lead.substring(0, lead.length < 400 ? lead.length : 400).toLowerCase();
      if (head.contains('<html') &&
          (head.contains('access denied') || head.contains('oops') || head.contains('not be accessed'))) {
        throw NaprException('err_denied');
      }
      return t;
    } on NaprException {
      rethrow;
    } catch (e) {
      throw NaprException('err_network', '$e');
    }
  }

  Future<List<ParcelMatch>> search(String code) async {
    code = code.trim();
    if (code.isEmpty) throw NaprException('err_empty_code');
    final raw = await _text(Uri.parse(_search), form: {'keyword': code, 'keyword_description': ''});
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final out = <ParcelMatch>[];
    for (final r in (data['result'] as List? ?? [])) {
      final lbl = _lbl(r as Map<String, dynamic>);
      if (lbl == null) continue;
      out.add(ParcelMatch(lbl, (r['name'] ?? code).toString(),
          (r['descript'] ?? r['resulttext'] ?? '').toString()));
    }
    out.sort((a, b) => (a.code == code ? 0 : 1).compareTo(b.code == code ? 0 : 1));
    return out;
  }

  String? _lbl(Map<String, dynamic> r) {
    for (final k in ['resultlink', 'details']) {
      var v = r[k];
      if (v is Map) v = v['info_link'] ?? v['geometry_link'] ?? '';
      if (v is String && v.contains('lbl=')) {
        return v.split('lbl=')[1].split('&')[0];
      }
    }
    return null;
  }

  Future<List<ParcelFeature>> features(String lbl) async {
    // The ':' in lbl must stay literal — percent-encoding breaks the service.
    final raw = await _text(Uri.parse('$_getinfo?lbl=$lbl&lang=ka&res=shp'));
    final rows = (jsonDecode(raw)['data'] as List?) ?? [];
    final out = <ParcelFeature>[
      for (final row in rows)
        if (row['shape'] != null)
          ParcelFeature('${row['id']}', '${row['name'] ?? ''}', row['shape'] as String)
    ];
    if (out.isEmpty) throw NaprException('err_no_geom');
    return out;
  }
}
