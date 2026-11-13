import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'lesson_screen.dart';

/// On tap: chu de yeu (tu cac cau sai) va bai can lam lai.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = <({String topic, int count, String courseId, String lessonId, String lessonTitle})>[];
    for (final c in s.courses) {
      for (final l in c.lessons) {
        final bs = l.blocks;
        if (bs == null) continue;
        final counts = <String, int>{};
        l.results.forEach((i, ok) {
          if (!ok && i < bs.length && bs[i].topic.isNotEmpty) counts[bs[i].topic] = (counts[bs[i].topic] ?? 0) + 1;
        });
        counts.forEach((t, n) => items.add((topic: t, count: n, courseId: c.id, lessonId: l.id, lessonTitle: l.title)));
      }
    }
    items.sort((a, b) => b.count.compareTo(a.count));

    return Scaffold(
      appBar: AppBar(title: const Text('Ôn tập')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        HeroCard(
          eyebrow: 'Chẩn đoán lỗ hổng',
          title: items.isEmpty ? 'Chưa có chủ đề yếu' : '${items.length} chủ đề cần ôn',
          subtitle: items.isEmpty
              ? 'Làm bài tập trong các khóa học, AI sẽ gom những chỗ bạn sai thành danh sách ôn tập.'
              : 'Ôn đúng chỗ yếu thay vì đọc lại cả tài liệu.',
          action: items.isEmpty ? 'Xem khóa học' : 'Ôn chủ đề yếu nhất',
          onTap: () {
            if (items.isEmpty) return;
            final it = items.first;
            Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(courseId: it.courseId, lessonId: it.lessonId)));
          },
        ),
        const SizedBox(height: 20),
        if (items.isNotEmpty) ...[
          const SectionHeader(eyebrow: 'Ưu tiên ôn', title: 'Chủ đề yếu'),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: NumberTile(i + 1),
                  title: Text(items[i].topic, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Sai ${items[i].count} câu · ${items[i].lessonTitle}'),
                  trailing: const Icon(Icons.arrow_forward, color: AppColors.primary),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => LessonScreen(courseId: items[i].courseId, lessonId: items[i].lessonId))),
                ),
              ),
            ),
        ],
      ]),
    );
  }
}
