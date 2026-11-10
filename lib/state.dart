import 'package:flutter/foundation.dart';

import 'db.dart';
import 'logic.dart';

/// App-wide state: the catalogue index, settings and owner mode.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  List<Pack> packs = [];
  Map<int, Pack> packById = {};
  Map<String, String> settings = Map.of(settingDefaults);
  bool owner = false;

  double setting(String k) => double.tryParse(settings[k] ?? '') ?? double.tryParse(settingDefaults[k] ?? '') ?? 0;

  Future<void> refresh() async {
    packs = await Db.instance.packIndex();
    packs.sort((a, b) => (a.item!.nameEn).toLowerCase().compareTo(b.item!.nameEn.toLowerCase()));
    packById = {for (final p in packs) p.id!: p};
    settings = await Db.instance.settings();
    notifyListeners();
  }

  Future<void> setSetting(String k, String v) async {
    await Db.instance.setSetting(k, v);
    settings[k] = v;
    notifyListeners();
  }

  void setOwner(bool v) {
    owner = v;
    notifyListeners();
  }

  /// Search packs by Telugu, English, romanised Telugu, brand or size.
  List<Pack> search(String q, {int limit = 30}) {
    if (q.trim().isEmpty) return packs.take(limit).toList();
    final scored = <(Pack, double)>[];
    for (final p in packs) {
      final it = p.item!;
      final s = bestSimilarity(q, [it.nameEn, it.nameTe, it.latin, '${it.brand} ${it.nameEn}', p.size]);
      if (s >= 0.45) scored.add((p, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }

  /// Text similarity of every pack to an OCR line, for matching.
  Map<int, double> textScores(OcrLine l) {
    final queries = [l.itemText, l.itemEn, if (l.itemText.isNotEmpty) teluguToLatin(l.itemText)]
        .where((s) => s.trim().isNotEmpty)
        .toList();
    final out = <int, double>{};
    if (queries.isEmpty) return out;
    for (final p in packs) {
      final it = p.item!;
      var best = 0.0;
      for (final q in queries) {
        final s = bestSimilarity(q, [it.nameEn, it.nameTe, it.latin]);
        if (s > best) best = s;
      }
      out[p.id!] = best;
    }
    return out;
  }

  /// Top candidate packs for one OCR line, best first.
  List<({Pack pack, MatchScore m})> rankMatches(OcrLine l, {int k = 6}) {
    final text = textScores(l);
    final ranked = packs
        .map((p) => (pack: p, m: scoreCandidate(l, p.size, p.price, text[p.id!] ?? 0)))
        .toList()
      ..sort((a, b) => b.m.score.compareTo(a.m.score));
    return ranked.take(k).toList();
  }
}

final app = AppState.instance;
