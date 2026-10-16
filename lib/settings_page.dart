import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'settings.dart';

const releaseUrl = 'https://github.com/GIS-GEORGIA/parcel-vertices/releases/latest';

const _githubMark =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path fill="currentColor" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>';

/// GitHub mark that bobs and tilts continuously; spins once on tap.
class AnimatedGithubIcon extends StatefulWidget {
  final double size;
  final Color color;
  const AnimatedGithubIcon({super.key, this.size = 40, required this.color});
  @override
  State<AnimatedGithubIcon> createState() => _AnimatedGithubIconState();
}

class _AnimatedGithubIconState extends State<AnimatedGithubIcon>
    with TickerProviderStateMixin {
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void dispose() {
    _idle.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _spin.forward(from: 0),
      child: AnimatedBuilder(
        animation: Listenable.merge([_idle, _spin]),
        builder: (_, child) {
          final t = _idle.value * 2 * math.pi;
          return Transform.translate(
            offset: Offset(0, math.sin(t) * 3),
            child: Transform.rotate(
              angle: math.sin(t) * 0.08 +
                  Curves.easeInOutBack.transform(_spin.value) * 2 * math.pi,
              child: child,
            ),
          );
        },
        child: SvgPicture.string(
          _githubMark.replaceAll('currentColor',
              '#${widget.color.toARGB32().toRadixString(16).substring(2)}'),
          width: widget.size,
          height: widget.size,
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final Settings settings;
  const SettingsPage({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.s;
        return Scaffold(
          appBar: AppBar(title: Text(s['settings'])),
          body: ListView(padding: const EdgeInsets.all(16), children: [
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
