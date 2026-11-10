import 'package:flutter/material.dart';

import '../db.dart';
import '../logic.dart';
import '../widgets.dart';

/// Enter a bill at the counter, or a day's receipts after closing.
class SaleScreen extends StatefulWidget {
  const SaleScreen({super.key});
  @override
  State<SaleScreen> createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  String _date = today();
  String _source = 'batch';
  List<Line> _lines = [];
  int _savedToday = 0;
  int _editor = 0; // bumps to reset the line editor after saving

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final n = await Db.instance.salesCountOn(_date);
    if (mounted) setState(() => _savedToday = n);
  }

  Future<void> _save() async {
    if (_lines.isEmpty) {
      toast(context, 'Add items first');
      return;
    }
    await Db.instance.saveSale(_date, _source, _lines);
    setState(() {
      _lines = [];
      _editor++;
    });
    await _loadCount();
    if (mounted) toast(context, 'Saved ✓');
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: [
        Bi('అమ్మకం నమోదు', 'Enter a sale', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(children: [
          DateField(_date, (d) {
            setState(() => _date = d);
            _loadCount();
          }),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'batch', label: Text('After closing')),
                ButtonSegment(value: 'counter', label: Text('Counter')),
              ],
              selected: {_source},
              onSelectionChanged: (s) => setState(() => _source = s.first),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        LineEditor(key: ValueKey(_editor), lines: _lines, mode: LineMode.sale),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Bi('భద్రపరచు', 'Save')),
        const SizedBox(height: 8),
        Center(child: Text('$_savedToday saved for $_date', style: const TextStyle(color: Colors.black54))),
      ]);
}
