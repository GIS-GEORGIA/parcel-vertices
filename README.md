# Parcel Vertices · ნაკვეთის წვეროები

[ქართული](#ქართული) · [English](#english)

**Web:** https://parcelv.qgis.ge · **გადმოწერა / Download:** [უახლესი რელიზი / Latest release](https://github.com/GIS-GEORGIA/parcel-vertices/releases/latest)

---

## ქართული

### რას აკეთებს
შეიყვანე **საკადასტრო კოდი** (მაგ. `01.13.08.001.009`) და აპლიკაცია:

1. პოულობს ნაკვეთს საჯარო საკადასტრო სერვისზე (maps.gov.ge) — შესვლა და ანგარიში არ სჭირდება;
2. გიჩვენებს ნაკვეთის **ყველა წვეროს (კუთხის წერტილს)** დანომრილ ცხრილად, ცალკე გარე და შიდა რგოლებით;
3. აჩვენებს ნაკვეთს რუკაზე წვეროების ნომრებით (OpenStreetMap);
4. გაძლევს კოორდინატებს ორ სისტემაში:
   - **WGS84** (EPSG:4326, გრძედი/განედი) — GPS მოწყობილობებისთვის;
   - **UTM 37N / 38N** (EPSG:32637 / 32638, მეტრებში) — ტაქეომეტრისა და CAD-ისთვის. ზონა ავტომატურად შეირჩევა, საჭიროების შემთხვევაში ხელით შეგიძლია შეცვალო;
5. ახდენს ექსპორტს:
   - **CSV** — ცხრილი Excel-ისთვის;
   - **DXF** — საზღვარი (პოლილაინი), წვეროები (წერტილები) და ნომრები (ტექსტი) ცალკე ფენებზე (`BOUNDARY`, `VERTICES`, `LABELS`); იხსნება AutoCAD-ში, QGIS-ში, ტაქეომეტრის პროგრამებში;
   - **კოპირება** ბუფერში;
   - **გაზიარება**: WhatsApp, Viber, Telegram, ელფოსტა, SMS, ან სისტემური გაზიარება (Messenger და სხვ.) CSV და DXF ფაილებით.

**პარამეტრები:** ენა (ქართული / English), თემა (ღია / მუქი / სისტემის), აპლიკაციის ვერსია და ბმული უახლეს რელიზზე.

### მხარდაჭერილი მოწყობილობები

| პლატფორმა | სტატუსი | შენიშვნა |
|---|---|---|
| Android | ✅ | APK რელიზებში; ხელმოწერილია debug გასაღებით, ამიტომ ინსტალაციისას საჭიროა „უცნობი წყაროებიდან ინსტალაციის" ნებართვა |
| Windows 10/11 (x64) | ✅ | აიგება წყაროდან (იხ. ქვემოთ) |
| Web | ⚠️ | კოდში არის, მაგრამ maps.gov.ge-ის CORS შეზღუდვის გამო ბრაუზერში ძებნა შეიძლება არ იმუშაოს (საჭიროა პროქსი) |
| iOS / macOS / Linux | ❌ | არ არის შემოწმებული |

საჭიროა ინტერნეტი (ძებნისთვის და რუკისთვის).

### ინსტალაცია
- **Android:** გადმოწერე `.apk` [რელიზებიდან](https://github.com/GIS-GEORGIA/parcel-vertices/releases/latest) და გახსენი.
- **Windows / წყაროდან აგება:** დააინსტალირე [Flutter](https://docs.flutter.dev/get-started/install) (და Windows-ზე Visual Studio „Desktop development with C++"), შემდეგ:

```bash
git clone https://github.com/GIS-GEORGIA/parcel-vertices.git
cd parcel-vertices
flutter pub get
flutter run -d windows          # ან: flutter build apk --release
flutter test
```

### პრობლემების გადაჭრა

| სიმპტომი | მიზეზი / გამოსავალი |
|---|---|
| „კოდი ვერ მოიძებნა" | შეამოწმე კოდის ფორმატი (წერტილებით, მაგ. `01.13.08.001.009`) და რომ ნაკვეთი რეესტრში არსებობს |
| „სერვისმა მოთხოვნა უარყო (Access Denied)" | maps.gov.ge დროებით ბლოკავს მოთხოვნას ან გათიშულია. სცადე მოგვიანებით ან სხვა ქსელიდან |
| „ქსელის შეცდომა" | შეამოწმე ინტერნეტი; კორპორატიულ ქსელში პროქსი/ფაიერვოლი შეიძლება ბლოკავდეს |
| რუკაზე ფონი ცარიელია | OpenStreetMap-ის ფილები ვერ ჩაიტვირთა — ინტერნეტის პრობლემა |
| DXF-ში ტექსტი ძალიან პატარაა/დიდია | UTM-ში ტექსტის სიმაღლე 1 მ-ია, WGS84-ში — ძალიან მცირე; ტაქეომეტრისთვის აირჩიე UTM |
| Android არ აინსტალირებს | ჩართე „უცნობი წყაროებიდან ინსტალაცია" ამ ფაილისთვის |
| WhatsApp/Viber არ იხსნება | აპლიკაცია დაინსტალირებული უნდა იყოს; სხვა შემთხვევაში გამოიყენე ელფოსტა ან „სხვა…" |
| ვებ-ვერსიაში ძებნა არ მუშაობს | CORS შეზღუდვა — გამოიყენე Android ან Windows ვერსია |

### კონტაქტი და შეტყობინება პრობლემის შესახებ
- **Bug / იდეა:** გახსენი [Issue](https://github.com/GIS-GEORGIA/parcel-vertices/issues/new) — მიუთითე ვერსია (პარამეტრები → ვერსია), მოწყობილობა/OS, ნაკვეთის კოდი და რა მოხდა.
- **ელფოსტა:** [aigroegsig@gmail.com](mailto:aigroegsig@gmail.com) (GIS GEORGIA) · [kapan.gio777@gmail.com](mailto:kapan.gio777@gmail.com) (ავტორი)
- **ორგანიზაცია:** [GIS-GEORGIA](https://github.com/GIS-GEORGIA)
- დაკავშირებული პროექტი: [georgian_cadastre QGIS პლაგინი](https://github.com/GIS-GEORGIA/qgis-plugins-repo/tree/main/georgian_cadastre) — იგივე API.

### მონაცემები და კონფიდენციალობა
აპლიკაცია იღებს მხოლოდ ნაკვეთის გეომეტრიასა და მისამართს. მესაკუთრის პერსონალურ მონაცემებს არ კითხულობს. შენი ძებნები არსად ინახება; ლოკალურად ინახება მხოლოდ ენისა და თემის არჩევანი. მონაცემები მოდის maps.gov.ge-დან; ზუსტი მნიშვნელობა სამართლებრივი/საინჟინრო მიზნით დაადასტურე ოფიციალურ დოკუმენტებთან.

### ტექნიკური ინფორმაცია
Flutter · API: `maps.gov.ge` (`/map/portal/search`, `/lr/bo/mg/getinfo.alpha`) · გეომეტრია WGS84 WKT-ით, UTM გადაყვანა (Krüger-ის მწკრივი) აპშივე · პაკეტები: `flutter_map`, `file_saver`, `share_plus`, `url_launcher`, `lottie`, `shared_preferences`.

---

## English

### What it does
Enter a **cadastral code** (e.g. `01.13.08.001.009`) and the app:

1. looks the parcel up on Georgia's public cadastre service (maps.gov.ge) — no login or account needed;
2. lists **every vertex (corner point)** in a numbered table, with outer and inner rings (holes) separated;
3. shows the parcel on a map with numbered vertices (OpenStreetMap);
4. gives coordinates in two systems:
   - **WGS84** (EPSG:4326, lon/lat) — for GPS devices;
   - **UTM 37N / 38N** (EPSG:32637 / 32638, metres) — for total stations and CAD. The zone is picked automatically and can be changed manually;
5. exports:
   - **CSV** — for Excel;
   - **DXF** — boundary (polyline), vertices (points) and numbers (text) on separate layers (`BOUNDARY`, `VERTICES`, `LABELS`); opens in AutoCAD, QGIS and total-station software;
   - **Copy** to clipboard;
   - **Share** via WhatsApp, Viber, Telegram, email, SMS, or the system share sheet (Messenger etc.) with CSV and DXF attached.

**Settings:** language (Georgian / English), theme (light / dark / system), app version and a link to the latest release.

### Supported devices

| Platform | Status | Notes |
|---|---|---|
| Android | ✅ | APK in releases; signed with a debug key, so installing requires allowing unknown sources |
| Windows 10/11 (x64) | ✅ | Build from source (see below) |
| Web | ⚠️ | Compiles, but maps.gov.ge CORS rules may block search in a browser (a proxy is needed) |
| iOS / macOS / Linux | ❌ | Not tested |

An internet connection is required (search and map tiles).

### Install
- **Android:** download the `.apk` from [Releases](https://github.com/GIS-GEORGIA/parcel-vertices/releases/latest) and open it.
- **Windows / build from source:** install [Flutter](https://docs.flutter.dev/get-started/install) (plus Visual Studio "Desktop development with C++" on Windows), then:

```bash
git clone https://github.com/GIS-GEORGIA/parcel-vertices.git
cd parcel-vertices
flutter pub get
flutter run -d windows          # or: flutter build apk --release
flutter test
```

### Troubleshooting

| Symptom | Cause / fix |
|---|---|
| "Code not found" | Check the code format (with dots, e.g. `01.13.08.001.009`) and that the parcel exists in the registry |
| "The service denied the request (Access Denied)" | maps.gov.ge is temporarily blocking requests or is down. Try later or from another network |
| "Network error" | Check your connection; a corporate proxy/firewall may block it |
| Map background is empty | OpenStreetMap tiles failed to load — connectivity issue |
| DXF text looks too small/large | In UTM text height is 1 m; in WGS84 it is tiny. Choose UTM for total stations |
| Android won't install | Allow "install unknown apps" for the app you opened the file with |
| WhatsApp/Viber won't open | The app must be installed; otherwise use email or "More…" |
| Search fails in the web version | CORS restriction — use the Android or Windows version |

### Contact & reporting problems
- **Bug / idea:** open an [Issue](https://github.com/GIS-GEORGIA/parcel-vertices/issues/new) and include the app version (Settings → Version), device/OS, the parcel code and what happened.
- **Email:** [aigroegsig@gmail.com](mailto:aigroegsig@gmail.com) (GIS GEORGIA) · [kapan.gio777@gmail.com](mailto:kapan.gio777@gmail.com) (author)
- **Organization:** [GIS-GEORGIA](https://github.com/GIS-GEORGIA)
- Related project: [georgian_cadastre QGIS plugin](https://github.com/GIS-GEORGIA/qgis-plugins-repo/tree/main/georgian_cadastre) — same API.

### Data & privacy
The app reads only the parcel geometry and address. It does not read owners' personal data. Your searches are not stored; only the language and theme choice are saved locally. Data comes from maps.gov.ge; verify exact values against official documents before legal or engineering use.

### Tech
Flutter · API: `maps.gov.ge` (`/map/portal/search`, `/lr/bo/mg/getinfo.alpha`) · geometry as WGS84 WKT, UTM conversion (Krüger series) done in-app · packages: `flutter_map`, `file_saver`, `share_plus`, `url_launcher`, `lottie`, `shared_preferences`.

## Development: accounts & credits (Worker)

The app now signs users in and unlocks coordinates through the Worker in `worker/`.

```bash
cd worker && npm install && npm run db:local && npm run dev   # http://localhost:8787
flutter run -d windows --dart-define=API_BASE=http://localhost:8787
```

Android emulator: use `--dart-define=API_BASE=http://10.0.2.2:8787`. The public APK/web build must not be released until the Worker is deployed and `API_BASE` points to it.
