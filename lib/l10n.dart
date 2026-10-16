/// Minimal ka/en string table. Use `S.of(lang)['key']`.
class S {
  final String lang;
  const S(this.lang);

  String operator [](String key) => (_t[lang] ?? _t['en']!)[key] ?? _t['en']![key] ?? key;

  /// Substitutes {0}, {1}… placeholders.
  String f(String key, List<Object?> args) {
    var s = this[key];
    for (var i = 0; i < args.length; i++) {
      s = s.replaceAll('{$i}', '${args[i]}');
    }
    return s;
  }

  static const _t = <String, Map<String, String>>{
    'ka': {
      'app_title': 'ნაკვეთის წვეროები',
      'code_label': 'საკადასტრო კოდი',
      'search': 'ძებნა',
      'copy': 'კოპირება',
      'share': 'გაზიარება',
      'other_share': 'Messenger / სხვა… (+CSV, DXF)',
      'email': 'ელფოსტა',
      'ring': 'რგოლი',
      'outer': 'გარე',
      'inner': 'შიდა {0}',
      'saved': 'შენახულია: {0}',
      'save_failed': 'შენახვა ვერ მოხერხდა: {0}',
      'save_title': 'ფაილის შენახვა',
      'cannot_open': 'აპლიკაცია ვერ გაიხსნა',
      'settings': 'პარამეტრები',
      'language': 'ენა',
      'theme': 'თემა',
      'theme_system': 'სისტემის',
      'theme_light': 'ღია',
      'theme_dark': 'მუქი',
      'about': 'აპლიკაციის შესახებ',
      'version': 'ვერსია',
      'github_release': 'GitHub — უახლესი რელიზი',
      'err_empty_code': 'საკადასტრო კოდი ცარიელია',
      'err_network': 'ქსელის შეცდომა: {0}',
      'err_denied': 'სერვისმა მოთხოვნა უარყო (Access Denied)',
      'err_not_found': 'კოდი ვერ მოიძებნა: {0}',
      'err_no_geom': 'ამ ნაკვეთზე გეომეტრია ვერ მოიძებნა',
    },
    'en': {
      'app_title': 'Parcel Vertices',
      'code_label': 'Cadastral code',
      'search': 'Search',
      'copy': 'Copy',
      'share': 'Share',
      'other_share': 'Messenger / more… (+CSV, DXF)',
      'email': 'Email',
      'ring': 'Ring',
      'outer': 'Outer',
      'inner': 'Inner {0}',
      'saved': 'Saved: {0}',
      'save_failed': 'Could not save: {0}',
      'save_title': 'Save file',
      'cannot_open': 'Could not open the app',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'theme_system': 'System',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'about': 'About',
      'version': 'Version',
      'github_release': 'GitHub — latest release',
      'err_empty_code': 'Cadastral code is empty',
      'err_network': 'Network error: {0}',
      'err_denied': 'The service denied the request (Access Denied)',
      'err_not_found': 'Code not found: {0}',
      'err_no_geom': 'No geometry found for this parcel',
    },
  };
}
