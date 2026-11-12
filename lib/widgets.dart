import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'logic.dart';
import 'state.dart';

// Look: FlexColorScheme's open-source "Blue Whale" scheme (MIT, github.com/rydmike/flex_color_scheme),
// with its orange accents swapped for teal and sky blue.
const brand = FlexColor.blueWhaleLightPrimary; // deep navy
const brandTeal = FlexColor.blueWhaleLightPrimaryVariant; // teal
const surfaceTint = Color(0xFFE6F2F1);

ThemeData nilvaiTheme() => FlexThemeData.light(
      colors: FlexColor.schemes[FlexScheme.blueWhale]!.light.copyWith(
        secondary: brandTeal,
        secondaryContainer: FlexColor.blueWhaleLightPrimaryContainer,
        tertiary: const Color(0xFF219EBC),
        tertiaryContainer: const Color(0xFFB8E3F0),
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      appBarStyle: FlexAppBarStyle.primary,
      appBarElevation: 0,
      visualDensity: VisualDensity.standard,
      subThemesData: const FlexSubThemesData(
        defaultRadius: 8,
        cardElevation: 0,
        inputDecoratorIsFilled: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorUnfocusedHasBorder: false,
        navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
        navigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarLabelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        navigationBarHeight: 72,
        snackBarBackgroundSchemeColor: SchemeColor.primary,
      ),
    ).copyWith(
      // Big tap targets for the shop counter.
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
    );

/// Telugu label with English beside it.
class Bi extends StatelessWidget {
  final String te, en;
  final TextStyle? style;
  const Bi(this.te, this.en, {super.key, this.style});
  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(TextSpan(children: [
      TextSpan(text: te, style: base),
      // English in a softer shade of the same colour, so it also reads on the dark app bar.
      TextSpan(
          text: '  $en',
          style: base.copyWith(
              color: (base.color ?? Colors.black).withValues(alpha: 0.6), fontWeight: FontWeight.normal)),
    ]));
  }
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

class SectionTitle extends StatelessWidget {
  final String te, en;
  const SectionTitle(this.te, this.en, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Bi(te, en, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );
}

/// Item name block used in lists.
class PackName extends StatelessWidget {
  final Pack? pack;
  const PackName(this.pack, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = pack;
    if (p == null) return const Text('?');
    final it = p.item!;
    return Text.rich(TextSpan(children: [
      if (it.nameTe.isNotEmpty) TextSpan(text: '${it.nameTe}  ', style: const TextStyle(fontWeight: FontWeight.bold)),
      TextSpan(text: it.nameEn),
      TextSpan(text: '  ${it.brand} · ${p.size}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
    ]));
  }
}

Future<DateTime?> pickDate(BuildContext context, String current) => showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current) ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

class DateField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const DateField(this.value, this.onChanged, {super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.calendar_today, size: 18),
        label: Text(value),
        onPressed: () async {
          final d = await pickDate(context, value);
          if (d != null) onChanged(isoDate(d));
        },
      );
}

/// Search box that lists matching packs; tapping one calls [onPick].
class PackPicker extends StatefulWidget {
  final ValueChanged<Pack> onPick;
  final String hint;
  const PackPicker({super.key, required this.onPick, this.hint = 'Add item… / సరుకు వెతకండి'});
  @override
  State<PackPicker> createState() => _PackPickerState();
}

class _PackPickerState extends State<PackPicker> {
  final _c = TextEditingController();
  List<Pack> _res = [];
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _c,
          decoration: InputDecoration(hintText: widget.hint, prefixIcon: const Icon(Icons.search)),
          onChanged: (v) => setState(() => _res = v.trim().isEmpty ? [] : app.search(v, limit: 8)),
        ),
        for (final p in _res)
          ListTile(
            dense: true,
            title: PackName(p),
            trailing: Text(rs(p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: () {
              widget.onPick(p);
              _c.clear();
              setState(() => _res = []);
            },
          ),
      ]);
}

enum LineMode { sale, purchase, count }

/// Editable list of lines for a sale, purchase or stock count.
class LineEditor extends StatefulWidget {
  final List<Line> lines;
  final LineMode mode;
  final VoidCallback? onChanged;
  const LineEditor({super.key, required this.lines, required this.mode, this.onChanged});
  @override
  State<LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<LineEditor> {
  void _changed() {
    setState(() {});
    widget.onChanged?.call();
  }

  double get _total => widget.lines
      .fold(0.0, (s, l) => s + l.qty * (widget.mode == LineMode.purchase ? l.cost : l.price));

  @override
  Widget build(BuildContext context) {
    final priceLabel = widget.mode == LineMode.purchase ? 'Cost ₹' : '₹ / unit';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PackPicker(onPick: (p) {
        final ex = widget.lines.where((l) => l.packId == p.id).toList();
        if (ex.isNotEmpty && widget.mode != LineMode.count) {
          ex.first.qty += 1;
        } else if (ex.isEmpty) {
          widget.lines.add(Line(p.id!, qty: widget.mode == LineMode.count ? 0 : 1, price: p.price, cost: p.cost));
        }
        _changed();
      }),
      const SizedBox(height: 8),
      if (widget.lines.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Center(child: Bi('ఏమీ లేదు', 'No lines yet'))),
      for (var i = 0; i < widget.lines.length; i++) _row(i, priceLabel),
      if (widget.mode != LineMode.count)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Bi('మొత్తం', 'Total'),
            const SizedBox(width: 12),
            Text(rs(_total), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ]),
        ),
    ]);
  }

  Widget _row(int i, String priceLabel) {
    final l = widget.lines[i];
    final p = app.packById[l.packId];
    return Card(
      key: ObjectKey(l),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: PackName(p)),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  widget.lines.removeAt(i);
                  _changed();
                }),
          ]),
          Row(children: [
            Expanded(child: NumField(label: 'Qty', value: l.qty, onChanged: (v) {
              l.qty = v;
              _changed();
            })),
            if (widget.mode != LineMode.count) ...[
              const SizedBox(width: 8),
              Expanded(
                  child: NumField(
                      label: priceLabel,
                      value: widget.mode == LineMode.purchase ? l.cost : l.price,
                      onChanged: (v) {
                        if (widget.mode == LineMode.purchase) {
                          l.cost = v;
                        } else {
                          l.price = v;
                        }
                        _changed();
                      })),
            ],
          ]),
        ]),
      ),
    );
  }
}

/// Number input that keeps its own controller so typing is not interrupted by rebuilds.
class NumField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const NumField({super.key, required this.label, required this.value, required this.onChanged});
  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late final TextEditingController _c = TextEditingController(text: _fmt(widget.value));
  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  @override
  void didUpdateWidget(NumField old) {
    super.didUpdateWidget(old);
    if (num0(_c.text) != widget.value) _c.text = _fmt(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: widget.label, isDense: true),
        onChanged: (v) => widget.onChanged(num0(v)),
      );
}

/// Card used on the report screen: title, body, course concept, and how much data it rests on.
class DashCard extends StatelessWidget {
  final String te, en, concept;
  final List<Widget> children;
  final String? basis;
  const DashCard({super.key, required this.te, required this.en, required this.concept, required this.children, this.basis});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Bi(te, en, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...children,
            if (basis != null)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(basis!, style: const TextStyle(color: Color(0xFFC98A00), fontSize: 12))),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(concept.toUpperCase(),
                  style: const TextStyle(fontSize: 11, color: Colors.black45, letterSpacing: 0.5)),
            ),
          ]),
        ),
      );
}

String basisText(int n, [String what = 'days of data']) =>
    'based on $n ${n == 1 ? what.replaceFirst('days', 'day') : what}';
