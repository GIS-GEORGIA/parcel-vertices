import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'session.dart';
import 'settings.dart';

const releaseUrl = 'https://github.com/GIS-GEORGIA/parcel-vertices/releases/latest';

/// LottieFiles "GitHub icon black" animation, tinted to the current text colour.
class AnimatedGithubIcon extends StatelessWidget {
  final double size;
  final Color color;
  const AnimatedGithubIcon({super.key, this.size = 40, required this.color});

  @override
  Widget build(BuildContext context) => ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: Lottie.asset('assets/github.lottie',
            width: size,
            height: size,
            repeat: true,
            errorBuilder: (_, _, _) => Icon(Icons.code, size: size, color: color)),
      );
}

class SettingsPage extends StatelessWidget {
  final Settings settings;
  final Session session;
  const SettingsPage({super.key, required this.settings, required this.session});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.s;
        return Scaffold(
          appBar: AppBar(title: Text(s['settings'])),
          body: ListView(padding: const EdgeInsets.all(16), children: [
            Text(s['account'], style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: session,
              builder: (_, _) => Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(session.email ?? ''),
                  subtitle: Text(s.f('balance', [session.balance])),
                  trailing: TextButton(
                    onPressed: () async {
                      await session.signOut();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Text(s['logout']),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(s['language'], style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'ka', label: Text('ქართული')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {settings.lang},
              onSelectionChanged: (v) => settings.setLang(v.first),
            ),
            const SizedBox(height: 24),
            Text(s['theme'], style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: [
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto),
                    label: Text(s['theme_system'])),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode),
                    label: Text(s['theme_light'])),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode),
                    label: Text(s['theme_dark'])),
              ],
              selected: {settings.theme},
              onSelectionChanged: (v) => settings.setTheme(v.first),
            ),
            const SizedBox(height: 24),
            Text(s['about'], style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: AnimatedGithubIcon(
                    color: Theme.of(context).colorScheme.onSurface),
                title: Text(s['github_release']),
                subtitle: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (_, snap) => Text(snap.hasData
                      ? '${s['version']}: ${snap.data!.version}+${snap.data!.buildNumber}'
                      : '…'),
                ),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchUrl(Uri.parse(releaseUrl),
                    mode: LaunchMode.externalApplication),
              ),
            ),
          ]),
        );
      },
    );
  }
}
