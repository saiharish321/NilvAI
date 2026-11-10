import 'package:flutter_test/flutter_test.dart';
import 'package:nilvai/logic.dart';

void main() {
  test('Indian currency format', () {
    expect(rs(1234567.5), '₹12,34,567.50');
    expect(rs0(814000), '₹8,14,000');
    expect(rs(99), '₹99.00');
  });

  test('Telugu transliteration is searchable', () {
    expect(teluguToLatin('కందిపప్పు'), 'kandipappu');
    expect(teluguToLatin('బియ్యం'), contains('biyyam'));
  });

  test('fuzzy search ranks the right item', () {
    expect(similarity('kandi', 'kandipappu'), greaterThan(0.9));
    expect(similarity('toor', 'Toor Dal'), greaterThan(0.9));
    expect(similarity('suger', 'Sugar'), greaterThan(similarity('suger', 'Salt')));
    expect(similarity('కంది', 'కందిపప్పు'), greaterThan(0.9));
  });

  test('pack sizes', () {
    expect(parsePackSize('250 g'), const Qty('mass', 0.25));
    expect(parsePackSize('26 kg bag'), const Qty('mass', 26));
    expect(parsePackSize('500 ml'), const Qty('vol', 0.5));
    expect(parsePackSize('Per tray (30)'), const Qty('count', 30));
    expect(parsePackSize('Sachet'), const Qty('count', 1));
  });

  test('CSV round trip with Telugu and commas', () {
    final rows = [
      {'a': 'కందిపప్పు', 'b': '1,000'},
      {'a': 'x"y', 'b': '2'},
    ];
    expect(parseCsv(toCsv(rows)), rows);
  });

  test('catalogue groups packs under items', () {
    final c = catalogueFromRows(parseCsv(
        'category,name_en,name_te,brand,pack,cost,price\nRice,Raw Rice,పచ్చి బియ్యం,Local,1 kg loose,43.6,50\nRice,Raw Rice,పచ్చి బియ్యం,Local,26 kg bag,1550,1650\n'));
    expect(c.items.length, 1);
    expect(c.packs.length, 2);
    expect(c.packs[1].price, 1650);
  });

  test('turns from two counts plus purchases', () {
    final packs = {1: const PackPrice(100, 110)};
    const open = CountData('2026-11-01', [LineQty(1, 100)]); // 10,000 at cost
    const close = CountData('2026-11-11', [LineQty(1, 80)]); // 8,000
    final purchases = [const PurchaseData('2026-11-05', [(qty: 10.0, cost: 100.0)])]; // 1,000
    final r = turnsFromCounts(open, close, purchases, packs, 0.11)!;
    expect(r.cogs, 3000);
    expect(r.avgStock, 9000);
    expect(r.turns, closeTo(3000 / 9000 * 36.5, 1e-9));
  });

  test('break-even matches the workbook: 9.67 turns covers wage + rent, 7.66 covers wage', () {
    const m = 0.110176904176904, stock = 724316.0;
    expect(monthlyEarning(9.67071049462557, stock, m, 326308, 121000), closeTo((240000 + 180000) / 12, 1));
    expect(monthlyEarning(7.66, stock, m, 326308, 121000), closeTo(20000, 100));
  });

  test('ABC split', () {
    final r = abc({'a': 70.0, 'b': 15.0, 'c': 10.0, 'd': 5.0});
    expect([r['a'], r['b'], r['c'], r['d']], ['A', 'A', 'B', 'C']);
  });

  test('price hint picks the right pack', () {
    const line = OcrLine('', '', 2, 'kg', 116);
    final loose = scoreCandidate(line, '1 kg loose', 58, 0);
    final bag = scoreCandidate(line, '26 kg bag', 1875, 0);
    expect(loose.qty, 2);
    expect(loose.score, greaterThan(bag.score));
  });

  test('normalise model output', () {
    final r = normaliseOcr(
        '<think>x</think>```json\n{"lines":[{"item_text":"కారం","qty_value":"250","qty_unit":"g","amount":"99"}],"total":"99"}```');
    expect(r.lines.single.amount, 99);
    expect(r.total, 99);
  });
}
