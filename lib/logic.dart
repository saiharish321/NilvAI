// Pure functions: no Flutter, no database. Unit-tested in test/logic_test.dart.
import 'dart:convert';
import 'dart:math' as math;

// ---------- Formatting ----------

/// Indian grouping: 12,34,567.89
String _group(int n) {
  final s = n.abs().toString();
  if (s.length <= 3) return (n < 0 ? '-' : '') + s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${n < 0 ? '-' : ''}${parts.join(',')},$last3';
}

String rs(num? n, {int decimals = 2}) {
  if (n == null || n.isNaN) return '–';
  final neg = n < 0;
  final fixed = n.abs().toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final whole = int.parse(dot < 0 ? fixed : fixed.substring(0, dot));
  final frac = dot < 0 ? '' : fixed.substring(dot);
  return '${neg ? '-' : ''}₹${_group(whole)}$frac';
}

String rs0(num? n) => rs(n, decimals: 0);

String pct(num? x, {int decimals = 1}) =>
    (x == null || x.isNaN) ? '–' : '${(x * 100).toStringAsFixed(decimals)}%';

double marginPct(double cost, double price) => price > 0 ? (price - cost) / price : 0;

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String today() => isoDate(DateTime.now());
int daysBetween(String a, String b) => DateTime.parse(b).difference(DateTime.parse(a)).inDays;

double num0(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(RegExp(r'[₹,\s]'), '');
  return double.tryParse(s) ?? 0;
}

// ---------- Telugu -> Latin (rough, for search only) ----------

const _vowels = {
  'అ': 'a', 'ఆ': 'aa', 'ఇ': 'i', 'ఈ': 'ii', 'ఉ': 'u', 'ఊ': 'uu', 'ఋ': 'ru',
  'ఎ': 'e', 'ఏ': 'ee', 'ఐ': 'ai', 'ఒ': 'o', 'ఓ': 'oo', 'ఔ': 'au',
};
const _consonants = {
  'క': 'k', 'ఖ': 'kh', 'గ': 'g', 'ఘ': 'gh', 'ఙ': 'n', 'చ': 'ch', 'ఛ': 'chh', 'జ': 'j', 'ఝ': 'jh', 'ఞ': 'n',
  'ట': 't', 'ఠ': 'th', 'డ': 'd', 'ఢ': 'dh', 'ణ': 'n', 'త': 't', 'థ': 'th', 'ద': 'd', 'ధ': 'dh', 'న': 'n',
  'ప': 'p', 'ఫ': 'ph', 'బ': 'b', 'భ': 'bh', 'మ': 'm', 'య': 'y', 'ర': 'r', 'ఱ': 'r', 'ల': 'l', 'ళ': 'l',
  'వ': 'v', 'శ': 'sh', 'ష': 'sh', 'స': 's', 'హ': 'h',
};
const _signs = {
  'ా': 'aa', 'ి': 'i', 'ీ': 'ii', 'ు': 'u', 'ూ': 'uu', 'ృ': 'ru', 'ె': 'e', 'ే': 'ee', 'ై': 'ai',
  'ొ': 'o', 'ో': 'oo', 'ౌ': 'au',
};
const _virama = '్';

String teluguToLatin(String s) {
  final ch = s.runes.map((r) => String.fromCharCode(r)).toList();
  final out = StringBuffer();
  for (var i = 0; i < ch.length; i++) {
    final c = ch[i];
    final nx = i + 1 < ch.length ? ch[i + 1] : '';
    if (_vowels.containsKey(c)) {
      out.write(_vowels[c]);
    } else if (_consonants.containsKey(c)) {
      out.write(_consonants[c]);
      if (nx == _virama) {
        i++;
      } else if (_signs.containsKey(nx)) {
        out.write(_signs[nx]);
        i++;
      } else {
        out.write('a');
      }
    } else if (c == 'ం') {
      final labial = 'పఫబభమ'.contains(nx) && nx.isNotEmpty;
      out.write(labial || !_consonants.containsKey(nx) ? 'm' : 'n');
    } else if (c == 'ః') {
      out.write('h');
    } else if (_signs.containsKey(c) || c == _virama) {
      continue;
    } else {
      out.write(c);
    }
  }
  return out.toString().replaceAll(RegExp(r'aa\b'), 'a').toLowerCase();
}

// ---------- Fuzzy matching (no library) ----------

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{M}\p{N} ]', unicode: true), ' ').trim();

Set<String> _bigrams(String s) {
  final t = ' $s ';
  final r = t.runes.toList();
  final out = <String>{};
  for (var i = 0; i < r.length - 1; i++) {
    out.add(String.fromCharCodes([r[i], r[i + 1]]));
  }
  return out;
}

double _dice(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 1;
  final x = _bigrams(a), y = _bigrams(b);
  final inter = x.intersection(y).length;
  return 2 * inter / (x.length + y.length);
}

/// Similarity 0..1 between a search query and one text field.
double similarity(String query, String target) {
  final q = _norm(query), t = _norm(target);
  if (q.isEmpty || t.isEmpty) return 0;
  final qc = q.replaceAll(' ', ''), tc = t.replaceAll(' ', '');
  if (tc.startsWith(qc)) return 1.0;
  if (tc.contains(qc)) return 0.92;
  final qTokens = q.split(RegExp(r'\s+'));
  final tTokens = t.split(RegExp(r'\s+'));
  var sum = 0.0;
  for (final qt in qTokens) {
    var best = 0.0;
    for (final tt in tTokens) {
      final s = tt.startsWith(qt) ? 0.95 : _dice(qt, tt);
      if (s > best) best = s;
    }
    sum += best;
  }
  final tokenScore = sum / qTokens.length;
  return math.max(tokenScore, _dice(qc, tc));
}

/// Best similarity of the query against several fields.
double bestSimilarity(String query, Iterable<String> fields) {
  var best = 0.0;
  for (final f in fields) {
    final s = similarity(query, f);
    if (s > best) best = s;
  }
  return best;
}

// ---------- Pack sizes ----------

class Qty {
  final String dim; // mass | vol | count
  final double base; // kg, L or pieces
  const Qty(this.dim, this.base);
  @override
  bool operator ==(Object other) => other is Qty && other.dim == dim && (other.base - base).abs() < 1e-9;
  @override
  int get hashCode => Object.hash(dim, base);
  @override
  String toString() => 'Qty($dim, $base)';
}

Qty parsePackSize(String label) {
  final s = label.toLowerCase();
  final m = RegExp(r'([\d.]+)\s*(kg|gm|g|ltr|l|ml)\b').firstMatch(s);
  if (m != null) {
    final v = double.tryParse(m.group(1)!) ?? 1;
    switch (m.group(2)) {
      case 'kg':
        return Qty('mass', v);
      case 'g':
      case 'gm':
        return Qty('mass', v / 1000);
      case 'l':
      case 'ltr':
        return Qty('vol', v);
      case 'ml':
        return Qty('vol', v / 1000);
    }
  }
  if (s.contains('dozen')) return const Qty('count', 12);
  final t = RegExp(r'tray\s*\((\d+)\)').firstMatch(s);
  if (t != null) return Qty('count', double.parse(t.group(1)!));
  return const Qty('count', 1);
}

Qty unitToBase(double value, String unit) {
  switch (unit.toLowerCase().trim()) {
    case 'kg':
      return Qty('mass', value);
    case 'g':
    case 'gm':
    case 'grams':
      return Qty('mass', value / 1000);
    case 'l':
    case 'ltr':
    case 'litre':
      return Qty('vol', value);
    case 'ml':
      return Qty('vol', value / 1000);
    default:
      return Qty('count', value);
  }
}

// ---------- CSV ----------

List<Map<String, String>> parseCsv(String text) {
  text = text.replaceFirst('﻿', '');
  final rows = <List<String>>[];
  var row = <String>[];
  final cur = StringBuffer();
  var q = false;
  void endField() {
    row.add(cur.toString());
    cur.clear();
  }

  void endRow() {
    endField();
    if (row.any((x) => x.isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (q) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cur.write('"');
        i++;
      } else if (c == '"') {
        q = false;
      } else {
        cur.write(c);
      }
    } else if (c == '"') {
      q = true;
    } else if (c == ',') {
      endField();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      cur.write(c);
    }
  }
  endRow();
  if (rows.isEmpty) return [];
  final keys = rows.first.map((h) => h.trim()).toList();
  return rows.skip(1).map((r) {
    final m = <String, String>{};
    for (var i = 0; i < keys.length; i++) {
      m[keys[i]] = i < r.length ? r[i].trim() : '';
    }
    return m;
  }).toList();
}

String toCsv(List<Map<String, Object?>> rows, [List<String>? cols]) {
  cols ??= {for (final r in rows) ...r.keys}.toList();
  String esc(Object? v) {
    final s = v?.toString() ?? '';
    return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  final lines = [cols.join(','), ...rows.map((r) => cols!.map((c) => esc(r[c])).join(','))];
  return '﻿${lines.join('\n')}';
}

// ---------- Catalogue import ----------

class CatItem {
  final String key, nameEn, nameTe, brand, category, abcSeed, supplier;
  final double creditDays;
  CatItem(this.key, this.nameEn, this.nameTe, this.brand, this.category, this.abcSeed, this.supplier, this.creditDays);
}

class CatPack {
  final String itemKey, size;
  final double cost, price;
  CatPack(this.itemKey, this.size, this.cost, this.price);
}

/// Columns: category,name_en,name_te,brand,pack,cost,price[,abc,supplier,credit_days]
({List<CatItem> items, List<CatPack> packs}) catalogueFromRows(List<Map<String, String>> rows) {
  final items = <String, CatItem>{};
  final packs = <CatPack>[];
  for (final r in rows) {
    final en = r['name_en'] ?? '', te = r['name_te'] ?? '';
    if (en.isEmpty && te.isEmpty) continue;
    final cat = (r['category'] ?? '').isEmpty ? 'Other' : r['category']!;
    final brand = r['brand'] ?? '';
    final key = '$cat|$en|$brand';
    items.putIfAbsent(key,
        () => CatItem(key, en, te, brand, cat, r['abc'] ?? '', r['supplier'] ?? '', num0(r['credit_days'])));
    packs.add(CatPack(key, (r['pack'] ?? '').isEmpty ? 'Each' : r['pack']!, num0(r['cost']), num0(r['price'])));
  }
  return (items: items.values.toList(), packs: packs);
}

// ---------- Stock and turns ----------

class LineQty {
  final int packId;
  final double qty;
  const LineQty(this.packId, this.qty);
}

class PackPrice {
  final double cost, price;
  const PackPrice(this.cost, this.price);
}

class CountData {
  final String date;
  final List<LineQty> lines;
  final double otherValueSp;
  const CountData(this.date, this.lines, [this.otherValueSp = 0]);
}

class PurchaseData {
  final String date;
  final List<({double qty, double cost})> lines;
  const PurchaseData(this.date, this.lines);
  double get value => lines.fold(0.0, (s, l) => s + l.qty * l.cost);
}

({double cost, double sp}) countValue(CountData c, Map<int, PackPrice> packs, double blendedMargin) {
  var cost = 0.0, sp = 0.0;
  for (final l in c.lines) {
    final p = packs[l.packId];
    if (p == null) continue;
    cost += l.qty * p.cost;
    sp += l.qty * p.price;
  }
  return (cost: cost + c.otherValueSp * (1 - blendedMargin), sp: sp + c.otherValueSp);
}

class TurnsResult {
  final int days;
  final double cogs, avgStock, purchases, turns;
  const TurnsResult(this.days, this.cogs, this.avgStock, this.purchases, this.turns);
}

/// Primary method: COGS = opening stock + purchases - closing stock, between two counts.
TurnsResult? turnsFromCounts(
    CountData open, CountData close, List<PurchaseData> purchases, Map<int, PackPrice> packs, double margin) {
  final days = daysBetween(open.date, close.date);
  if (days <= 0) return null;
  final a = countValue(open, packs, margin), b = countValue(close, packs, margin);
  final bought = purchases
      .where((p) => p.date.compareTo(open.date) > 0 && p.date.compareTo(close.date) <= 0)
      .fold(0.0, (s, p) => s + p.value);
  final cogs = a.cost + bought - b.cost;
  final avg = (a.cost + b.cost) / 2;
  if (avg <= 0) return null;
  return TurnsResult(days, cogs, avg, bought, cogs / avg * 365 / days);
}

/// Cross-check: COGS from logged sales against the latest stock at cost.
double? turnsFromSales(double salesCogs, double stockCost, int days) {
  if (days <= 0 || stockCost <= 0) return null;
  return salesCogs / stockCost * 365 / days;
}

/// Owner's monthly earning implied by a turn rate (staff and overheads are annual).
double monthlyEarning(double turns, double stockCost, double margin, double staffCost, double overheads) {
  final cogs = turns * stockCost;
  final sales = cogs / (1 - margin);
  return (sales - cogs - staffCost - overheads) / 12;
}

// ---------- ABC ----------

Map<K, String> abc<K>(Map<K, double> contribution) {
  final arr = contribution.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
  final total = arr.fold(0.0, (s, e) => s + e.value);
  final out = <K, String>{};
  var cum = 0.0;
  for (final e in arr) {
    final before = cum / total;
    cum += e.value;
    out[e.key] = before < 0.8 ? 'A' : (before < 0.95 ? 'B' : 'C');
  }
  return out;
}

// ---------- OCR ----------

class OcrLine {
  final String itemText, itemEn, qtyUnit;
  final double qtyValue, amount;
  const OcrLine(this.itemText, this.itemEn, this.qtyValue, this.qtyUnit, this.amount);
  Map<String, Object?> toJson() =>
      {'item_text': itemText, 'item_en': itemEn, 'qty_value': qtyValue, 'qty_unit': qtyUnit, 'amount': amount};
}

class OcrResult {
  final List<OcrLine> lines;
  final double? total;
  const OcrResult(this.lines, this.total);
  Map<String, Object?> toJson() => {'lines': lines.map((l) => l.toJson()).toList(), 'total': total};
}

/// Accepts the server's JSON (or loose model text) and returns clean lines.
OcrResult normaliseOcr(Object? input) {
  Object? o = input;
  if (o is String) {
    final cleaned = o
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '')
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    try {
      o = jsonDecode(cleaned);
    } catch (_) {
      return const OcrResult([], null);
    }
  }
  if (o is! Map) return const OcrResult([], null);
  final raw = (o['lines'] ?? o['items'] ?? []) as List;
  final lines = <OcrLine>[];
  for (final l in raw) {
    if (l is! Map) continue;
    final line = OcrLine(
      (l['item_text'] ?? l['item'] ?? '').toString().trim(),
      (l['item_en'] ?? '').toString().trim(),
      num0(l['qty_value'] ?? l['qty']),
      (l['qty_unit'] ?? l['unit'] ?? '').toString().trim(),
      num0(l['amount'] ?? l['price']),
    );
    if (line.itemText.isNotEmpty || line.itemEn.isNotEmpty || line.amount > 0) lines.add(line);
  }
  return OcrResult(lines, o['total'] == null ? null : num0(o['total']));
}

class MatchScore {
  final double score, qty, priceScore;
  const MatchScore(this.score, this.qty, this.priceScore);
}

/// Combines text similarity with a price check: a line of Rs 116 for 2 kg fits a Rs 58/kg pack.
MatchScore scoreCandidate(OcrLine line, String packSize, double packPrice, double textScore) {
  final ps = parsePackSize(packSize);
  var qty = 1.0;
  if (line.qtyValue > 0) {
    final lb = unitToBase(line.qtyValue, line.qtyUnit);
    if (lb.dim == ps.dim && ps.base > 0) {
      qty = lb.base / ps.base;
    } else if (lb.dim == 'count') {
      qty = line.qtyValue;
    }
  }
  qty = (qty * 1000).round() / 1000;
  var priceScore = 0.5;
  if (line.amount > 0 && packPrice > 0 && qty > 0) {
    final expected = qty * packPrice;
    final err = (line.amount - expected).abs() / expected;
    priceScore = math.exp(-err * 6);
  }
  final hasText = (line.itemText + line.itemEn).trim().isNotEmpty;
  final whole = qty >= 1 && (qty - qty.roundToDouble()).abs() < 1e-6 ? 0.03 : 0.0;
  final score = (hasText ? 0.6 * textScore + 0.4 * priceScore : priceScore) + whole;
  return MatchScore(score, qty, priceScore);
}
