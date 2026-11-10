import 'package:flutter/material.dart';

import '../db.dart';
import '../logic.dart';
import '../state.dart';
import '../widgets.dart';

const _ok = Color(0xFF2F7D32), _mid = Color(0xFFC98A00), _warn = Color(0xFFC62828), _cap = Color(0xFF8A7F6B);

/// Weekly report: is the shop paying, what earns, what ties up capital.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Widget>? _cards;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final db = Db.instance;
    final counts = await db.counts();
    final saleLines = await db.saleLines();
    final purchaseLines = await db.purchaseLines();
    final purchases = await db.purchases();
    final trials = await db.trials();

    final prices = {for (final p in app.packs) p.id!: PackPrice(p.cost, p.price)};
    final m = app.setting('blended_margin');
    final tCash = app.setting('turns_cash'), tRent = app.setting('turns_with_rent');
    final cards = <Widget>[];

    // Purchases grouped for the turns calculation
    final byPurchase = <int, PurchaseData>{};
    for (final l in purchaseLines) {
      final id = l['purchase_id'] as int;
      final pd = byPurchase[id] ?? PurchaseData(l['date'] as String, []);
      byPurchase[id] = PurchaseData(pd.date, [...pd.lines, (qty: num0(l['qty']), cost: num0(l['cost']))]);
    }

    final saleDays = saleLines.map((l) => l['date']).toSet().length;

    // ---- Break-even gauge
    final tc = counts.length >= 2
        ? turnsFromCounts(counts[counts.length - 2], counts.last, byPurchase.values.toList(), prices, m)
        : null;
    final latest = counts.isEmpty ? null : countValue(counts.last, prices, m);
    double? ts;
    if (latest != null && saleDays > 0) {
      final first = saleLines.first['date'] as String;
      final cogs = saleLines.fold(0.0, (s, l) => s + num0(l['qty']) * num0(l['cost']));
      ts = turnsFromSales(cogs, latest.cost, daysBetween(first, today()) + 1);
    }
    final be = <Widget>[];
    String? beBasis;
    if (tc != null) {
      be.add(_Gauge(turns: tc.turns, cash: tCash, rent: tRent));
      if (app.owner) {
        final earn = monthlyEarning(tc.turns, tc.avgStock, m, app.setting('staff_cost'), app.setting('other_overheads'));
        be.add(Text('Monthly earning ≈ ${rs0(earn)} vs wage ${rs0(app.setting('owner_wage_month'))}'));
      }
      beBasis = basisText(tc.days, 'days between counts (${counts[counts.length - 2].date} → ${counts.last.date})');
    } else {
      be.add(Text('Needs two stock counts and the purchases between them. ${counts.length}/2 counts done.'));
    }
    if (ts != null) {
      be.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('Cross-check from logged sales: ${ts.toStringAsFixed(2)} turns/yr (${basisText(saleDays)})',
            style: const TextStyle(color: Colors.black54)),
      ));
    }
    cards.add(DashCard(te: 'షాపు లాభంలో ఉందా?', en: 'Is the shop paying?', concept: 'Break-even via CVP (CCS)', basis: beBasis, children: be));

    // ---- Rescue orders
    final weekAgo = isoDate(DateTime.now().subtract(const Duration(days: 7)));
    final bb = purchases.where((p) => p['channel'] == 'bigbasket').toList();
    final bbWeek = bb.where((p) => (p['date'] as String).compareTo(weekAgo) >= 0).toList();
    cards.add(DashCard(te: 'అత్యవసర ఆర్డర్లు', en: 'BigBasket rescue orders', concept: 'Service level / stockouts (OM)', children: [
      Text('${bbWeek.length} this week · ${rs0(bbWeek.fold(0.0, (s, p) => s + num0(p['value'])))}',
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      Text('${bb.length} in total', style: const TextStyle(color: Colors.black54)),
    ]));

    if (saleDays > 0) {
      // ---- ABC
      final contrib = <int, double>{};
      for (final l in saleLines) {
        final p = app.packById[l['pack_id']];
        if (p == null) continue;
        contrib[p.itemId] = (contrib[p.itemId] ?? 0) + num0(l['qty']) * (num0(l['price']) - num0(l['cost']));
      }
      final tags = abc(contrib);
      final total = contrib.values.fold(0.0, (a, b) => a + b);
      final items = {for (final p in app.packs) p.itemId: p.item!};
      final top = contrib.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      cards.add(DashCard(
        te: 'ఎక్కువ లాభం తెచ్చే సరుకులు',
        en: 'Items that earn most',
        concept: 'ABC analysis (OM)',
        basis: basisText(saleDays),
        children: [
          for (final e in top.take(10))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                _AbcTag(tags[e.key] ?? 'C'),
                const SizedBox(width: 8),
                Expanded(child: Text('${items[e.key]?.nameTe ?? ''} ${items[e.key]?.nameEn ?? ''}')),
                Text(total > 0 ? pct(e.value / total) : '–'),
              ]),
            ),
          Text('A = ${tags.values.where((t) => t == 'A').length} items earn 80% of margin',
              style: const TextStyle(color: Colors.black54)),
        ],
      ));

      // ---- Capital vs earnings
      if (counts.isNotEmpty) {
        final cap = <String, double>{}, earn = <String, double>{};
        for (final l in counts.last.lines) {
          final p = app.packById[l.packId];
          if (p != null) cap[p.item!.category] = (cap[p.item!.category] ?? 0) + l.qty * p.cost;
        }
        contrib.forEach((id, v) {
          final c = items[id]?.category ?? 'Other';
          earn[c] = (earn[c] ?? 0) + v;
        });
        final capT = cap.values.fold(0.0, (a, b) => a + b), earnT = total;
        final cats = {...cap.keys, ...earn.keys}.toList()..sort((a, b) => (cap[b] ?? 0).compareTo(cap[a] ?? 0));
        cards.add(DashCard(
          te: 'పెట్టుబడి vs లాభం',
          en: 'Capital vs earnings (counted items)',
          concept: 'Category profitability (ACCV, CCS)',
          basis: basisText(saleDays),
          children: [
            for (final c in cats)
              _Bars(label: c, capital: capT > 0 ? (cap[c] ?? 0) / capT : 0, earning: earnT > 0 ? (earn[c] ?? 0) / earnT : 0),
            const Text('■ stock   ■ margin', style: TextStyle(fontSize: 12)),
          ],
        ));

        // ---- Days of stock left
        final c = counts.last;
        final sinceCount = daysBetween(c.date, today());
        final span = sinceCount < 1 ? 1 : sinceCount;
        final rows = <(Pack, double)>[];
        for (final l in c.lines) {
          final p = app.packById[l.packId];
          if (p == null) continue;
          final sold = saleLines
              .where((x) => (x['date'] as String).compareTo(c.date) > 0 && x['pack_id'] == l.packId)
              .fold(0.0, (s, x) => s + num0(x['qty']));
          final bought = purchaseLines
              .where((x) => (x['date'] as String).compareTo(c.date) > 0 && x['pack_id'] == l.packId)
              .fold(0.0, (s, x) => s + num0(x['qty']));
          final rate = sold / span;
          if (rate > 0) rows.add((p, (l.qty + bought - sold) / rate));
        }
        rows.sort((a, b) => a.$2.compareTo(b.$2));
        if (rows.isNotEmpty) {
          cards.add(DashCard(
            te: 'ఎన్ని రోజుల సరుకు',
            en: 'Days of stock left',
            concept: 'Reorder logic, simplified EOQ (OM)',
            basis: basisText(span, 'days since last count'),
            children: [
              for (final r in rows.take(8))
                Row(children: [
                  Expanded(child: PackName(r.$1)),
                  Text('${r.$2 < 0 ? 0 : r.$2.round()} d', style: TextStyle(color: r.$2 < 3 ? _warn : null)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(
                      RegExp('fresh|perish', caseSensitive: false).hasMatch(r.$1.item!.category)
                          ? 'order small, often'
                          : r.$1.item!.creditDays > 0
                              ? 'buy within ${r.$1.item!.creditDays.toInt()}d credit'
                              : '',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
                ]),
            ],
          ));
        }
      }
    }

    // ---- Trials
    for (final t in trials) {
      final ids = (t['item_ids'] as String? ?? '').split(',').where((s) => s.isNotEmpty).map(int.parse).toSet();
      final start = t['start_date'] as String;
      final weeks = <int, ({double s, double m})>{};
      for (final l in saleLines) {
        final date = l['date'] as String;
        final p = app.packById[l['pack_id']];
        if (p == null || !ids.contains(p.itemId) || date.compareTo(start) < 0) continue;
        final w = daysBetween(start, date) ~/ 7 + 1;
        final o = weeks[w] ?? (s: 0.0, m: 0.0);
        final q = num0(l['qty']);
        weeks[w] = (s: o.s + q * num0(l['price']), m: o.m + q * (num0(l['price']) - num0(l['cost'])));
      }
      final ws = weeks.keys.toList()..sort();
      cards.add(DashCard(
        te: 'కొత్త సరుకు ట్రయల్',
        en: 'Trial: ${t['name']}',
        concept: 'Before-and-after measurement',
        basis: 'since $start',
        children: [
          if (ws.isEmpty) const Text('No sales yet'),
          for (final w in ws)
            Text('Week $w: ${rs0(weeks[w]!.s)}${app.owner ? '  ·  margin ${rs0(weeks[w]!.m)}' : ''}'),
        ],
      ));
    }

    if (mounted) setState(() => _cards = cards);
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _build,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Row(children: [
            Expanded(child: Bi('వారపు లెక్క', 'Weekly report', style: Theme.of(context).textTheme.titleLarge)),
            IconButton(onPressed: _build, icon: const Icon(Icons.refresh)),
          ]),
          if (_cards == null) const Center(child: CircularProgressIndicator()) else ..._cards!,
          const SizedBox(height: 8),
          const Text('Pull down to refresh after entering data.', style: TextStyle(color: Colors.black45)),
        ]),
      );
}

class _Gauge extends StatelessWidget {
  final double turns, cash, rent;
  const _Gauge({required this.turns, required this.cash, required this.rent});
  @override
  Widget build(BuildContext context) {
    const max = 14.0;
    final color = turns >= rent ? _ok : (turns >= cash ? _mid : _warn);
    double f(double v) => (v / max).clamp(0.0, 1.0).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 24,
          child: Stack(children: [
            Container(decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12))),
            Container(
                width: w * f(turns),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12))),
            Positioned(left: w * f(cash), top: 0, bottom: 0, child: Container(width: 2, color: Colors.black)),
            Positioned(left: w * f(rent), top: 0, bottom: 0, child: Container(width: 2, color: Colors.black)),
          ]),
        );
      }),
      Text('marks: ${cash.toStringAsFixed(2)} (wage)  ·  ${rent.toStringAsFixed(2)} (wage + rent)',
          style: const TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 6),
      Text('${turns.toStringAsFixed(2)} turns/yr', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
      turns >= rent
          ? const Bi('అద్దె, జీతం రెండూ వస్తున్నాయి', 'Covers your wage and the rent')
          : turns >= cash
              ? const Bi('జీతం వస్తుంది, అద్దె రావడం లేదు', 'Covers your wage, not the rent')
              : const Bi('మీ జీతం కూడా రావడం లేదు', 'Does not yet cover your wage'),
    ]);
  }
}

class _AbcTag extends StatelessWidget {
  final String tag;
  const _AbcTag(this.tag);
  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
            color: tag == 'A' ? _ok : (tag == 'B' ? _mid : _cap), borderRadius: BorderRadius.circular(6)),
        child: Text(tag, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      );
}

class _Bars extends StatelessWidget {
  final String label;
  final double capital, earning;
  const _Bars({required this.label, required this.capital, required this.earning});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          _bar(capital, _cap),
          _bar(earning, _ok),
        ]),
      );
  Widget _bar(double v, Color c) => Row(children: [
        Expanded(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v.clamp(0.02, 1.0).toDouble(),
            child: Container(height: 14, color: c),
          ),
        ),
        SizedBox(width: 44, child: Text(' ${pct(v, decimals: 0)}', style: const TextStyle(fontSize: 12))),
      ]);
}
