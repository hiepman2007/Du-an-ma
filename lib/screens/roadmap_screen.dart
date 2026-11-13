import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/api_client.dart';
import '../widgets/lesson_image.dart';
import '../widgets/motion.dart';
import '../widgets/roadmap_map.dart';
import '../widgets/source_widgets.dart';
import 'canvas_screen.dart';
import 'lesson_screen.dart';
import 'quiz_builder_screen.dart';
import 'tutor_chat_screen.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key, required this.courseId, this.showSources = true});
  final String courseId;
  final bool showSources;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.courseById(courseId);
    if (c == null) {
      return const Scaffold(body: Center(child: Text('Khóa học đã bị xóa')));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lộ trình'),
        actions: [
          IconButton(
            tooltip: 'Xóa khóa học',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Xóa khóa học?'),
                  content: const Text('Khóa học và tiến độ học sẽ bị xóa.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(d, false),
                      child: const Text('Hủy'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(d, true),
                      child: const Text('Xóa'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                if (Navigator.canPop(context)) Navigator.pop(context);
                await s.deleteCourse(c);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StudyRoadmap(courseId: courseId, showSources: showSources, expanded: true),
        ],
      ),
    );
  }
}

class StudyRoadmap extends StatefulWidget {
  const StudyRoadmap({
    super.key,
    required this.courseId,
    this.showSources = false,
    this.expanded = false,
  });

  final String courseId;
  final bool showSources;
  final bool expanded;

  @override
  State<StudyRoadmap> createState() => _StudyRoadmapState();
}

class _StudyRoadmapState extends State<StudyRoadmap> {
  bool _editing = false;

  Future<void> _rename(BuildContext context, Lesson l) async {
    var title = l.title;
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Đổi tên bài'),
        content: TextFormField(
          initialValue: title,
          onChanged: (value) => title = value,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, title.trim()),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    if (v != null && v.isNotEmpty && context.mounted) {
      await context.read<AppState>().renameLesson(l, v);
    }
  }

  void _openLesson(Course course, Lesson lesson) => openLesson(context, course, lesson);

  Future<void> _showLesson(Course course, RoadmapGraph graph, Lesson lesson) => showLessonDetails(context, course, lesson);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.courseById(widget.courseId);
    if (c == null) return const Text('Khóa học đã bị xóa');
    final total = c.lessons.length;
    final graph = RoadmapGraph(c.lessons);
    final next = graph.next();
    final mastered = c.lessons.where(isMastered).length;
    final review = c.lessons.where(needsReview).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroBackground(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (c.subject.isNotEmpty ? c.subject : c.sourceLabel)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (c.goal.isNotEmpty)
                      Text(
                        c.goal,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Đã học ${c.doneLessons}/$total bài · Nắm vững $mastered',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ProgressRing(
                value: total == 0 ? 0 : c.doneLessons / total,
                size: 72,
                stroke: 7,
                color: Colors.white,
                track: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (widget.showSources) ...[
          _SourcesPanel(course: c),
          const SizedBox(height: 14),
        ],
        if (next != null)
          FilledButton.icon(
            onPressed: () => _openLesson(c, next),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              next.lastStudiedAt == null ? 'Bắt đầu học' : 'Tiếp tục học',
            ),
          ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                'Sơ đồ học tập',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (c.lessons.isNotEmpty)
              IconButton(
                tooltip: _editing ? 'Xem sơ đồ' : 'Chỉnh sửa lộ trình',
                onPressed: () => setState(() => _editing = !_editing),
                icon: Icon(
                  _editing ? Icons.account_tree_outlined : Icons.edit_outlined,
                ),
              ),
            if (!widget.expanded && c.lessons.isNotEmpty)
              IconButton(
                tooltip: 'Mở rộng sơ đồ',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoadmapScreen(courseId: c.id, showSources: false),
                  ),
                ),
                icon: const Icon(Icons.open_in_full),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (c.lessons.isEmpty)
          const Text('Sơ đồ sẽ hiện sau khi có lộ trình.')
        else if (_editing) ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Giữ và kéo để đổi thứ tự.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) =>
                s.reorderLesson(c, from, to > from ? to + 1 : to),
            children: [
              for (var i = 0; i < c.lessons.length; i++)
                Padding(
                  key: ValueKey(c.lessons[i].id),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ReorderableDelayedDragStartListener(
                    index: i,
                    child: _LessonTile(
                      course: c,
                      lesson: c.lessons[i],
                      index: i,
                      onRename: () => _rename(context, c.lessons[i]),
                    ),
                  ),
                ),
            ],
          ),
        ] else ...[
          const RoadmapLegend(),
          const SizedBox(height: 12),
          RoadmapMap(
            graph: graph,
            next: next,
            onTap: (lesson) => _showLesson(c, graph, lesson),
          ),
          if (review.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Nên ôn lại',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final lesson in review)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.replay, color: AppColors.danger),
                  title: Text(lesson.title),
                  subtitle: Text(
                    'Đúng ${lesson.correctCount + lesson.quizCorrect}/${lesson.results.length + lesson.quizTotal} câu',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLesson(c, graph, lesson),
                ),
              ),
          ],
        ],
      ],
    );
  }
}

void openLesson(BuildContext context, Course course, Lesson lesson) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => LessonScreen(courseId: course.id, lessonId: lesson.id)));

/// Bảng chi tiết một bài: mục tiêu, bài cần học trước, mức nắm vững, các cách học bài đó.
Future<void> showLessonDetails(BuildContext context, Course course, Lesson lesson) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _LessonSheet(
      course: course,
      graph: RoadmapGraph(course.lessons),
      lesson: lesson,
      onStudy: () {
        Navigator.pop(sheet);
        openLesson(context, course, lesson);
      },
      onAsk: () {
        Navigator.pop(sheet);
        Navigator.push(context, MaterialPageRoute(builder: (_) => TutorChatScreen(courseId: course.id, lessonId: lesson.id)));
      },
      onCanvas: () {
        Navigator.pop(sheet);
        Navigator.push(context, MaterialPageRoute(builder: (_) => CanvasScreen(
          courseId: course.id, lessonId: lesson.id,
          initialPrompt: 'Mô phỏng tương tác giúp hiểu bài "${lesson.title}"'
              '${lesson.objectives.isEmpty ? '' : ': ${lesson.objectives.take(3).join('; ')}'}',
        )));
      },
      onQuiz: course.enabledSources.isEmpty
          ? null
          : () {
              Navigator.pop(sheet);
              Navigator.push(context, MaterialPageRoute(builder: (_) => QuizBuilderScreen(courseId: course.id, lessonId: lesson.id)));
            },
    ),
  );
}

class _LessonSheet extends StatelessWidget {
  const _LessonSheet({
    required this.course,
    required this.graph,
    required this.lesson,
    required this.onStudy,
    required this.onAsk,
    required this.onQuiz,
    required this.onCanvas,
  });

  final Course course;
  final RoadmapGraph graph;
  final Lesson lesson;
  final VoidCallback onStudy, onAsk;
  final VoidCallback? onQuiz;
  final VoidCallback onCanvas;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context).textTheme;
    final status = graph.statusOf(lesson);
    final missing = graph.missingPrerequisites(lesson);
    final before = [
      for (final id in graph.prerequisitesOf(lesson))
        if (graph.byId(id) case final Lesson l) l,
    ];
    final mastery = lessonMastery(lesson);
    const label = TextStyle(fontWeight: FontWeight.w800);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            LessonImage(course: course, lesson: lesson, aspect: 16 / 7, radius: 14),
            const SizedBox(height: 12),
            Row(children: [
              Icon(status.icon, size: 18, color: status.color),
              const SizedBox(width: 6),
              Text(status.label,
                  style: TextStyle(color: status.color, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${lesson.minutes} phút',
                  style: const TextStyle(color: AppColors.muted)),
            ]),
            const SizedBox(height: 8),
            Text(lesson.title,
                style: theme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (lesson.phase.isNotEmpty)
              Text('Chặng: ${lesson.phase}',
                  style: const TextStyle(color: AppColors.muted)),
            if (lesson.objectives.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Mục tiêu', style: label),
              const SizedBox(height: 4),
              for (final objective in lesson.objectives) Text('• $objective'),
            ],
            if (before.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Cần học trước', style: label),
              const SizedBox(height: 4),
              for (final l in before)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(children: [
                    Icon(l.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: l.completed ? AppColors.success : AppColors.muted),
                    const SizedBox(width: 6),
                    Expanded(child: Text(l.title)),
                  ]),
                ),
            ],
            if (mastery != null) ...[
              const SizedBox(height: 14),
              Text('Nắm vững ${(mastery * 100).round()}%', style: label),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: mastery,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
                color: needsReview(lesson) ? AppColors.danger : AppColors.success,
              ),
              const SizedBox(height: 4),
              Text('Đúng ${lesson.correctCount + lesson.quizCorrect}/${lesson.results.length + lesson.quizTotal} câu (bài học và quiz gần nhất)',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Nên học "${missing.first.title}" trước. Bạn vẫn có thể học bài này ngay.',
                  style: const TextStyle(color: AppColors.primaryDark),
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStudy,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(status == LessonStatus.inProgress
                    ? 'Học tiếp bài này'
                    : 'Học bài này'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAsk,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Hỏi gia sư về bài này'),
              ),
            ),
            if (onQuiz != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onQuiz,
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Làm quiz bài này'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onCanvas,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Mô phỏng bài này (Canvas)'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => state.setLessonCompleted(lesson, !lesson.completed),
                icon: Icon(lesson.completed ? Icons.undo : Icons.check),
                label: Text(lesson.completed ? 'Bỏ đánh dấu đã xong' : 'Đánh dấu đã xong'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.course, required this.lesson, required this.index, required this.onRename});
  final Course course;
  final Lesson lesson;
  final int index;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final status = lesson.blocks == null
        ? 'Chưa tạo · ~${lesson.minutes} phút'
        : lesson.isDone
            ? 'Đã hoàn thành'
            : lesson.lastStudiedAt == null
                ? 'Chưa học · ~${lesson.minutes} phút'
                : 'Đang học · bước ${lesson.stepIndex + 1}';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(appRadius),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(courseId: course.id, lessonId: lesson.id))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            NumberTile(index + 1, done: lesson.isDone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lesson.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(status, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                if (lesson.interactionHint.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.touch_app_outlined, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(lesson.interactionHint,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.primaryDark)),
                      ),
                    ]),
                  ),
                ],
                if (lesson.objectives.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final o in lesson.objectives.take(3))
                    Text('• $o', style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'rename') onRename();
                if (v == 'delete') context.read<AppState>().removeLesson(course, lesson);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                PopupMenuItem(value: 'delete', child: Text('Xóa bài')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// Khung Nguon kieu NotebookLM: tich chon nguon AI duoc dung, them nguon moi, bat/tat tra cuu web.
class _SourcesPanel extends StatefulWidget {
  const _SourcesPanel({required this.course});
  final Course course;
  @override
  State<_SourcesPanel> createState() => _SourcesPanelState();
}

class _SourcesPanelState extends State<_SourcesPanel> {
  bool _open = false;
  bool _adding = false;

  Future<void> _add(List<SourceDraft> drafts) async {
    setState(() => _adding = true);
    try {
      await context.read<AppState>().addSources(widget.course, drafts);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final s = context.read<AppState>();
    final on = c.enabledSources.length;
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          onTap: () => setState(() => _open = !_open),
          leading: const Icon(Icons.library_books_outlined, color: AppColors.primary),
          title: Text('Nguồn ($on/${c.sources.length} đang dùng)', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(c.allowWeb ? 'Gia sư được tra cứu thêm trên mạng' : 'Gia sư chỉ dựa vào các nguồn đã chọn'),
          trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final src in c.sources)
                SourceRow(
                  kind: src.kind,
                  title: src.title,
                  mimeType: src.mimeType,
                  url: src.url,
                  trusted: src.kind == SourceKind.web ? src.trusted : null,
                  subtitle: SourceRow.describe(src.kind, mimeType: src.mimeType, domain: src.domain, text: src.text),
                  enabled: src.enabled,
                  onToggle: (v) => s.setSourceEnabled(c, src, v),
                  onRemove: c.sources.length > 1 ? () => s.removeSource(c, src) : null,
                ),
              if (on == 0)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Chưa chọn nguồn nào: hãy tích ít nhất một nguồn.', style: TextStyle(color: AppColors.danger)),
                ),
              const SizedBox(height: 4),
              if (_adding)
                const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
              else
                SourceAddBar(onAdd: _add),
              WebSwitch(value: c.allowWeb, onChanged: (v) => s.setAllowWeb(c, v)),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Bài học, bộ đề và gia sư dùng các nguồn đang được tích. Bài đã tạo không đổi; bấm "Tạo lại bài" để cập nhật theo nguồn mới.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            ]),
          ),
      ]),
    );
  }
}
