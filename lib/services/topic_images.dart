import 'dart:convert';

import 'package:http/http.dart' as http;

/// Anh xem truoc cho chu de/bai hoc: lay anh dai dien cua bai Wikipedia gan nhat (API cong khai, khong can key).
/// Chi gui ten chu de, khong gui du lieu nguoi dung. Ket qua (ke ca "khong co anh") duoc nho trong phien.
class TopicImages {
  TopicImages({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final Map<String, Future<String?>> _cache = {};

  Future<String?> lookup(String topic, {String subject = ''}) {
    final key = '${subject.trim()}|${topic.trim()}'.toLowerCase();
    return _cache.putIfAbsent(key, () async {
      for (final lang in const ['vi', 'en']) {
        for (final q in [if (subject.trim().isNotEmpty) '${topic.trim()} ${subject.trim()}', topic.trim()]) {
          final url = await _search(lang, q);
          if (url != null) return url;
        }
      }
      return null;
    });
  }

  Future<String?> _search(String lang, String query) async {
    if (query.isEmpty) return null;
    final uri = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'generator': 'search',
      'gsrsearch': query,
      'gsrlimit': '5',
      'prop': 'pageimages',
      'piprop': 'thumbnail',
      'pithumbsize': '480',
      'format': 'json',
      'origin': '*',
    });
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final pages = ((jsonDecode(res.body) as Map)['query'] as Map?)?['pages'] as Map?;
      if (pages == null) return null;
      final sorted = pages.values.whereType<Map>().toList()
        ..sort((a, b) => ((a['index'] as num?) ?? 99).compareTo((b['index'] as num?) ?? 99));
      for (final p in sorted) {
        final src = (p['thumbnail'] as Map?)?['source'];
        if (src is String && src.startsWith('https://') && !src.toLowerCase().endsWith('.svg')) return src;
      }
    } catch (_) {}
    return null;
  }
}
