import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Luu toan bo du lieu app vao mot file JSON tren may (dong mo lai app van con).
/// Ban web (chi de xem thu): giu trong bo nho, tai lai trang se mat.
class Storage {
  Map<String, dynamic>? _memory;

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/app_data.json');
  }

  Future<Map<String, dynamic>> load() async {
    if (kIsWeb) return _memory ?? {};
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Ghi vao file tam roi doi ten, tranh hong du lieu neu app bi tat giua chung.
  Future<void> save(Map<String, dynamic> data) async {
    if (kIsWeb) {
      _memory = data;
      return;
    }
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }
}
