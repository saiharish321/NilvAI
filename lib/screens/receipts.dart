import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../db.dart';
import '../files.dart';
import '../logic.dart';
import '../ocr.dart';
import '../state.dart';
import '../widgets.dart';

const _badge = {
  'queued': '⏳ queued',
  'sending': '📡 reading…',
  'done': '✅ ready to check',
  'error': '⚠️ error',
  'confirmed': '✔ saved',
};

/// Photograph handwritten bills, send them to the laptop, then check each line.
class ReceiptsScreen extends StatefulWidget {
  const ReceiptsScreen({super.key});
  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  List<Receipt> _rs = [];
  bool? _online;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Db.instance.receipts();
    if (mounted) setState(() => _rs = r);
    final on = await serverOnline();
    if (mounted) setState(() => _online = on);
  }

  Future<void> _add(bool camera) async {
    final n = await addReceiptPhotos(camera: camera);
    if (mounted && n > 0) toast(context, '$n added');
    _load();
  }

  Future<void> _readAll() async {
    setState(() => _busy = true);
    for (final r in _rs.where((r) => r.status == 'queued' || r.status == 'error').toList()) {
      await readReceipt(r);
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _busy = false);
    _load();
  }

  Future<void> _import() async {
    final f = await pickTextFile();
    if (f == null) return;
    try {
      final n = await importResults(f.text);
      if (mounted) toast(context, '$n receipts imported');
    } catch (e) {
      if (mounted) toast(context, 'Not a results file');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _rs.where((r) => r.status == 'queued' || r.status == 'error').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Bi('రసీదు ఫోటోలు', 'Receipt photos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(onPressed: () => _add(true), icon: const Icon(Icons.photo_camera), label: const Text('Camera')),
          OutlinedButton.icon(onPressed: () => _add(false), icon: const Icon(Icons.photo_library), label: const Text('Gallery')),
          OutlinedButton.icon(
              onPressed: _busy || pending == 0 ? null : _readAll,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text('Read all ($pending)')),
          OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.file_open), label: const Text('Import results')),
        ]),
        const SizedBox(height: 6),
        Text(
          'OCR server: ${app.settings['ocr_url']} · ${app.settings['ocr_mode']} · '
          '${_online == null ? '…' : _online! ? '🟢 online' : '🔴 offline (photos stay queued)'}',
          style: const TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (_rs.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Bi('ఇంకా ఫోటోలు లేవు', 'No receipts yet'))),
        for (final r in _rs)
          Card(
            child: ListTile(
              leading: r.imagePath.isNotEmpty && File(r.imagePath).existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(File(r.imagePath), width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 120))
                  : const Icon(Icons.description, size: 40),
              title: Text('#${r.id}  ${r.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                _badge[r.status] ?? r.status,
                if (r.result != null) '${r.result!.lines.length} lines',
                if (r.seconds > 0) '${r.seconds.toStringAsFixed(1)}s',
                if (r.error.isNotEmpty) r.error,
              ].join(' · ')),
              onTap: r.result == null
                  ? null
                  : () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => ConfirmScreen(receiptId: r.id!)));
                      _load();
                    },
            ),
          ),
      ]),
    );
  }
}

class _OcrDraft {
  final OcrLine raw;
  final List<({Pack pack, MatchScore m})> cands;
  int? packId;
  double qty, price;
  bool keep = true;
  _OcrDraft(this.raw, this.cands, this.packId, this.qty, this.price);
}

/// Each line the model read, with the app's best catalogue match. Nothing is saved until confirmed.
class ConfirmScreen extends StatefulWidget {
  final int receiptId;
  const ConfirmScreen({super.key, required this.receiptId});
  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  Receipt? _r;
  String _date = today();
  List<_OcrDraft> _lines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Db.instance.receipt(widget.receiptId);
    if (r == null || r.result == null) return;
    final lines = r.result!.lines.map((l) {
      final cands = app.rankMatches(l);
      final best = cands.isEmpty ? null : cands.first;
      if (best == null || best.m.score <= 0.35) {
        return _OcrDraft(l, cands, null, l.qtyValue > 0 ? l.qtyValue : 1.0, 0.0);
      }
      final qty = best.m.qty;
      final price = l.amount > 0 && qty > 0 ? double.parse((l.amount / qty).toStringAsFixed(2)) : best.pack.price;
      return _OcrDraft(l, cands, best.pack.id, qty, price);
    }).toList();
    if (mounted) {
      setState(() {
        _r = r;
        _lines = lines;
        if (r.saleDate.isNotEmpty) _date = r.saleDate;
      });
    }
  }

  double get _sum => _lines.where((l) => l.keep).fold(0.0, (s, l) => s + l.qty * l.price);

  void _choose(_OcrDraft d, Pack p) {
    setState(() {
      d.packId = p.id;
      final c = d.cands.where((c) => c.pack.id == p.id);
      if (c.isNotEmpty) {
        d.qty = c.first.m.qty;
        d.price = d.raw.amount > 0 && d.qty > 0 ? double.parse((d.raw.amount / d.qty).toStringAsFixed(2)) : p.price;
      } else {
        d.price = p.price;
      }
    });
  }

  Future<void> _save() async {
    final keep = _lines.where((l) => l.keep).toList();
    if (keep.any((l) => l.packId == null)) {
      toast(context, 'Choose an item for every kept line, or untick it');
      return;
    }
    final r = _r!;
    final saleId = await Db.instance.saveSale(
        _date, 'ocr', [for (final l in keep) Line(l.packId!, qty: l.qty, price: l.price, cost: app.packById[l.packId]?.cost ?? 0)],
        receiptId: r.id);
    // What the owner corrected, for the OCR evaluation table
    r.corrections = jsonEncode([
      for (final l in _lines)
        {'raw': l.raw.toJson(), 'top': l.cands.isEmpty ? null : l.cands.first.pack.id, 'final': l.keep ? l.packId : null}
    ]);
    r.status = 'confirmed';
    r.saleId = saleId;
    r.saleDate = _date;
    await Db.instance.saveReceipt(r);
    if (mounted) {
      toast(context, 'Saved ✓');
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(content: const Text('Delete this receipt?'), actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
            ]));
    if (ok != true) return;
    final r = _r!;
    if (r.imagePath.isNotEmpty) {
      final f = File(r.imagePath);
      if (await f.exists()) await f.delete();
    }
    await Db.instance.deleteReceipt(r.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppBar(title: Text('Check receipt #${widget.receiptId}'), actions: [
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: r == null ? null : _delete),
      ]),
      body: r == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(12), children: [
              if (r.imagePath.isNotEmpty && File(r.imagePath).existsSync())
                ExpansionTile(
                  title: const Bi('ఫోటో', 'Photo'),
                  children: [InteractiveViewer(maxScale: 5, child: Image.file(File(r.imagePath)))],
                ),
              Row(children: [const Bi('తేదీ', 'Date'), const SizedBox(width: 12), DateField(_date, (d) => setState(() => _date = d))]),
              for (final d in _lines) _lineCard(d),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'Total '),
                    TextSpan(text: rs(_sum), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    if (r.result!.total != null) ...[
                      TextSpan(text: '   receipt says ${rs(r.result!.total)} '),
                      TextSpan(text: (_sum - r.result!.total!).abs() < 1 ? '✅' : '⚠️'),
                    ],
                  ]),
                  textAlign: TextAlign.end,
                ),
              ),
              if (r.status == 'confirmed')
                Text('✔ Already saved (sale #${r.saleId})', style: TextStyle(color: Colors.green.shade700))
              else
                FilledButton.icon(
                    onPressed: _save, icon: const Icon(Icons.check), label: const Bi('నిర్ధారించు', 'Confirm and save')),
            ]),
    );
  }

  Widget _lineCard(_OcrDraft d) {
    final chosen = d.packId == null ? null : app.packById[d.packId];
    final inCands = d.cands.any((c) => c.pack.id == d.packId);
    return Opacity(
      opacity: d.keep ? 1 : 0.45,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: surfaceTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: brandTeal.withValues(alpha: 0.5))),
              child: Text(
                  '📝 ${d.raw.itemText}${d.raw.itemEn.isNotEmpty ? ' (${d.raw.itemEn})' : ''} · '
                  '${d.raw.qtyValue > 0 ? d.raw.qtyValue : ''} ${d.raw.qtyUnit} · ${rs(d.raw.amount)}',
                  style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 6),
            DropdownButton<int>(
              isExpanded: true,
              value: d.packId,
              hint: const Text('— choose item / ఎంచుకోండి —'),
              items: [
                for (final c in d.cands)
                  DropdownMenuItem(
                    value: c.pack.id,
                    child: Text(
                        '${c.pack.item!.nameTe} ${c.pack.item!.nameEn} ${c.pack.size} ${rs(c.pack.price)} '
                        '(${(c.m.score * 100).clamp(0, 100).round()}%)',
                        overflow: TextOverflow.ellipsis),
                  ),
                if (chosen != null && !inCands)
                  DropdownMenuItem(value: chosen.id, child: Text('${chosen.item!.nameEn} ${chosen.size}')),
              ],
              onChanged: (id) {
                final p = id == null ? null : app.packById[id];
                if (p != null) _choose(d, p);
              },
            ),
            PackPicker(hint: 'or search…', onPick: (p) => _choose(d, p)),
            Row(children: [
              Expanded(child: NumField(label: 'Qty', value: d.qty, onChanged: (v) => setState(() => d.qty = v))),
              const SizedBox(width: 8),
              Expanded(child: NumField(label: '₹ / unit', value: d.price, onChanged: (v) => setState(() => d.price = v))),
              Checkbox(value: d.keep, onChanged: (v) => setState(() => d.keep = v ?? true)),
              const Text('keep'),
            ]),
          ]),
        ),
      ),
    );
  }
}
