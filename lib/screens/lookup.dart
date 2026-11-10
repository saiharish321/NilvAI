import 'package:flutter/material.dart';

import '../logic.dart';
import '../state.dart';
import '../widgets.dart';

/// Home: type a few letters in Telugu or English and see every pack size and its price.
class LookupScreen extends StatefulWidget {
  const LookupScreen({super.key});
  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          // Distinct items, in order of best match
          final items = <int>{for (final p in app.search(_q, limit: 40)) p.itemId}.take(15).toList();
          return ListView(padding: const EdgeInsets.all(12), children: [
            TextField(
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                  hintText: 'వెతకండి / Search (kandi, toor, కంది…)', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            if (app.packs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Bi('సరుకుల జాబితా లేదు', 'No catalogue yet: ☰ → Export & backup → Import')),
              ),
            for (final id in items) _itemCard(id),
          ]);
        },
      );

  Widget _itemCard(int itemId) {
    final packs = app.packs.where((p) => p.itemId == itemId).toList()..sort((a, b) => a.price.compareTo(b.price));
    final it = packs.first.item!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(children: [
            if (it.nameTe.isNotEmpty)
              TextSpan(text: '${it.nameTe}  ', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            TextSpan(text: it.nameEn, style: const TextStyle(fontSize: 17)),
            TextSpan(text: '  ${it.brand}', style: const TextStyle(color: Colors.black54)),
          ])),
          const Divider(),
          for (final p in packs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(p.size, style: const TextStyle(color: Colors.black54, fontSize: 16))),
                if (app.owner) ...[
                  Text(rs(p.cost), style: const TextStyle(color: Colors.black45)),
                  const SizedBox(width: 10),
                  Text(pct(p.margin),
                      style: TextStyle(color: p.margin < 0.08 ? Colors.red.shade700 : Colors.green.shade700)),
                  const SizedBox(width: 12),
                ],
                Text(rs(p.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ]),
            ),
        ]),
      ),
    );
  }
}
