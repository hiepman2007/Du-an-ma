import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Luu toan bo du lieu app vao mot file JSON tren may (dong mo lai app van con).
class Storage {
  Storage({this.accountId});

  final String? accountId;
  Future<void> _writes = Future.value();
  String get _key => 'hoc-thong-minh:${accountId ?? 'guest'}';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final suffix = accountId == null ? '' : '_$accountId';
    return File('${dir.path}/app_data$suffix.json');
  }

  Future<Map<String, dynamic>> load() async {
    if (kIsWeb) {
      final saved = await SharedPreferencesAsync().getString(_key);
      return saved == null ? {} : jsonDecode(saved) as Map<String, dynamic>;
    }
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  /// Ghi vao file tam roi doi ten, tranh hong du lieu neu app bi tat giua chung.
  Future<void> save(Map<String, dynamic> data) {
    final snapshot = jsonEncode(data);
    final write = _writes.then((_) => _write(snapshot));
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

  Future<void> _write(String snapshot) async {
    if (kIsWeb) {
      await SharedPreferencesAsync().setString(_key, snapshot);
      return;
    }
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(snapshot, flush: true);
    await tmp.rename(f.path);
  }
}
