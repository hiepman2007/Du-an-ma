import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/api_client.dart';
import '../widgets/motion.dart';
import '../widgets/source_widgets.dart';
import 'lesson_screen.dart';

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
  final _lanes = ScrollController();

  @override
  void dispose() {
    _lanes.dispose();
    super.dispose();
  }

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

  void _openLesson(Course course, Lesson lesson) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonScreen(courseId: course.id, lessonId: lesson.id),
      ),
    );
  }

  Lesson? _nextLesson(List<Lesson> lessons) {
    Lesson? firstUnfinished;
    Lesson? mostRecent;
    for (final lesson in lessons) {
      if (lesson.isDone) continue;
      firstUnfinished ??= lesson;
      final lastStudied = lesson.lastStudiedAt;
      if (lastStudied != null &&
          (mostRecent == null ||
              lastStudied.isAfter(mostRecent.lastStudiedAt!))) {
        mostRecent = lesson;
      }
    }
    return mostRecent ?? firstUnfinished;
  }

  List<_StudyPhase> _phases(List<Lesson> lessons) {
    final phases = <_StudyPhase>[];
    for (final lesson in lessons) {
      final name = lesson.phase.trim();
      if (phases.isEmpty ||
          phases.last.name != name ||
          (name.isEmpty && phases.last.lessons.length == 3)) {
        phases.add(_StudyPhase(name: name, lessons: []));
      }
      phases.last.lessons.add(lesson);
    }
    return phases;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.courseById(widget.courseId);
    if (c == null) return const Text('Khóa học đã bị xóa');
    final total = c.lessons.length;
    final next = _nextLesson(c.lessons);
    final phases = _phases(c.lessons);
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
                      'Hoàn thành ${c.doneLessons}/$total bài',
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
        if (phases.isEmpty)
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
        ] else
          LayoutBuilder(
            builder: (context, constraints) {
              final horizontal =
                  constraints.maxWidth >= 700 && phases.length > 1;
              final tiles = [
                for (var i = 0; i < phases.length; i++)
                  _PhaseCard(
                    key: ValueKey(phases[i].lessons.first.id),
                    name: phases[i].name,
                    index: i,
                    lessons: phases[i].lessons,
                    course: c,
                    next: next,
                    onOpen: (lesson) => _openLesson(c, lesson),
                  ),
              ];
              if (horizontal) {
                final laneWidth =
                    ((constraints.maxWidth - (phases.length - 1) * 28) /
                            phases.length)
                        .clamp(230.0, 340.0);
                return Scrollbar(
                  controller: _lanes,
                  thumbVisibility: phases.length * 258 - 28 > constraints.maxWidth,
                  child: SingleChildScrollView(
                    controller: _lanes,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < tiles.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.only(top: 17, left: 4, right: 4),
                              child: Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                          SizedBox(width: laneWidth, child: tiles[i]),
                        ],
                      ],
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 18, top: 2, bottom: 2),
                          child: Icon(
                            Icons.arrow_downward,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    tiles[i],
                  ],
                ],
              );
            },
          ),
      ],
    );
  }
}

class _StudyPhase {
  const _StudyPhase({required this.name, required this.lessons});

  final String name;
  final List<Lesson> lessons;
}

class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    super.key,
    required this.name,
    required this.index,
    required this.lessons,
    required this.course,
    required this.next,
    required this.onOpen,
  });

  final String name;
  final int index;
  final List<Lesson> lessons;
  final Course course;
  final Lesson? next;
  final ValueChanged<Lesson> onOpen;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final done = lessons.where((lesson) => lesson.isDone).length;
    final active = lessons.contains(next);
    final allDone = done == lessons.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: active || index == 0,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: allDone
              ? AppColors.success
              : active
              ? color.primary
              : color.primaryContainer,
          foregroundColor: active || allDone
              ? color.onPrimary
              : color.onPrimaryContainer,
          child: allDone
              ? const Icon(Icons.check, size: 17)
              : Text('${index + 1}'),
        ),
        title: Text(
          name.isEmpty ? 'Chặng ${index + 1}' : name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text('$done/${lessons.length} bài đã xong'),
        children: [
          for (final lesson in lessons)
            _LessonNode(
              course: course,
              lesson: lesson,
              active: lesson == next,
              onTap: () => onOpen(lesson),
            ),
        ],
      ),
    );
  }
}

class _LessonNode extends StatelessWidget {
  const _LessonNode({
    required this.course,
    required this.lesson,
    required this.active,
    required this.onTap,
  });

  final Course course;
  final Lesson lesson;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    final date = lesson.scheduledAt;
    final requiredTitles = [
      for (final candidate in course.lessons)
        if (lesson.prerequisites.contains(candidate.id))
          candidate.title,
    ];
    final status = lesson.isDone
        ? 'Đã hoàn thành'
        : lesson.lastStudiedAt != null
        ? 'Đang học'
        : 'Chưa học';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: active ? color.primaryContainer : color.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  lesson.isDone
                      ? Icons.check_circle
                      : active
                      ? Icons.play_circle
                      : Icons.circle_outlined,
                  color: lesson.isDone
                      ? AppColors.success
                      : active
                      ? color.primary
                      : color.outline,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: theme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$status · ${lesson.minutes} phút${date == null || lesson.isDone ? '' : ' · ${date.day}/${date.month}'}',
                        style: theme.bodySmall?.copyWith(
                          color: color.onSurfaceVariant,
                        ),
                      ),
                      if (requiredTitles.isNotEmpty)
                        Text(
                          'Học trước ${requiredTitles.join(', ')}',
                          style: theme.bodySmall?.copyWith(
                            color: color.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
