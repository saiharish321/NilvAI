import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'logic.dart';

// ---------- Models ----------

class Item {
  int? id;
  String key, nameEn, nameTe, brand, category, abcSeed, supplier;
  double creditDays;
  bool active;
  Item({
    this.id,
    required this.key,
    required this.nameEn,
    this.nameTe = '',
    this.brand = '',
    this.category = 'Other',
    this.abcSeed = '',
    this.supplier = '',
    this.creditDays = 0,
    this.active = true,
  });
  factory Item.fromMap(Map<String, Object?> m) => Item(
        id: m['id'] as int?,
        key: m['key'] as String? ?? '',
        nameEn: m['name_en'] as String? ?? '',
        nameTe: m['name_te'] as String? ?? '',
        brand: m['brand'] as String? ?? '',
        category: m['category'] as String? ?? 'Other',
        abcSeed: m['abc_seed'] as String? ?? '',
        supplier: m['supplier'] as String? ?? '',
        creditDays: num0(m['credit_days']),
        active: (m['active'] as int? ?? 1) == 1,
      );
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'key': key,
        'name_en': nameEn,
        'name_te': nameTe,
        'brand': brand,
        'category': category,
        'abc_seed': abcSeed,
        'supplier': supplier,
        'credit_days': creditDays,
        'active': active ? 1 : 0,
      };
  String get latin => teluguToLatin(nameTe);
}

class Pack {
  int? id;
  int itemId;
  String size;
  double cost, price;
  Item? item;
  Pack({this.id, required this.itemId, required this.size, this.cost = 0, this.price = 0, this.item});
  factory Pack.fromMap(Map<String, Object?> m) => Pack(
        id: m['id'] as int?,
        itemId: m['item_id'] as int,
        size: m['size'] as String? ?? '',
        cost: num0(m['cost']),
        price: num0(m['price']),
      );
  Map<String, Object?> toMap() =>
      {if (id != null) 'id': id, 'item_id': itemId, 'size': size, 'cost': cost, 'price': price};
  double get margin => marginPct(cost, price);
}

/// One line of a sale, purchase or stock count while it is being edited.
class Line {
  int packId;
  double qty, price, cost;
  Line(this.packId, {this.qty = 1, this.price = 0, this.cost = 0});
}

class Receipt {
  int? id;
  String created, name, imagePath, status, error, model, saleDate;
  OcrResult? result;
  double seconds;
  int? saleId;
  String corrections; // JSON list, for the OCR evaluation
  Receipt({
    this.id,
    required this.created,
    this.name = '',
    this.imagePath = '',
    this.status = 'queued',
    this.error = '',
    this.model = '',
    this.saleDate = '',
    this.result,
    this.seconds = 0,
    this.saleId,
    this.corrections = '',
  });
  factory Receipt.fromMap(Map<String, Object?> m) => Receipt(
        id: m['id'] as int?,
        created: m['created'] as String? ?? '',
        name: m['name'] as String? ?? '',
        imagePath: m['image_path'] as String? ?? '',
        status: m['status'] as String? ?? 'queued',
        error: m['error'] as String? ?? '',
        model: m['model'] as String? ?? '',
        saleDate: m['sale_date'] as String? ?? '',
        result: (m['result'] as String? ?? '').isEmpty ? null : normaliseOcr(jsonDecode(m['result'] as String)),
        seconds: num0(m['seconds']),
        saleId: m['sale_id'] as int?,
        corrections: m['corrections'] as String? ?? '',
      );
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'created': created,
        'name': name,
        'image_path': imagePath,
        'status': status,
        'error': error,
        'model': model,
        'sale_date': saleDate,
        'result': result == null ? '' : jsonEncode(result!.toJson()),
        'seconds': seconds,
        'sale_id': saleId,
        'corrections': corrections,
      };
}

// ---------- Settings ----------

const settingDefaults = <String, String>{
  'shop_name': 'నిల్వAI · Nilvai',
  'turns_with_rent': '9.67',
  'turns_cash': '7.66',
  'owner_wage_month': '20000',
  'staff_cost': '326308',
  'other_overheads': '121000',
  'blended_margin': '0.11',
  'ocr_url': 'http://192.168.1.10:8765',
  'ocr_token': '',
  'ocr_mode': 'full',
  'pin': '',
  'last_backup': '',
};

// ---------- Database ----------

class Db {
  Db._();
  static final Db instance = Db._();
  Database? _db;

  static const _tables = [
    'items', 'packs', 'sales', 'sale_lines', 'purchases', 'purchase_lines',
    'counts', 'count_lines', 'trials', 'settings',
  ];

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'nilvai.db');
    return openDatabase(path, version: 1, onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, v) async {
      final b = d.batch();
      b.execute('''CREATE TABLE items(id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT UNIQUE, name_en TEXT, name_te TEXT,
        brand TEXT, category TEXT, abc_seed TEXT, supplier TEXT, credit_days REAL, active INTEGER DEFAULT 1)''');
      b.execute('''CREATE TABLE packs(id INTEGER PRIMARY KEY AUTOINCREMENT, item_id INTEGER REFERENCES items(id),
        size TEXT, cost REAL, price REAL)''');
      b.execute('''CREATE TABLE sales(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, datetime TEXT, source TEXT,
        total REAL, receipt_id INTEGER)''');
      b.execute('''CREATE TABLE sale_lines(id INTEGER PRIMARY KEY AUTOINCREMENT, sale_id INTEGER REFERENCES sales(id) ON DELETE CASCADE,
        pack_id INTEGER, qty REAL, price REAL, cost REAL)''');
      b.execute('''CREATE TABLE purchases(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, supplier TEXT, channel TEXT,
        credit_days REAL)''');
      b.execute('''CREATE TABLE purchase_lines(id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER REFERENCES purchases(id) ON DELETE CASCADE, pack_id INTEGER, qty REAL, cost REAL)''');
      b.execute('CREATE TABLE counts(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT, other_value_sp REAL)');
      b.execute('''CREATE TABLE count_lines(id INTEGER PRIMARY KEY AUTOINCREMENT,
        count_id INTEGER REFERENCES counts(id) ON DELETE CASCADE, pack_id INTEGER, qty REAL)''');
      b.execute('CREATE TABLE trials(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, start_date TEXT, item_ids TEXT)');
      b.execute('''CREATE TABLE receipts(id INTEGER PRIMARY KEY AUTOINCREMENT, created TEXT, name TEXT, image_path TEXT,
        status TEXT, error TEXT, model TEXT, sale_date TEXT, result TEXT, seconds REAL, sale_id INTEGER, corrections TEXT)''');
      b.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      b.execute('CREATE INDEX idx_sales_date ON sales(date)');
      b.execute('CREATE INDEX idx_sale_lines_sale ON sale_lines(sale_id)');
      b.execute('CREATE INDEX idx_packs_item ON packs(item_id)');
      await b.commit(noResult: true);
    });
  }

  // ----- settings -----
  Future<Map<String, String>> settings() async {
    final rows = await (await db).query('settings');
    return {...settingDefaults, for (final r in rows) r['key'] as String: r['value'] as String? ?? ''};
  }

  Future<void> setSetting(String key, String value) async => (await db)
      .insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  // ----- catalogue -----
  Future<List<Item>> items() async =>
      (await (await db).query('items', orderBy: 'name_en COLLATE NOCASE')).map(Item.fromMap).toList();

  /// All packs of active items, joined with their item.
  Future<List<Pack>> packIndex() async {
    final items = {for (final i in await this.items()) i.id!: i};
    final packs = (await (await db).query('packs')).map(Pack.fromMap).toList();
    for (final pk in packs) {
      pk.item = items[pk.itemId];
    }
    return packs.where((pk) => pk.item != null && pk.item!.active).toList();
  }

  Future<List<Pack>> packsOf(int itemId) async =>
      (await (await db).query('packs', where: 'item_id = ?', whereArgs: [itemId])).map(Pack.fromMap).toList();

  Future<int> saveItem(Item it, List<Pack> packs) async {
    final d = await db;
    return d.transaction((t) async {
      final id = it.id ?? await t.insert('items', it.toMap());
      if (it.id != null) await t.update('items', it.toMap(), where: 'id = ?', whereArgs: [it.id]);
      for (final pk in packs.where((x) => x.size.trim().isNotEmpty)) {
        pk.itemId = id;
        if (pk.id != null) {
          await t.update('packs', pk.toMap(), where: 'id = ?', whereArgs: [pk.id]);
        } else {
          await t.insert('packs', pk.toMap());
        }
      }
      return id;
    });
  }

  /// Adds new items and packs; updates prices of ones that already exist.
  Future<({int items, int packs})> importCatalogue(List<CatItem> items, List<CatPack> packs) async {
    final d = await db;
    return d.transaction((t) async {
      final ids = <String, int>{};
      for (final c in items) {
        final row = {
          'key': c.key, 'name_en': c.nameEn, 'name_te': c.nameTe, 'brand': c.brand, 'category': c.category,
          'abc_seed': c.abcSeed, 'supplier': c.supplier, 'credit_days': c.creditDays, 'active': 1,
        };
        final ex = await t.query('items', columns: ['id'], where: 'key = ?', whereArgs: [c.key]);
        if (ex.isEmpty) {
          ids[c.key] = await t.insert('items', row);
        } else {
          ids[c.key] = ex.first['id'] as int;
          await t.update('items', row, where: 'id = ?', whereArgs: [ids[c.key]]);
        }
      }
      for (final pk in packs) {
        final itemId = ids[pk.itemKey]!;
        final ex = await t.query('packs', columns: ['id'], where: 'item_id = ? AND size = ?', whereArgs: [itemId, pk.size]);
        final row = {'item_id': itemId, 'size': pk.size, 'cost': pk.cost, 'price': pk.price};
        if (ex.isEmpty) {
          await t.insert('packs', row);
        } else {
          await t.update('packs', row, where: 'id = ?', whereArgs: [ex.first['id']]);
        }
      }
      return (items: items.length, packs: packs.length);
    });
  }

  // ----- sales -----
  Future<int> saveSale(String date, String source, List<Line> lines, {int? receiptId}) async {
    final d = await db;
    final keep = lines.where((l) => l.qty > 0).toList();
    return d.transaction((t) async {
      final id = await t.insert('sales', {
        'date': date,
        'datetime': DateTime.now().toIso8601String(),
        'source': source,
        'total': keep.fold(0.0, (s, l) => s + l.qty * l.price),
        'receipt_id': receiptId,
      });
      for (final l in keep) {
        await t.insert('sale_lines', {'sale_id': id, 'pack_id': l.packId, 'qty': l.qty, 'price': l.price, 'cost': l.cost});
      }
      return id;
    });
  }

  Future<int> salesCountOn(String date) async =>
      Sqflite.firstIntValue(await (await db).rawQuery('SELECT COUNT(*) FROM sales WHERE date = ?', [date])) ?? 0;

  /// Every sale line with its sale date and source.
  Future<List<Map<String, Object?>>> saleLines() async => (await db).rawQuery(
      'SELECT s.id AS sale_id, s.date, s.source, l.pack_id, l.qty, l.price, l.cost FROM sale_lines l JOIN sales s ON s.id = l.sale_id ORDER BY s.date');

  // ----- purchases -----
  Future<void> savePurchase(String date, String supplier, String channel, double creditDays, List<Line> lines) async {
    final d = await db;
    await d.transaction((t) async {
      final id = await t.insert('purchases', {'date': date, 'supplier': supplier, 'channel': channel, 'credit_days': creditDays});
      for (final l in lines.where((l) => l.qty > 0)) {
        await t.insert('purchase_lines', {'purchase_id': id, 'pack_id': l.packId, 'qty': l.qty, 'cost': l.cost});
        if (l.cost > 0) await t.update('packs', {'cost': l.cost}, where: 'id = ?', whereArgs: [l.packId]);
      }
    });
  }

  Future<List<Map<String, Object?>>> purchases() async => (await db).rawQuery(
      'SELECT p.*, COALESCE(SUM(l.qty * l.cost), 0) AS value FROM purchases p LEFT JOIN purchase_lines l ON l.purchase_id = p.id GROUP BY p.id ORDER BY p.date DESC, p.id DESC');

  Future<List<Map<String, Object?>>> purchaseLines() async => (await db).rawQuery(
      'SELECT p.id AS purchase_id, p.date, p.supplier, p.channel, p.credit_days, l.pack_id, l.qty, l.cost FROM purchase_lines l JOIN purchases p ON p.id = l.purchase_id ORDER BY p.date');

  // ----- stock counts -----
  Future<void> saveCount(String date, double otherValueSp, List<Line> lines) async {
    final d = await db;
    await d.transaction((t) async {
      final id = await t.insert('counts', {'date': date, 'other_value_sp': otherValueSp});
      for (final l in lines.where((l) => l.qty > 0)) {
        await t.insert('count_lines', {'count_id': id, 'pack_id': l.packId, 'qty': l.qty});
      }
    });
  }

  /// Stock counts, oldest first, with their lines.
  Future<List<CountData>> counts() async {
    final d = await db;
    final cs = await d.query('counts', orderBy: 'date, id');
    final out = <CountData>[];
    for (final c in cs) {
      final lines = await d.query('count_lines', where: 'count_id = ?', whereArgs: [c['id']]);
      out.add(CountData(c['date'] as String,
          lines.map((l) => LineQty(l['pack_id'] as int, num0(l['qty']))).toList(), num0(c['other_value_sp'])));
    }
    return out;
  }

  // ----- trials -----
  Future<List<Map<String, Object?>>> trials() async => (await db).query('trials', orderBy: 'start_date');
  Future<void> addTrial(String name, String start, List<int> itemIds) async =>
      (await db).insert('trials', {'name': name, 'start_date': start, 'item_ids': itemIds.join(',')});
  Future<void> deleteTrial(int id) async => (await db).delete('trials', where: 'id = ?', whereArgs: [id]);

  // ----- receipts -----
  Future<List<Receipt>> receipts() async =>
      (await (await db).query('receipts', orderBy: 'id DESC', limit: 100)).map(Receipt.fromMap).toList();
  Future<Receipt?> receipt(int id) async {
    final r = await (await db).query('receipts', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : Receipt.fromMap(r.first);
  }

  Future<int> saveReceipt(Receipt r) async {
    final d = await db;
    if (r.id == null) return r.id = await d.insert('receipts', r.toMap());
    await d.update('receipts', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
    return r.id!;
  }

  Future<void> deleteReceipt(int id) async => (await db).delete('receipts', where: 'id = ?', whereArgs: [id]);
  Future<List<Receipt>> allReceipts() async => (await (await db).query('receipts')).map(Receipt.fromMap).toList();

  // ----- backup -----
  Future<String> backupJson() async {
    final d = await db;
    final out = <String, Object?>{'app': 'nilvai', 'version': 1, 'exported': DateTime.now().toIso8601String()};
    for (final t in _tables) {
      out[t] = await d.query(t);
    }
    return jsonEncode(out);
  }

  Future<void> restoreJson(String text) async {
    final data = jsonDecode(text);
    if (data is! Map || data['app'] != 'nilvai') throw const FormatException('Not a Nilvai backup');
    final d = await db;
    await d.transaction((t) async {
      for (final name in _tables.reversed) {
        await t.delete(name);
      }
      for (final name in _tables) {
        for (final row in (data[name] as List? ?? [])) {
          await t.insert(name, Map<String, Object?>.from(row as Map));
        }
      }
    });
    debugPrint('restored backup');
  }
}
