import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'lesson_screen.dart';
import 'study_artifact_screen.dart';

/// On tap: chu de yeu (tu cac cau sai) va bai can lam lai.
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final items = <({String topic, int count, String courseId, String itemId, String title, bool quiz})>[];
    for (final c in s.courses) {
      for (final l in c.lessons) {
        final bs = l.blocks;
        if (bs == null) continue;
        final counts = <String, int>{};
        l.results.forEach((i, ok) {
          if (!ok && i >= 0 && i < bs.length && bs[i].topic.isNotEmpty) counts.update(bs[i].topic, (n) => n + 1, ifAbsent: () => 1);
        });
        counts.forEach((t, n) => items.add((topic: t, count: n, courseId: c.id, itemId: l.id, title: l.title, quiz: false)));
      }
      for (final artifact in c.artifacts.where((a) => a.kind.isQuiz && a.attempts.isNotEmpty)) {
        final counts = <String, int>{};
        final results = artifact.attempts.last.results;
        for (var i = 0; i < artifact.blocks.length; i++) {
          final block = artifact.blocks[i];
          if (results[artifact.questionKey(i)] == false) {
            counts.update(block.topic.isEmpty ? artifact.title : block.topic, (n) => n + 1, ifAbsent: () => 1);
          }
        }
        counts.forEach((t, n) => items.add((topic: t, count: n, courseId: c.id, itemId: artifact.id, title: artifact.title, quiz: true)));
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
              ? 'Làm bài tập hoặc quiz để xem những chủ đề cần ôn.'
              : 'Ôn đúng chỗ yếu thay vì đọc lại cả tài liệu.',
          action: items.isEmpty ? 'Xem khóa học' : 'Ôn chủ đề yếu nhất',
          onTap: () {
            if (items.isEmpty) return;
            final it = items.first;
            Navigator.push(context, MaterialPageRoute(builder: (_) => it.quiz
              ? StudyArtifactScreen(courseId: it.courseId, artifactId: it.itemId)
              : LessonScreen(courseId: it.courseId, lessonId: it.itemId)));
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
                  subtitle: Text('Sai ${items[i].count} câu · ${items[i].title}'),
                  trailing: const Icon(Icons.arrow_forward, color: AppColors.primary),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => items[i].quiz
                        ? StudyArtifactScreen(courseId: items[i].courseId, artifactId: items[i].itemId)
                        : LessonScreen(courseId: items[i].courseId, lessonId: items[i].itemId))),
                ),
              ),
            ),
        ],
      ]),
    );
  }
}
