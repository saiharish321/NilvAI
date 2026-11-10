import 'package:flutter/material.dart';

import '../db.dart';
import '../logic.dart';
import '../state.dart';
import '../widgets.dart';

/// Purchases and stock counts.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<CountData> _counts = [];
  List<Map<String, Object?>> _purchases = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await Db.instance.counts();
    final p = await Db.instance.purchases();
    if (mounted) {
      setState(() {
        _counts = c.reversed.toList();
        _purchases = p.take(30).toList();
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final prices = {for (final p in app.packs) p.id!: PackPrice(p.cost, p.price)};
    final m = app.setting('blended_margin');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: () => _open(const PurchaseScreen()),
                  icon: const Icon(Icons.add),
                  label: const Bi('కొనుగోలు', 'Purchase'))),
          const SizedBox(width: 8),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: () => _open(const CountScreen()),
                  icon: const Icon(Icons.checklist),
                  label: const Bi('సరుకు లెక్క', 'Count'))),
        ]),
        const SectionTitle('సరుకు లెక్కలు', 'Stock counts'),
        if (_counts.isEmpty) const Text('None yet. Two counts are needed for inventory turns.'),
        for (final c in _counts)
          Card(
              child: ListTile(
            title: Text(c.date),
            subtitle: Text(() {
              final v = countValue(c, prices, m);
              return '${c.lines.length} lines · ${rs0(v.sp)} at selling price${app.owner ? ' · ${rs0(v.cost)} at cost' : ''}';
            }()),
          )),
        const SectionTitle('కొనుగోళ్లు', 'Purchases'),
        if (_purchases.isEmpty) const Text('None yet'),
        for (final p in _purchases)
          Card(
              child: ListTile(
            title: Text('${p['date']} · ${p['supplier']}'),
            subtitle: Text([
              rs(num0(p['value'])),
              if (num0(p['credit_days']) > 0) '${num0(p['credit_days']).toInt()}d credit',
              if (p['channel'] == 'bigbasket') '🛒 BigBasket rescue',
            ].join(' · ')),
          )),
      ]),
    );
  }
}

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});
  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  String _date = today();
  final _supplier = TextEditingController();
  double _credit = 0;
  bool _bigbasket = false;
  final List<Line> _lines = [];

  @override
  void dispose() {
    _supplier.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      toast(context, 'Add items first');
      return;
    }
    await Db.instance.savePurchase(_date, _supplier.text.trim(), _bigbasket ? 'bigbasket' : 'distributor', _credit, _lines);
    await app.refresh(); // invoice cost becomes the catalogue cost
    if (mounted) {
      toast(context, 'Saved ✓');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = {for (final p in app.packs) p.item!.supplier}.where((s) => s.isNotEmpty).toList();
    return Scaffold(
      appBar: AppBar(title: const Bi('కొనుగోలు బిల్లు', 'Purchase invoice')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          DateField(_date, (d) => setState(() => _date = d)),
          const SizedBox(width: 8),
          Expanded(child: NumField(label: 'Credit days', value: _credit, onChanged: (v) => _credit = v)),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _supplier,
          decoration: const InputDecoration(labelText: 'Supplier / సరఫరాదారు'),
          onChanged: (_) => setState(() {}),
        ),
        Wrap(spacing: 6, children: [
          for (final s in suppliers
              .where((s) => s.toLowerCase().contains(_supplier.text.toLowerCase()) && s != _supplier.text)
              .take(4))
            ActionChip(label: Text(s), onPressed: () => setState(() => _supplier.text = s)),
        ]),
        CheckboxListTile(
          value: _bigbasket,
          onChanged: (v) => setState(() => _bigbasket = v ?? false),
          title: const Bi('అత్యవసర ఆర్డర్', '🛒 BigBasket prepaid rescue order'),
          tileColor: surfaceTint,
        ),
        const SizedBox(height: 8),
        LineEditor(lines: _lines, mode: LineMode.purchase),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Bi('భద్రపరచు', 'Save')),
      ]),
    );
  }
}

class CountScreen extends StatefulWidget {
  const CountScreen({super.key});
  @override
  State<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends State<CountScreen> {
  String _date = today();
  double _other = 0;
  final List<Line> _lines = [];
  int _editor = 0;

  void _addAll() {
    final have = _lines.map((l) => l.packId).toSet();
    for (final p in app.packs) {
      if (!have.contains(p.id)) _lines.add(Line(p.id!, qty: 0, price: p.price, cost: p.cost));
    }
    setState(() => _editor++);
  }

  Future<void> _save() async {
    await Db.instance.saveCount(_date, _other, _lines);
    if (mounted) {
      toast(context, 'Saved ✓');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Bi('సరుకు లెక్క', 'Stock count')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          const Text('Count the items in the app. For everything else, enter one total at selling price.',
              style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 8),
          Row(children: [
            DateField(_date, (d) => setState(() => _date = d)),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _addAll, child: const Text('Add every item')),
          ]),
          const SizedBox(height: 8),
          LineEditor(key: ValueKey(_editor), lines: _lines, mode: LineMode.count),
          NumField(label: 'Value of other items (selling price) / మిగతా సరుకు విలువ', value: _other, onChanged: (v) => _other = v),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Bi('భద్రపరచు', 'Save')),
        ]),
      );
}
