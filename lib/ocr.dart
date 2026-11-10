import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'db.dart';
import 'files.dart';
import 'logic.dart';
import 'state.dart';

/// Photos come through Android's own camera and gallery screens: the app needs no camera or storage permission.
Future<int> addReceiptPhotos({required bool camera}) async {
  final picker = ImagePicker();
  final picked = <XFile>[];
  if (camera) {
    final x = await picker.pickImage(source: ImageSource.camera, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (x != null) picked.add(x);
  } else {
    picked.addAll(await picker.pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 85));
  }
  final dir = await receiptsDir();
  for (final x in picked) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dest = p.join(dir.path, 'receipt_$stamp${p.extension(x.path).isEmpty ? '.jpg' : p.extension(x.path)}');
    await File(x.path).copy(dest);
    await Db.instance.saveReceipt(Receipt(created: DateTime.now().toIso8601String(), name: x.name, imagePath: dest));
  }
  return picked.length;
}

Future<bool> serverOnline() async {
  try {
    final r = await http.get(Uri.parse('${app.settings['ocr_url']}/health')).timeout(const Duration(seconds: 3));
    return r.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Sends one receipt photo to the laptop OCR server and stores the result.
Future<void> readReceipt(Receipt r) async {
  r.status = 'sending';
  r.error = '';
  await Db.instance.saveReceipt(r);
  try {
    final req = http.MultipartRequest('POST', Uri.parse('${app.settings['ocr_url']}/extract'))
      ..headers['X-Nilvai-Token'] = app.settings['ocr_token'] ?? ''
      ..fields['mode'] = app.settings['ocr_mode'] ?? 'full'
      ..files.add(await http.MultipartFile.fromPath('file', r.imagePath));
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(minutes: 5)));
    if (res.statusCode == 401) throw const HttpException('Wrong OCR token: check Settings');
    if (res.statusCode != 200) throw HttpException('Server error ${res.statusCode}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    r.result = normaliseOcr(j);
    r.seconds = num0(j['seconds']);
    r.model = (j['model'] ?? '').toString();
    r.status = 'done';
  } catch (e) {
    r.status = 'error';
    r.error = e.toString();
  }
  await Db.instance.saveReceipt(r);
}

/// Imports results.json written by ocr-server/batch.py (when the phone could not reach the laptop).
Future<int> importResults(String text) async {
  final data = jsonDecode(text) as Map<String, dynamic>;
  final existing = await Db.instance.allReceipts();
  String stem(String s) => p.basenameWithoutExtension(s);
  var n = 0;
  for (final raw in (data['receipts'] as List? ?? [])) {
    final m = raw as Map<String, dynamic>;
    final file = (m['file'] ?? '').toString();
    final match = existing.where((x) => x.status != 'confirmed' && x.name.isNotEmpty && stem(x.name) == stem(file));
    final r = match.isNotEmpty ? match.first : Receipt(created: DateTime.now().toIso8601String(), name: file);
    r.result = normaliseOcr(m);
    r.seconds = num0(m['seconds']);
    r.model = (data['model'] ?? '').toString();
    r.status = 'done';
    await Db.instance.saveReceipt(r);
    n++;
  }
  return n;
}
