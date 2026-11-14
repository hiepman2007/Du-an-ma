import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../screens/home_shell.dart';
import '../screens/lab_screen.dart';
import '../screens/study_actions.dart';
import '../services/intent.dart';
import '../theme.dart';
import 'roadmap_map.dart';
import 'sims/phenomenon_sim.dart';
import 'sims/sim_catalog.dart';

/// The tuong tac duoi cau tra loi cua gia su, theo y dinh nguoi hoc: xem truoc lo trinh, lam quiz,
/// chay thi nghiem ngay trong chat, va nut mo trang day du.
class IntentCard extends StatelessWidget {
  const IntentCard({super.key, required this.course, required this.message, required this.question, this.onAsk});
  final Course course;
  final ChatMessage message;
  final String question;
  final ValueChanged<String>? onAsk;

  @override
  Widget build(BuildContext context) {
    final intent = ChatIntent.fromId(message.intent);
    final hasSim = message.blocks.any((b) => b.type == BlockType.phenomenonSim);
    final scene = simCatalog[sceneFor(question)];
    if (intent == ChatIntent.none && (hasSim || scene == null)) return const SizedBox.shrink();
    final (icon, title, subtitle) = switch (intent) {
      ChatIntent.plan => (Icons.route, 'Lộ trình học', course.lessons.isEmpty ? 'Chưa có lộ trình. Lập ngay từ tài liệu của bạn.' : '${course.lessons.length} bài · ${course.doneLessons} đã học'),
      ChatIntent.quiz => (Icons.quiz_outlined, 'Luyện tập', 'Làm quiz từ chính tài liệu này, có giải thích từng câu.'),
      ChatIntent.flashcards => (Icons.style_outlined, 'Thẻ ghi nhớ', 'Lật thẻ để tự kiểm tra các khái niệm chính.'),
      ChatIntent.summary => (Icons.lightbulb_outline, 'Tóm tắt', 'Bản tóm tắt có trích nguồn, lưu vào Studio.'),
      ChatIntent.test => (Icons.timer_outlined, 'Thi thử', 'Làm bài có đếm giờ như thi thật.'),
      _ => (Icons.science_outlined, 'Phòng thí nghiệm ảo', scene == null ? 'Chọn một thí nghiệm để tự tay thử.' : 'Thử ngay: ${scene.title}'),
    };
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
        if (intent == ChatIntent.plan && course.lessons.isNotEmpty) ...[const SizedBox(height: 10), MiniPath(course: course)],
        if ((intent == ChatIntent.lab || intent == ChatIntent.none) && scene != null && !hasSim) ...[
          const SizedBox(height: 10),
          PhenomenonSim(scene: scene, onAsk: onAsk),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: _actions(context, intent)),
      ]),
    );
  }

  List<Widget> _actions(BuildContext context, ChatIntent intent) => switch (intent) {
        ChatIntent.plan => [
            FilledButton.icon(
              onPressed: () => course.lessons.isEmpty
                  ? StudyActions.plan(context, course, topic: StudyActions.topicFrom(question))
                  : openStudyPage(context, course, StudyPage.plan),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(course.lessons.isEmpty ? 'Lập lộ trình' : 'Mở lộ trình'),
            ),
          ],
        ChatIntent.quiz => [
            FilledButton.icon(
                onPressed: () => StudyActions.create(context, course, StudyArtifactKind.quickQuiz),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Làm quiz nhanh')),
            OutlinedButton(onPressed: () => StudyActions.quizBuilder(context, course), child: const Text('Tùy chỉnh')),
          ],
        ChatIntent.flashcards => [
            FilledButton(onPressed: () => openStudyPage(context, course, StudyPage.flashcards), child: const Text('Mở thẻ ghi nhớ')),
          ],
        ChatIntent.summary => [
            FilledButton(onPressed: () => StudyActions.create(context, course, StudyArtifactKind.summary), child: const Text('Xem tóm tắt')),
          ],
        ChatIntent.test => [
            FilledButton(onPressed: () => openStudyPage(context, course, StudyPage.test), child: const Text('Vào thi thử')),
          ],
        _ => [
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabScreen(courseId: course.id))),
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Mở Phòng thí nghiệm'),
            ),
          ],
      };
}

/// Duong hoc thu nho kieu Duolingo: toi da 6 bai, mau theo trang thai.
class MiniPath extends StatelessWidget {
  const MiniPath({super.key, required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final graph = RoadmapGraph(course.lessons);
    final lessons = course.lessons.take(6).toList();
    return SizedBox(
      height: 64,
      child: Row(children: [
        for (final (i, l) in lessons.indexed) ...[
          if (i > 0) Expanded(child: Container(height: 3, color: AppColors.border)),
          Tooltip(
            message: l.title,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: graph.statusOf(l).color.withValues(alpha: graph.statusOf(l) == LessonStatus.locked ? 0.25 : 1),
              child: Icon(graph.statusOf(l) == LessonStatus.done ? Icons.check : graph.statusOf(l) == LessonStatus.locked ? Icons.lock : Icons.star,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ]),
    );
  }
}
