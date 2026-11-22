import 'dart:async';

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Ce a fost trimis către aplicație din altă aplicație: text sau poza unei rețete.
class SharedItem {
  const SharedItem({this.text, this.imagePath});
  final String? text;
  final String? imagePath;

  static SharedItem? fromMap(Object? m) {
    if (m is! Map) return null;
    final text = m['text'] as String?;
    final image = m['image'] as String?;
    if ((text == null || text.trim().isEmpty) && image == null) return null;
    return SharedItem(text: text, imagePath: image);
  }
}

/// „Trimite către Mănușa”: primește ce vine din `MainActivity` pe canalul `ro.manusa/share`.
class ShareInbox {
  ShareInbox() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') {
        final item = SharedItem.fromMap(call.arguments);
        if (item != null) _items.add(item);
      }
    });
  }

  static const _channel = MethodChannel('ro.manusa/share');
  final _items = StreamController<SharedItem>.broadcast();

  /// Ce sosește cât timp aplicația e deschisă.
  Stream<SharedItem> get items => _items.stream;

  /// Ce a deschis aplicația (o singură dată).
  Future<SharedItem?> take() async {
    try {
      return SharedItem.fromMap(await _channel.invokeMethod<Object?>('take'));
    } catch (_) {
      return null; // altă platformă sau teste
    }
  }
}

/// Citește textul dintr-o poză, pe telefon (ML Kit, fără internet).
Future<String> readTextFromImage(String path) async {
  final reader = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await reader.processImage(InputImage.fromFilePath(path));
    // Rândurile, în ordinea în care apar pe pagină (de sus în jos, apoi de la stânga la dreapta).
    final lines = [for (final b in result.blocks) ...b.lines]
      ..sort((a, b) {
        final dy = a.boundingBox.top - b.boundingBox.top;
        return dy.abs() < 12 ? a.boundingBox.left.compareTo(b.boundingBox.left) : dy.sign.toInt();
      });
    return _joinRows(lines);
  } finally {
    await reader.close();
  }
}

/// Lipește bucățile aflate pe același rând (ex. numele în stânga, doza în dreapta).
String _joinRows(List<TextLine> lines) {
  final rows = <List<TextLine>>[];
  for (final l in lines) {
    if (rows.isNotEmpty) {
      final last = rows.last.first.boundingBox;
      final mid = l.boundingBox.center.dy;
      if (mid > last.top && mid < last.bottom) {
        rows.last.add(l);
        continue;
      }
    }
    rows.add([l]);
  }
  return rows.map((r) => (r..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left))).map((l) => l.text).join('  ')).join('\n');
}
