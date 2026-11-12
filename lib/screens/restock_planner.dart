// Restock planner for Nilvai: suggests order or pre-pack quantities from recent sales.
// Self-contained: depends only on Flutter Material. Place in lib/screens/.
import 'dart:math' as math;
import 'package:flutter/material.dart';

class RestockItem {
  RestockItem(this.te, this.en, this.unit,
      {required this.avg7,
      required this.avg3,
      required this.onHand,
      this.festivalFactor = 1.0,
      this.coverDays = 3,
      this.prepack = false,
      this.packsPerBag = 1});
  final String te, en, unit;
  double avg7, avg3, onHand;
  final double festivalFactor;
  final int coverDays, packsPerBag;
  final bool prepack;

  double forecast() => 0.6 * avg3 + 0.4 * avg7;
  bool spike() => avg7 > 0 && avg3 >= 1.8 * avg7;

  int quantity(bool festival) {
    final f = festival ? festivalFactor : 1.0;
    final daily = forecast() * f;
    final safety = daily * ((f > 1 || spike()) ? 1.0 : 0.5);
    return math.max(0, (daily * coverDays + safety - onHand).ceil());
  }
}

class RestockPlannerScreen extends StatefulWidget {
  const RestockPlannerScreen({super.key});
  @override
  State<RestockPlannerScreen> createState() => _RestockPlannerScreenState();
}

class _RestockPlannerScreenState extends State<RestockPlannerScreen> {
  bool festival = true;

  final items = <RestockItem>[
    RestockItem('కొబ్బరికాయ', 'Coconut', 'pcs',
        avg7: 40, avg3: 55, onHand: 30, festivalFactor: 2, coverDays: 2),
    RestockItem('మెత్తని చీపురు', 'Soft broom', 'pcs',
        avg7: 5, avg3: 15, onHand: 5, coverDays: 4),
    RestockItem('బల్బు 9W', 'LED bulb 9W', 'pcs',
        avg7: 6, avg3: 7, onHand: 7, coverDays: 8),
    RestockItem('చక్కెర 1 కిలో', 'Sugar 1 kg pack', 'packs',
        avg7: 15, avg3: 22, onHand: 20, festivalFactor: 2, coverDays: 3,
        prepack: true, packsPerBag: 50),
    RestockItem('కందిపప్పు 1 కిలో', 'Toor dal 1 kg pack', 'packs',
        avg7: 8, avg3: 10, onHand: 12, festivalFactor: 1.5, coverDays: 4),
    RestockItem('బియ్యం 26 కిలో', 'Rice 26 kg bag', 'bags',
        avg7: 2.7, avg3: 2.7, onHand: 8, festivalFactor: 1.2, coverDays: 30),
  ];

  String fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  String reason(RestockItem i, int q) {
    if (i.prepack) return 'ముందే ప్యాక్ చేయండి · Pack in advance from bulk bag';
    if (q == 0) return 'స్టాక్ సరిపోతుంది · Enough stock';
    if (i.spike()) return 'డిమాండ్ పెరిగింది · Trend spike';
    if (festival && i.festivalFactor > 1) return 'పండుగ · Festival';
    return 'సాధారణ ఆర్డర్ · Normal reorder';
  }

  Future<void> edit(RestockItem i) async {
    final c7 = TextEditingController(text: fmt(i.avg7));
    final c3 = TextEditingController(text: fmt(i.avg3));
    final ch = TextEditingController(text: fmt(i.onHand));
    Widget field(String label, TextEditingController c) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${i.te} · ${i.en}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          field('7 రోజుల సగటు · Sales per day, last 7 days', c7),
          field('3 రోజుల సగటు · Sales per day, last 3 days', c3),
          field('ఉన్న స్టాక్ · Stock on hand', ch),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        i.avg7 = double.tryParse(c7.text) ?? i.avg7;
        i.avg3 = double.tryParse(c3.text) ?? i.avg3;
        i.onHand = double.tryParse(ch.text) ?? i.onHand;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('కొనుగోలు సూచన · Restock planner')),
      body: ListView(children: [
        SwitchListTile(
          title: const Text('పండుగ వారం · Festival week'),
          value: festival,
          onChanged: (v) => setState(() => festival = v),
        ),
        const Divider(height: 1),
        for (final i in items) ...[
          _row(i, s),
          const Divider(height: 1),
        ],
      ]),
    );
  }

  Widget _row(RestockItem i, ColorScheme s) {
    final q = i.quantity(festival);
    final red = !i.prepack && q > 0 && i.spike();
    return InkWell(
      onTap: () => edit(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.te, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              Text(i.en, style: TextStyle(fontSize: 13, color: s.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(reason(i, q),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: red ? s.error : s.primary)),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Column(children: [
              Text(fmt(i.onHand),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: s.onSurfaceVariant)),
              Text('ఉంది', style: TextStyle(fontSize: 11, color: s.onSurfaceVariant)),
              Text('in stock', style: TextStyle(fontSize: 11, color: s.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: Column(children: [
              Text('$q',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: red ? s.error : s.onSurface)),
              Text(i.unit, style: const TextStyle(fontSize: 12)),
              if (i.prepack)
                Text('${(q / i.packsPerBag).ceil()} bags',
                    style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}
