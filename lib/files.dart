import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Lets the user pick one file and returns its text, or null if cancelled.
Future<({String name, String text})?> pickTextFile() async {
  final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
  if (r == null || r.files.isEmpty) return null;
  final f = r.files.single;
  final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
  if (bytes == null) return null;
  return (name: f.name, text: utf8.decode(bytes, allowMalformed: true));
}

/// Writes files to the app's temporary folder and opens the Android share sheet (WhatsApp, email…).
Future<void> shareFiles(Map<String, String> files, {String? text}) async {
  final dir = await getTemporaryDirectory();
  final xs = <XFile>[];
  for (final e in files.entries) {
    final f = File(p.join(dir.path, e.key));
    await f.writeAsString(e.value);
    xs.add(XFile(f.path));
  }
  await SharePlus.instance.share(ShareParams(files: xs, text: text));
}

/// Folder that holds receipt photos (private to the app).
Future<Directory> receiptsDir() async {
  final d = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'receipts'));
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}
