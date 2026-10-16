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
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _register = true, _busy = false;
  String? _error;

  Future<void> _submit() async {
    final s = widget.settings.s;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.session.signIn(_email.text.trim(), _pass.text, register: _register);
    } on ApiException catch (e) {
      setState(() => _error = s.f(e.key, [e.detail]));
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
            Text(_register ? s['register'] : s['login'],
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(s['auth_hint']),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                  labelText: s['email'], border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                  labelText: s['password'], border: const OutlineInputBorder()),
            ),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_register ? s['register'] : s['login']),
            ),
            TextButton(
              onPressed: () => setState(() => _register = !_register),
              child: Text(_register ? s['have_account'] : s['no_account']),
            ),
          ]),
        ),
      ),
    );
  }
}
