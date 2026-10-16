import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'session.dart';
import 'settings.dart';

String gel(int tetri) =>
    tetri % 100 == 0 ? '${tetri ~/ 100} ₾' : '${(tetri / 100).toStringAsFixed(2)} ₾';

class StorePage extends StatefulWidget {
  final Settings settings;
  final Session session;
  const StorePage({super.key, required this.settings, required this.session});
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  List<Product>? _products;
  String? _error, _pendingOrder;
  bool _busy = false;
  Timer? _poll;
  int _polls = 0;

  Session get session => widget.session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String _err(ApiException e) => widget.settings.s.f(e.key, [e.detail]);

  Future<void> _load() async {
    try {
      final p = await session.api.products();
      if (mounted) setState(() => _products = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = _err(e));
    }
  }

  Future<void> _buy(Product p) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final o = await session.api.createOrder(p.id);
      final ok = await launchUrl(o.checkoutUrl, mode: LaunchMode.externalApplication);
      if (!ok) throw ApiException('cannot_open');
      setState(() => _pendingOrder = o.orderId);
      _startPolling(o.orderId);
    } on ApiException catch (e) {
      if (e.status == 401) await session.expire();
      if (mounted) setState(() => _error = _err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The app only reads status; the gateway webhook is what marks an order paid.
  void _startPolling(String id) {
    _poll?.cancel();
    _polls = 0;
    _poll = Timer.periodic(const Duration(seconds: 3), (t) async {
      if (++_polls > 100) {
        t.cancel(); // ~5 minutes
        if (mounted) setState(() => _pendingOrder = null);
        return;
      }
      try {
        final st = await session.api.orderStatus(id);
        if (st.status == 'paid') {
          t.cancel();
          session.setBalance(st.balance);
          if (mounted) {
            setState(() => _pendingOrder = null);
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(widget.settings.s.f('paid_ok', [st.balance]))));
          }
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings.s;
    return ListenableBuilder(
      listenable: session,
      builder: (_, _) => Scaffold(
        appBar: AppBar(title: Text(s['buy_credits'])),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.toll),
              title: Text(s.f('balance', [session.balance])),
              subtitle: Text(s['credit_hint']),
            ),
          ),
          if (_pendingOrder != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                title: Text(s['waiting_payment']),
              ),
            ),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 8),
          if (_products == null && _error == null) const Center(child: CircularProgressIndicator()),
          for (final p in _products ?? <Product>[])
            Card(
              child: ListTile(
                title: Text(p.credits == 1 ? s['single_parcel'] : s.f('pack', [p.credits])),
                subtitle: Text(s.f('per_parcel', [gel((p.amountTetri / p.credits).round())])),
                trailing: FilledButton(
                  onPressed: _busy ? null : () => _buy(p),
                  child: Text(gel(p.amountTetri)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
