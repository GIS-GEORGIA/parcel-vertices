import 'package:flutter/material.dart';

import 'api.dart';
import 'session.dart';
import 'settings.dart';

class AuthPage extends StatefulWidget {
  final Settings settings;
  final Session session;
  const AuthPage({super.key, required this.settings, required this.session});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _busy = false;
  bool _cancelled = false;
  String? _error;

  Future<void> _google() async {
    final s = widget.settings.s;
    setState(() {
      _busy = true;
      _cancelled = false;
      _error = null;
    });
    try {
      await widget.session.signInWithGoogle(cancelled: () => _cancelled);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = s.f(e.key, [e.detail]));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings.s;
    return Scaffold(
      appBar: AppBar(title: Text(s['app_title']), actions: [
        TextButton(
            onPressed: () =>
                widget.settings.setLang(widget.settings.lang == 'ka' ? 'en' : 'ka'),
            child: Text(widget.settings.lang == 'ka' ? 'EN' : 'KA')),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
            Text(s['app_title'], style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(s['auth_hint']),
            const SizedBox(height: 24),
            if (_busy) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 12),
              Center(child: Text(s['google_waiting'])),
              TextButton(
                onPressed: () => setState(() => _cancelled = true),
                child: Text(s['cancel']),
              ),
            ] else
              FilledButton.icon(
                onPressed: _google,
                icon: const Icon(Icons.login),
                label: Text(s['google_signin']),
              ),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ]),
        ),
      ),
    );
  }
}
