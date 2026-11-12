import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../db.dart';
import '../files.dart';
import '../logic.dart';
import '../state.dart';
import '../widgets.dart';
import 'restock_planner.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget tile(IconData i, String te, String en, Widget page) => Card(
          child: ListTile(
            leading: Icon(i, color: brand),
            title: Bi(te, en),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Bi('మరిన్ని', 'More')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        tile(Icons.menu_book, 'సరుకుల జాబితా', 'Catalogue', const CatalogueScreen()),
        tile(Icons.inventory_2, 'కొనుగోలు సూచన', 'Restock planner', const RestockPlannerScreen()),
        tile(Icons.science,'ట్రయల్', 'Product trials', const TrialsScreen()),
        tile(Icons.balance, 'నిర్ణయ నియమం', 'Decision rule', const DecisionScreen()),
        tile(Icons.ios_share, 'ఎగుమతి / బ్యాకప్', 'Export & backup', const DataScreen()),
        tile(Icons.settings, 'సెట్టింగ్స్', 'Settings', const SettingsScreen()),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Nilvai · open source (MIT) · data stays on this phone', style: TextStyle(color: Colors.black45)),
        ),
      ]),
    );
  }
}

// ---------- Catalogue ----------

class CatalogueScreen extends StatefulWidget {
  const CatalogueScreen({super.key});
  @override
  State<CatalogueScreen> createState() => _CatalogueScreenState();
}

class _CatalogueScreenState extends State<CatalogueScreen> {
  List<Item> _items = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final i = await Db.instance.items();
    if (mounted) setState(() => _items = i);
  }

  Future<void> _edit(Item? it) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ItemScreen(item: it)));
    await app.refresh();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Catalogue (${_items.length})')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(null), icon: const Icon(Icons.add), label: const Text('New item')),
        body: ListView(children: [
          for (final it in _items)
            ListTile(
              title: Text('${it.nameTe}  ${it.nameEn}'),
              subtitle: Text('${it.brand} · ${it.category}${it.active ? '' : ' · hidden'}'),
              onTap: () => _edit(it),
            ),
          const SizedBox(height: 80),
        ]),
      );
}

class ItemScreen extends StatefulWidget {
  final Item? item;
  const ItemScreen({super.key, this.item});
  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  late final Item _it = widget.item ?? Item(key: '', nameEn: '');
  List<Pack> _packs = [];
  late final _te = TextEditingController(text: _it.nameTe);
  late final _en = TextEditingController(text: _it.nameEn);
  late final _brand = TextEditingController(text: _it.brand);
  late final _cat = TextEditingController(text: _it.category);

  @override
  void initState() {
    super.initState();
    if (_it.id != null) {
      Db.instance.packsOf(_it.id!).then((p) {
        if (mounted) setState(() => _packs = p);
      });
    } else {
      _packs = [Pack(itemId: 0, size: '1 kg')];
    }
  }

  @override
  void dispose() {
    for (final c in [_te, _en, _brand, _cat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_te.text.trim().isEmpty && _en.text.trim().isEmpty) {
      toast(context, 'Name needed');
      return;
    }
    _it
      ..nameTe = _te.text.trim()
      ..nameEn = _en.text.trim()
      ..brand = _brand.text.trim()
      ..category = _cat.text.trim().isEmpty ? 'Other' : _cat.text.trim();
    if (_it.key.isEmpty) _it.key = '${_it.category}|${_it.nameEn}|${_it.brand}|${DateTime.now().millisecondsSinceEpoch}';
    await Db.instance.saveItem(_it, _packs);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_it.id == null ? 'New item' : 'Edit item')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          TextField(controller: _te, decoration: const InputDecoration(labelText: 'తెలుగు పేరు')),
          const SizedBox(height: 8),
          TextField(controller: _en, decoration: const InputDecoration(labelText: 'English name')),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _brand, decoration: const InputDecoration(labelText: 'Brand'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _cat, decoration: const InputDecoration(labelText: 'Category'))),
          ]),
          const SectionTitle('ప్యాక్ సైజులు', 'Pack sizes (cost, price, margin)'),
          for (final p in _packs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                    flex: 3,
                    child: TextFormField(
                        initialValue: p.size,
                        decoration: const InputDecoration(labelText: 'Size', isDense: true),
                        onChanged: (v) => p.size = v)),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: NumField(label: 'Cost', value: p.cost, onChanged: (v) => setState(() => p.cost = v))),
                const SizedBox(width: 6),
                Expanded(
                    flex: 2,
                    child: NumField(label: 'Price', value: p.price, onChanged: (v) => setState(() => p.price = v))),
                SizedBox(width: 52, child: Text(pct(p.margin), textAlign: TextAlign.end)),
              ]),
            ),
          TextButton.icon(
              onPressed: () => setState(() => _packs.add(Pack(itemId: _it.id ?? 0, size: ''))),
              icon: const Icon(Icons.add),
              label: const Text('Add pack size')),
          SwitchListTile(
              value: _it.active, onChanged: (v) => setState(() => _it.active = v), title: const Text('Show in search')),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('Save')),
        ]),
      );
}

// ---------- Trials ----------

class TrialsScreen extends StatefulWidget {
  const TrialsScreen({super.key});
  @override
  State<TrialsScreen> createState() => _TrialsScreenState();
}

class _TrialsScreenState extends State<TrialsScreen> {
  List<Map<String, Object?>> _trials = [];
  List<Item> _items = [];
  final Set<int> _picked = {};
  final _name = TextEditingController();
  String _start = today();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await Db.instance.trials();
    final i = await Db.instance.items();
    if (mounted) {
      setState(() {
        _trials = t;
        _items = i;
      });
    }
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty || _picked.isEmpty) {
      toast(context, 'Name and at least one item');
      return;
    }
    await Db.instance.addTrial(_name.text.trim(), _start, _picked.toList());
    _name.clear();
    _picked.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Bi('ట్రయల్', 'Product trials')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          for (final t in _trials)
            Card(
              child: ListTile(
                title: Text('${t['name']}'),
                subtitle: Text('from ${t['start_date']}'),
                trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await Db.instance.deleteTrial(t['id'] as int);
                      _load();
                    }),
              ),
            ),
          const SectionTitle('కొత్త ట్రయల్', 'New trial'),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          Row(children: [const Text('Start '), DateField(_start, (d) => setState(() => _start = d))]),
          for (final it in _items)
            CheckboxListTile(
              dense: true,
              value: _picked.contains(it.id),
              title: Text('${it.nameTe}  ${it.nameEn}  ${it.brand}'),
              onChanged: (v) => setState(() => v == true ? _picked.add(it.id!) : _picked.remove(it.id)),
            ),
          FilledButton.icon(onPressed: _add, icon: const Icon(Icons.save), label: const Text('Save trial')),
        ]),
      );
}

// ---------- Decision rule ----------

class DecisionScreen extends StatelessWidget {
  const DecisionScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final cash = app.setting('turns_cash'), rent = app.setting('turns_with_rent');
    Widget rule(Color c, String band, String te, String en, String detail) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(band, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c)),
              Bi(te, en, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(detail),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Bi('నిర్ణయ నియమం', 'Decision rule')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        const Text('Measure turns between two stock counts, at least a month apart. Then:'),
        rule(const Color(0xFF2F7D32), '≥ ${rent.toStringAsFixed(2)} turns', 'కొనసాగించండి', 'Continue',
            'The shop pays your wage and a market rent on the building.'),
        rule(const Color(0xFFC98A00), '${cash.toStringAsFixed(2)} – ${rent.toStringAsFixed(2)}', 'మార్పు చేయండి', 'Reposition',
            'Pays your wage, not the rent. Move capital from slow, low-margin lines to categories that earn more than the capital they hold, and grow hotel and temple supply.'),
        rule(const Color(0xFFC62828), '< ${cash.toStringAsFixed(2)}', 'గట్టిగా మార్చండి', 'Reposition firmly, test rice focus',
            'Does not pay your wage. Compare the narrow rice-retailer option on the same turns test.'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Text('Capital rule: a category should not hold a larger share of stock than its share of margin '
                '(see "Capital vs earnings").\n\nCredit rule: supply hotels and the temple on credit no longer '
                'than your own supplier credit.'),
          ),
        ),
        const Text('RELEVANT COST AND DECISION RULE (CCS, SM). THRESHOLDS EDITABLE IN SETTINGS.',
            style: TextStyle(fontSize: 11, color: Colors.black45)),
      ]),
    );
  }
}

// ---------- Export, backup, import ----------

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});
  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() job) async {
    setState(() => _busy = true);
    try {
      final msg = await job();
      if (mounted && msg != null) toast(context, msg);
    } catch (e) {
      if (mounted) toast(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _importCatalogue(String csv) async {
    final c = catalogueFromRows(parseCsv(csv));
    final r = await Db.instance.importCatalogue(c.items, c.packs);
    await app.refresh();
    return '${r.items} items, ${r.packs} packs imported';
  }

  Future<String?> _exportCsv() async {
    final db = Db.instance;
    final pk = app.packById;
    Map<String, Object?> nm(Object? id) {
      final p = pk[id];
      return {'item': p?.item?.nameEn, 'item_te': p?.item?.nameTe, 'brand': p?.item?.brand, 'category': p?.item?.category, 'pack': p?.size};
    }

    final d = today();
    final sales = await db.saleLines();
    final purchases = await db.purchaseLines();
    final counts = await db.counts();
    final receipts = await db.allReceipts();
    final corrections = <Map<String, Object?>>[];
    for (final r in receipts.where((r) => r.corrections.isNotEmpty)) {
      final list = jsonDecode(r.corrections) as List;
      for (var i = 0; i < list.length; i++) {
        final c = list[i] as Map;
        final raw = c['raw'] as Map;
        final top = nm(c['top']), fin = nm(c['final']);
        corrections.add({
          'receipt_id': r.id, 'line': i + 1, 'seconds': r.seconds, 'model': r.model,
          'raw_text': raw['item_text'], 'raw_en': raw['item_en'], 'raw_qty': raw['qty_value'], 'raw_unit': raw['qty_unit'],
          'raw_amount': raw['amount'], 'top_match': top['item'] == null ? '' : '${top['item']} ${top['pack']}',
          'final': c['final'] == null ? 'DROPPED' : '${fin['item']} ${fin['pack']}', 'top_correct': c['top'] == c['final'] ? 1 : 0,
        });
      }
    }
    final purchaseRows = await db.purchases();
    final files = <String, String>{
      'nilvai_${d}_items.csv': toCsv([
        for (final p in app.packs)
          {'pack_id': p.id, ...nm(p.id), 'cost': p.cost, 'price': p.price, 'margin_pct': p.margin.toStringAsFixed(4)}
      ]),
      'nilvai_${d}_sales_lines.csv': toCsv([for (final l in sales) {...l, ...nm(l['pack_id'])}]),
      'nilvai_${d}_purchase_lines.csv': toCsv([for (final l in purchases) {...l, ...nm(l['pack_id'])}]),
      'nilvai_${d}_counts.csv': toCsv([
        for (final c in counts) ...[
          for (final l in c.lines) {'date': c.date, ...nm(l.packId), 'qty': l.qty},
          {'date': c.date, 'item': 'OTHER (value at selling price)', 'qty': c.otherValueSp},
        ]
      ]),
      'nilvai_${d}_ocr_corrections.csv': toCsv(corrections),
      'nilvai_${d}_summary.csv': toCsv([
        {
          'exported': d,
          'sale_days': sales.map((s) => s['date']).toSet().length,
          'sales': sales.map((s) => s['sale_id']).toSet().length,
          'sales_by_ocr': sales.where((s) => s['source'] == 'ocr').map((s) => s['sale_id']).toSet().length,
          'purchases': purchaseRows.length,
          'bigbasket_orders': purchaseRows.where((p) => p['channel'] == 'bigbasket').length,
          'counts': counts.length,
          'receipts_confirmed': receipts.where((r) => r.status == 'confirmed').length,
        }
      ]),
    };
    await shareFiles(files, text: 'Nilvai export $d');
    return null;
  }

  Future<String?> _backup() async {
    await shareFiles({'nilvai-backup-${today()}.json': await Db.instance.backupJson()}, text: 'Nilvai backup');
    await app.setSetting('last_backup', today());
    return null;
  }

  Future<String?> _restore() async {
    final f = await pickTextFile();
    if (f == null || !mounted) return null;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(content: const Text('Replace all data on this phone with the backup?'), actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Replace')),
            ]));
    if (ok != true) return null;
    await Db.instance.restoreJson(f.text);
    await app.refresh();
    return 'Restored';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Bi('ఎగుమతి / బ్యాకప్', 'Export & backup')),
        body: AbsorbPointer(
          absorbing: _busy,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            if (_busy) const LinearProgressIndicator(),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Catalogue: ${app.packs.length} packs', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import catalogue CSV'),
                    onPressed: () => _run(() async {
                      final f = await pickTextFile();
                      return f == null ? null : _importCatalogue(f.text);
                    }),
                  ),
                  TextButton(
                    onPressed: () => _run(() async => _importCatalogue(await rootBundle.loadString('assets/sample_catalogue.csv'))),
                    child: const Text('Load sample catalogue'),
                  ),
                  const Text('Columns: category, name_en, name_te, brand, pack, cost, price. Existing items are updated, not duplicated.',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                ]),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton.icon(icon: const Icon(Icons.ios_share), label: const Text('Export CSVs for the report'), onPressed: () => _run(_exportCsv)),
                  const Text('Items, sales, purchases, counts, OCR corrections and a summary. Share by WhatsApp or email.',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                ]),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton.icon(icon: const Icon(Icons.backup), label: const Text('Backup now'), onPressed: () => _run(_backup)),
                  OutlinedButton.icon(icon: const Icon(Icons.restore), label: const Text('Restore from backup'), onPressed: () => _run(_restore)),
                  Text('Last backup: ${app.settings['last_backup']?.isEmpty ?? true ? 'never' : app.settings['last_backup']}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),
      );
}

// ---------- Settings ----------

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget field(String key, String label, {bool number = false, bool secret = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            initialValue: app.settings[key],
            obscureText: secret,
            keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(labelText: label),
            onChanged: (v) => app.setSetting(key, v.trim()),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        field('shop_name', 'App title'),
        field('pin', 'Owner PIN (hides cost and margin from staff)', secret: true, number: true),
        const SectionTitle('OCR సర్వర్', 'OCR server'),
        field('ocr_url', 'Server address, e.g. http://192.168.1.23:8765'),
        field('ocr_token', 'Server token (same as OCR_TOKEN on the laptop)', secret: true),
        ListenableBuilder(
          listenable: app,
          builder: (context, _) => SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'full', label: Text('Items + numbers')),
              ButtonSegment(value: 'numbers', label: Text('Numbers only')),
            ],
            selected: {app.settings['ocr_mode'] ?? 'full'},
            onSelectionChanged: (s) => app.setSetting('ocr_mode', s.first),
          ),
        ),
        const SectionTitle('పరిమితులు', 'Thresholds (from the report)'),
        field('turns_cash', 'Turns to cover cash costs and owner wage', number: true),
        field('turns_with_rent', 'Turns to also cover imputed rent', number: true),
        field('blended_margin', 'Blended margin (0.11 = 11%)', number: true),
        field('owner_wage_month', 'Owner wage per month', number: true),
        field('staff_cost', 'Staff cost per year', number: true),
        field('other_overheads', 'Other overheads per year (excl. rent, owner wage)', number: true),
      ]),
    );
  }
}
