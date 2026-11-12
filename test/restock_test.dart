import 'package:flutter_test/flutter_test.dart';
import 'package:nilvai/screens/restock_planner.dart';

void main() {
  test('restock planner starting rows, festival week on', () {
    final coconut = RestockItem('', '', 'pcs', avg7: 40, avg3: 55, onHand: 30, festivalFactor: 2, coverDays: 2);
    final broom = RestockItem('', '', 'pcs', avg7: 5, avg3: 15, onHand: 5, coverDays: 4);
    final bulb = RestockItem('', '', 'pcs', avg7: 6, avg3: 7, onHand: 7, coverDays: 8);
    final sugar = RestockItem('', '', 'packs',
        avg7: 15, avg3: 22, onHand: 20, festivalFactor: 2, coverDays: 3, prepack: true, packsPerBag: 50);
    final dal = RestockItem('', '', 'packs', avg7: 8, avg3: 10, onHand: 12, festivalFactor: 1.5, coverDays: 4);
    final rice = RestockItem('', '', 'bags', avg7: 2.7, avg3: 2.7, onHand: 8, festivalFactor: 1.2, coverDays: 30);

    expect(coconut.quantity(true), 264);
    expect(broom.quantity(true), 50);
    expect(broom.spike(), isTrue);
    expect(bulb.quantity(true), 50);
    expect(sugar.quantity(true), 134);
    expect((sugar.quantity(true) / sugar.packsPerBag).ceil(), 3);
    expect(dal.quantity(true), 57);
    expect(rice.quantity(true), 93);
    expect(rice.quantity(false), 75);
  });
}
