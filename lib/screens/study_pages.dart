import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/lesson_image.dart';
import '../widgets/motion.dart';
import '../widgets/roadmap_map.dart';
import '../widgets/source_tile.dart';
import '../widgets/source_widgets.dart';
import 'home_shell.dart';
import 'match_game_screen.dart';
import 'quiz_player_screen.dart';
import 'roadmap_screen.dart';
import 'study_actions.dart';

/// Khung chung cua mot trang: cuon doc, gioi han be ngang tren man rong, chua cho nut tro ly noi.
class _PageList extends StatelessWidget {
  const _PageList({required this.children, this.maxWidth = 960});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: children),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16), this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        child: child,
      );
}

String _examText(Course c) {
  final exam = c.brief?.examDate;
  if (exam == null) return '';
  final today = DateTime.now();
  final days = DateTime(exam.year, exam.month, exam.day).difference(DateTime(today.year, today.month, today.day)).inDays;
  final date = '${exam.day}/${exam.month}/${exam.year}';
  return days > 0 ? 'Còn $days ngày · $date' : days == 0 ? 'Thi hôm nay · $date' : 'Đã thi ngày $date';
}

/// Trang thai lap lo trinh: dang lam, can tiep tuc, chua co.
class _PlanState extends StatelessWidget {
  const _PlanState({required this.course, required this.onNavigate});
  final Course course;
  final ValueChanged<StudyPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = course;
    if (state.isBusy(c, 'plan')) {
      return _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 10),
          Text(c.brief?.searchWeb == true && !c.researchDone
              ? 'Đang tìm nguồn…'
              : c.lessons.isEmpty
                  ? 'Đang lập sơ đồ học…'
                  : 'Đang chuẩn bị bài giảng đầu tiên…'),
        ]),
      );
    }
    if (c.lessons.isEmpty) {
      return _Panel(
        color: AppColors.accent,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Chưa có lộ trình', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Tải tài liệu (slide, PDF, ảnh chụp) hoặc nhập chủ đề. AI sẽ chia thành các chủ đề, bài học và bài kiểm tra.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.icon(onPressed: () => StudyActions.plan(context, c), icon: const Icon(Icons.route_outlined), label: const Text('Lập lộ trình')),
            OutlinedButton.icon(onPressed: () => onNavigate(StudyPage.materials), icon: const Icon(Icons.upload_file), label: const Text('Tải tài liệu lên')),
          ]),
        ]),
      );
    }
    if (c.brief != null && c.lessons.first.blocks == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
            onPressed: () => StudyActions.continuePlan(context, c), icon: const Icon(Icons.refresh), label: const Text('Tiếp tục chuẩn bị khóa học')),
      );
    }
    return const SizedBox.shrink();
  }
}

// ---------------------------------------------------------------- Tong quan

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.course, required this.onNavigate});
  final Course course;
  final ValueChanged<StudyPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final c = course;
    final graph = RoadmapGraph(c.lessons);
    final next = graph.next();
    final total = c.lessons.length;
    final mastered = c.lessons.where(isMastered).length;
    final review = c.lessons.where(needsReview).take(3).toList();
    final recent = c.artifacts.reversed.take(4).toList();
    return _PageList(children: [
      Eyebrow((c.subject.isNotEmpty ? c.subject : 'Sổ học tập').toUpperCase()),
      const SizedBox(height: 4),
      Text(c.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
      if (c.isSample) const Text('Sổ mẫu · nội dung có sẵn', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 14),
      _PlanState(course: c, onNavigate: onNavigate),
      if (total > 0) ...[
        _Panel(
          child: Row(children: [
            ProgressRing(value: total == 0 ? 0 : c.doneLessons / total, size: 70, stroke: 7),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tiến độ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Text('$total chủ đề · ${c.doneLessons} đã học · $mastered nắm vững', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                if (c.brief?.examDate != null)
                  Row(children: [
                    const Icon(Icons.event, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Flexible(child: Text(_examText(c), style: const TextStyle(fontWeight: FontWeight.w700))),
                  ])
                else
                  InkWell(
                    onTap: () => StudyActions.plan(context, c, edit: c.brief != null),
                    child: const Text('+ Thêm ngày thi', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ],
      if (next != null) ...[
        _Panel(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showLessonDetails(context, c, next),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              LessonImage(course: c, lesson: next, aspect: 16 / 6, radius: 15),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Eyebrow(next.lastStudiedAt == null ? 'Bài tiếp theo' : 'Đang học dở'),
                  const SizedBox(height: 4),
                  Text(next.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text([if (next.phase.isNotEmpty) next.phase, '${next.minutes} phút'].join(' · '), style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => openLesson(context, c, next),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(next.lastStudiedAt == null ? 'Học bài này' : 'Học tiếp'),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 6),
      const Text('Luyện tập & hoạt động', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth >= 640 ? 3 : 2;
        final w = (box.maxWidth - 10 * (cols - 1)) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (i, p) in [StudyPage.plan, StudyPage.quiz, StudyPage.flashcards, StudyPage.test, StudyPage.arcade, StudyPage.research].indexed)
            SizedBox(
              width: w,
              child: _ActionTile(page: p, onTap: () => onNavigate(p)).enter(context, index: i),
            ),
        ]);
      }),
      if (review.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('Nên ôn lại', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        for (final l in review)
          Card(
            child: ListTile(
              leading: LessonImage(course: c, lesson: l, size: 40, radius: 8),
              title: Text(l.title),
              subtitle: Text('Nắm vững ${((lessonMastery(l) ?? 0) * 100).round()}%'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLessonDetails(context, c, l),
            ),
          ),
      ],
      if (recent.isNotEmpty) ...[
        const SizedBox(height: 18),
        const Text('Gần đây', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        for (final a in recent) _ArtifactCard(course: c, artifact: a),
      ],
    ]);
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.page, required this.onTap});
  final StudyPage page;
  final VoidCallback onTap;

  static const _hints = {
    StudyPage.plan: 'Chủ đề, bài học, kiểm tra',
    StudyPage.quiz: 'Tạo quiz từ tài liệu',
    StudyPage.flashcards: 'Thẻ ghi nhớ hai mặt',
    StudyPage.test: 'Làm bài có đếm giờ',
    StudyPage.arcade: 'Ghép nhanh thuật ngữ',
    StudyPage.research: 'Tìm nguồn uy tín',
  };

  @override
  Widget build(BuildContext context) => PressScale(
        onTap: onTap,
        child: _Panel(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(radius: 18, backgroundColor: AppColors.accent, child: Icon(page.icon, size: 20, color: AppColors.primary)),
            const SizedBox(height: 10),
            Text(page.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(_hints[page] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ]),
        ),
      );
}

class _ArtifactCard extends StatelessWidget {
  const _ArtifactCard({required this.course, required this.artifact, this.trailing});
  final Course course;
  final StudyArtifact artifact;
  final Widget? trailing;

  static IconData iconFor(StudyArtifactKind k) => switch (k) {
        StudyArtifactKind.flashcards => Icons.style_outlined,
        StudyArtifactKind.summary => Icons.lightbulb_outline,
        StudyArtifactKind.note => Icons.bookmark_outline,
        StudyArtifactKind.canvas => Icons.widgets_outlined,
        _ => Icons.checklist_rtl,
      };

  @override
  Widget build(BuildContext context) {
    final a = artifact;
    final best = a.attempts.isEmpty ? null : a.attempts.map((t) => t.score).reduce((x, y) => x > y ? x : y);
    final subtitle = a.kind == StudyArtifactKind.canvas
        ? 'Mini app · ${a.blocks.length} phiên bản'
        : a.attempts.isEmpty
            ? '${a.kind.label} · phiên bản ${a.version}'
            : '${a.attempts.length} lượt làm · cao nhất $best/${a.attempts.last.total}';
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: AppColors.accent, child: Icon(iconFor(a.kind), color: AppColors.primary, size: 20)),
        title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: trailing ?? const Icon(Icons.chevron_right),
        onTap: () => StudyActions.open(context, course, a),
      ),
    );
  }
}

// ---------------------------------------------------------------- Lo trinh

class StudyPlanPage extends StatelessWidget {
  const StudyPlanPage({super.key, required this.course, required this.onNavigate});
  final Course course;
  final ValueChanged<StudyPage> onNavigate;

  /// Nhom bai theo chang, giu thu tu xuat hien.
  static List<(String, List<Lesson>)> groups(Course c) {
    final out = <(String, List<Lesson>)>[];
    for (final l in c.lessons) {
      final name = l.phase.trim().isEmpty ? 'Các bài học' : l.phase.trim();
      final g = out.where((e) => e.$1 == name).firstOrNull;
      if (g == null) {
        out.add((name, [l]));
      } else {
        g.$2.add(l);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final c = course;
    final graph = RoadmapGraph(c.lessons);
    final next = graph.next();
    final summary = _PlanSummary(course: c, onNavigate: onNavigate);
    final timeline = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _PlanState(course: c, onNavigate: onNavigate),
      if (c.lessons.isNotEmpty) ...[
        Row(children: [
          if (next != null)
            Expanded(
              child: FilledButton.icon(
                onPressed: () => openLesson(context, c, next),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(next.lastStudiedAt == null ? 'Bắt đầu học' : 'Tiếp tục học'),
              ),
            )
          else
            const Expanded(child: Text('Bạn đã học hết lộ trình. Làm quiz hoặc thi thử để kiểm tra lại nhé!')),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Xem dạng sơ đồ',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoadmapScreen(courseId: c.id, showSources: false))),
            icon: const Icon(Icons.account_tree_outlined),
          ),
          if (c.brief != null)
            IconButton.outlined(
              tooltip: 'Điều chỉnh lịch học',
              onPressed: () => StudyActions.plan(context, c, edit: true),
              icon: const Icon(Icons.tune),
            ),
        ]),
        const SizedBox(height: 16),
        const _TimelineStart(),
        for (final (i, (name, lessons)) in groups(c).indexed)
          _PhaseCard(
            key: ValueKey('phase-$name'),
            course: c,
            graph: graph,
            title: name,
            lessons: lessons,
            initiallyOpen: next == null ? i == 0 : lessons.contains(next),
          ).enter(context, index: i),
      ],
    ]);
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 860) {
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_PlanHeader(course: c), timeline])),
                const SizedBox(width: 20),
                SizedBox(width: 280, child: summary),
              ]),
            ),
          ),
        );
      }
      return _PageList(children: [_PlanHeader(course: c), summary, const SizedBox(height: 14), timeline]);
    });
  }
}

class _PlanHeader extends StatelessWidget {
  const _PlanHeader({required this.course});
  final Course course;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.map_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(course.brief?.goal.isNotEmpty == true ? course.brief!.goal : 'Lộ trình học', style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
        ]),
      );
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.course, required this.onNavigate});
  final Course course;
  final ValueChanged<StudyPage> onNavigate;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final total = c.lessons.length;
    final pct = total == 0 ? 0 : (c.doneLessons * 100 / total).round();
    final mastered = c.lessons.where(isMastered).length;
    Widget stat(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [Icon(icon, size: 17, color: AppColors.muted), const SizedBox(width: 8), Text(text)]),
        );
    final files = c.activeSources.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Tiến độ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text('$pct%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
          ]),
          const SizedBox(height: 8),
          AnimatedBar(value: pct / 100),
          stat(Icons.menu_book_outlined, '$total chủ đề'),
          stat(Icons.check_circle_outline, '${c.doneLessons} đã học'),
          stat(Icons.workspace_premium_outlined, '$mastered nắm vững'),
        ]),
      ),
      const SizedBox(height: 10),
      _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ngày thi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          if (c.brief?.examDate != null) Text(_examText(c)),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => StudyActions.plan(context, c, edit: c.brief != null),
            icon: Icon(c.brief?.examDate == null ? Icons.add : Icons.edit_calendar_outlined, size: 18),
            label: Text(c.brief?.examDate == null ? 'Thêm ngày thi' : 'Đổi lịch học'),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Đề cương & tài liệu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(files == 0 ? 'Chưa có tài liệu.' : '$files tài liệu · ${c.enabledSources.length} đang dùng'),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => onNavigate(StudyPage.materials),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Thêm đề cương / tài liệu'),
          ),
        ]),
      ),
    ]);
  }
}

class _TimelineStart extends StatelessWidget {
  const _TimelineStart();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 6, bottom: 10),
        child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: AppColors.accent, child: Icon(Icons.near_me_outlined, size: 17, color: AppColors.primary)),
          SizedBox(width: 12),
          Text('Bắt đầu', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}

class _PhaseCard extends StatefulWidget {
  const _PhaseCard({
    super.key,
    required this.course,
    required this.graph,
    required this.title,
    required this.lessons,
    required this.initiallyOpen,
  });
  final Course course;
  final RoadmapGraph graph;
  final String title;
  final List<Lesson> lessons;
  final bool initiallyOpen;

  @override
  State<_PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends State<_PhaseCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final c = widget.course;
    final ls = widget.lessons;
    final done = ls.where((l) => l.isDone).length;
    final minutes = ls.fold(0, (s, l) => s + l.minutes);
    final allDone = done == ls.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(_open ? Icons.expand_more : Icons.chevron_right, color: AppColors.muted),
                const SizedBox(width: 4),
                Icon(allDone ? Icons.check_circle : done > 0 ? Icons.timelapse : Icons.radio_button_unchecked,
                    size: 20, color: allDone ? AppColors.success : done > 0 ? AppColors.primary : AppColors.muted),
                const SizedBox(width: 10),
                LessonImage(course: c, lesson: ls.first, size: 44, radius: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                    Text('${ls.length} bài · $minutes phút · $done/${ls.length} xong', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE9DDF7)),
                ),
                child: Row(children: [
                  const Icon(Icons.timer_outlined, size: 20, color: Color(0xFF7B4BB7)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Kiểm tra nhanh', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Khoảng 3 phút', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                  OutlinedButton(
                    onPressed: c.enabledSources.isEmpty ? null : () => StudyActions.quizBuilder(context, c, lessonId: ls.first.id),
                    child: const Text('Bắt đầu'),
                  ),
                ]),
              ),
            ),
            for (final l in ls) _LessonRow(course: c, lesson: l, status: widget.graph.statusOf(l)),
            const SizedBox(height: 6),
          ],
        ]),
      ),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.course, required this.lesson, required this.status});
  final Course course;
  final Lesson lesson;
  final LessonStatus status;

  @override
  Widget build(BuildContext context) {
    final mastery = lessonMastery(lesson);
    final sub = [
      '${lesson.minutes} phút',
      if (mastery != null) needsReview(lesson) ? 'Nên ôn lại' : 'Nắm vững ${(mastery * 100).round()}%',
      if (mastery == null) status.label,
    ].join(' · ');
    return InkWell(
      onTap: () => showLessonDetails(context, course, lesson),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          Icon(status.icon, size: 20, color: status.color),
          const SizedBox(width: 10),
          LessonImage(course: course, lesson: lesson, size: 48, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(lesson.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(sub, style: TextStyle(fontSize: 12, color: needsReview(lesson) ? AppColors.danger : AppColors.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Nghien cuu

class ResearchPage extends StatefulWidget {
  const ResearchPage({super.key, required this.course, required this.onNavigate});
  final Course course;
  final ValueChanged<StudyPage> onNavigate;

  @override
  State<ResearchPage> createState() => _ResearchPageState();
}

class _ResearchPageState extends State<ResearchPage> {
  late final _topic = TextEditingController(text: widget.course.brief?.topic ?? (widget.course.title == 'Sổ học tập mới' ? '' : widget.course.title));
  bool _loading = false, _adding = false;
  String? _error;
  List<WebSource> _results = [];
  final Set<String> _selected = {};

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final t = _topic.text.trim();
    if (t.isEmpty || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _selected.clear();
    });
    try {
      final r = await context.read<AppState>().searchSources(t);
      if (!mounted) return;
      final have = widget.course.sources.map((s) => s.url).whereType<String>().toSet();
      setState(() {
        _results = r.where((s) => !have.contains(s.url)).toList();
        _selected.addAll(_results.where((s) => s.trusted).take(3).map((s) => s.url));
        if (_results.isEmpty) _error = 'Không tìm thấy nguồn mới phù hợp. Hãy thử chủ đề cụ thể hơn.';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tìm được. Hãy kiểm tra kết nối rồi thử lại.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final picked = _results.where((s) => _selected.contains(s.url)).toList();
    if (picked.isEmpty) return;
    setState(() => _adding = true);
    try {
      await context.read<AppState>().addSources(widget.course, picked.map(SourceDraft.web).toList());
      if (mounted) {
        setState(() {
          _results.removeWhere((s) => _selected.contains(s.url));
          _selected.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã thêm ${picked.length} nguồn vào tài liệu.')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa thêm được nguồn. Hãy thử lại.');
    }
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = widget.course;
    final web = c.activeSources.where((s) => s.kind == SourceKind.web).toList();
    return _PageList(maxWidth: 820, children: [
      const SectionHeader(eyebrow: 'Nghiên cứu', title: 'Tìm nguồn uy tín cho chủ đề'),
      const Text('AI tìm trang web thật (giáo trình mở, bách khoa, trang trường đại học), bạn chọn nguồn để thêm vào tài liệu của sổ.',
          style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 12),
      TextField(
        controller: _topic,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: 'Ví dụ: Định luật Ohm, Quang hợp…',
          prefixIcon: const Icon(Icons.travel_explore),
          suffixIcon: IconButton(tooltip: 'Tìm nguồn', icon: const Icon(Icons.search), onPressed: _loading ? null : _search),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: _loading ? null : _search, icon: const Icon(Icons.search), label: const Text('Tìm nguồn')),
        OutlinedButton.icon(
          onPressed: state.isBusy(c, 'url') ? null : () => addLinkDialog(context, c),
          icon: const Icon(Icons.link),
          label: const Text('Dán liên kết'),
        ),
      ]),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: AiThinking(messages: ['Đang tìm nguồn trên mạng…', 'Đang kiểm tra độ tin cậy…', 'Đang lọc trang liên quan…']),
        ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('${_results.length} kết quả', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final s in _results)
          SourceTile(source: s, selected: _selected.contains(s.url), onChanged: (v) => setState(() => v ? _selected.add(s.url) : _selected.remove(s.url))),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _selected.isEmpty || _adding ? null : _add,
          child: Text(_adding ? 'Đang thêm…' : 'Thêm ${_selected.length} nguồn vào tài liệu'),
        ),
      ],
      const SizedBox(height: 22),
      Row(children: [
        Expanded(child: Text('Nguồn web trong sổ (${web.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        if (web.isNotEmpty)
          TextButton.icon(
              onPressed: () => widget.onNavigate(StudyPage.chat), icon: const Icon(Icons.chat_bubble_outline, size: 18), label: const Text('Hỏi về các nguồn')),
      ]),
      if (web.isEmpty) const Text('Chưa có nguồn web nào.', style: TextStyle(color: AppColors.muted)),
      for (final s in web)
        SourceRow(
          kind: s.kind,
          title: s.title,
          url: s.url,
          trusted: s.trusted,
          subtitle: [s.publisher.isEmpty ? s.domain : s.publisher, if (s.extract.isEmpty) 'Chỉ liên kết'].where((v) => v.isNotEmpty).join(' · '),
          enabled: s.enabled,
          onToggle: (on) => state.setSourceEnabled(c, s, on),
          onRemove: () => state.removeSource(c, s),
        ),
    ]);
  }
}

Future<void> addLinkDialog(BuildContext context, Course course) async {
  final state = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final url = await showDialog<String>(context: context, builder: (_) => const _LinkDialog());
  if (url == null) return;
  try {
    await state.addWebUrl(course, url);
    messenger.showSnackBar(const SnackBar(content: Text('Đã thêm liên kết vào tài liệu.')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Chưa thêm được liên kết.')));
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final url = _input.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => _error = 'Nhập liên kết http hoặc https.');
      return;
    }
    Navigator.pop(context, url);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Thêm liên kết web'),
        content: TextField(
            controller: _input,
            autofocus: true,
            keyboardType: TextInputType.url,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(hintText: 'https://…', errorText: _error)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: _submit, child: const Text('Thêm nguồn')),
        ],
      );
}

// ---------------------------------------------------------------- Tai lieu

const _sourceLabels = {
  'lecture': 'Bài giảng và tham khảo',
  'exam': 'Đề thi gốc',
  'practice': 'Bài luyện',
  'simulation': 'Mô phỏng',
};

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({super.key, required this.course});
  final Course course;
  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  bool _adding = false;
  String? _error;

  Future<void> _add(List<SourceDraft> drafts) async {
    if (_adding) return;
    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await context.read<AppState>().addSources(widget.course, drafts);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa tải lên được. Hãy kiểm tra kết nối rồi thử lại.');
    }
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = widget.course;
    final sources = c.activeSources;
    final groups = {'': 'Tài liệu của sổ', ..._sourceLabels};
    bool inGroup(CourseSource s, String key) => key == '' ? !_sourceLabels.containsKey(s.category) : s.category == key;
    return _PageList(maxWidth: 820, children: [
      const SectionHeader(eyebrow: 'Tài liệu', title: 'Nguồn của sổ học tập'),
      Text(sources.isEmpty ? 'Thêm slide, PDF, ảnh chụp hoặc văn bản. AI chỉ dùng những nguồn đang được tích.'
          : '${c.enabledSources.length}/${sources.length} nguồn đang dùng. AI chỉ dùng những nguồn đang được tích.',
          style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 12),
      SourceAddBar(onAdd: _add, enabled: !_adding),
      OutlinedButton.icon(
          onPressed: state.isBusy(c, 'url') ? null : () => addLinkDialog(context, c), icon: const Icon(Icons.link), label: const Text('Thêm liên kết web')),
      if (_adding || state.isBusy(c, 'url')) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
      const SizedBox(height: 8),
      WebSwitch(value: c.allowWeb, onChanged: (v) => state.setAllowWeb(c, v)),
      if (c.missingCategories.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Chưa tìm thấy ${c.missingCategories.map((k) => _sourceLabels[k]?.toLowerCase() ?? k).join(', ')}.'),
        ),
      for (final g in groups.entries)
        if (sources.any((s) => inGroup(s, g.key))) ...[
          const SizedBox(height: 14),
          Text(g.value, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final s in sources.where((s) => inGroup(s, g.key)))
            SourceRow(
              kind: s.kind,
              title: s.title,
              mimeType: s.mimeType,
              url: s.url,
              subtitle: s.kind == SourceKind.web
                  ? [s.publisher.isEmpty ? s.domain : s.publisher, if (s.extract.isEmpty) 'Chỉ liên kết'].where((v) => v.isNotEmpty).join(' · ')
                  : s.kind == SourceKind.file && state.signedIn && s.storagePath == null
                      ? 'Cần đính kèm lại'
                      : SourceRow.describe(s.kind, mimeType: s.mimeType, text: s.text),
              trusted: s.kind == SourceKind.web ? s.trusted : null,
              enabled: s.enabled,
              onToggle: (on) => state.setSourceEnabled(c, s, on),
              onRemove: () => state.removeSource(c, s),
            ),
        ],
    ]);
  }
}

// ---------------------------------------------------------------- Luyen tap & hoat dong

class PracticePage extends StatelessWidget {
  const PracticePage({super.key, required this.course, required this.page, required this.onNavigate});
  final Course course;
  final StudyPage page;
  final ValueChanged<StudyPage> onNavigate;

  static (String, String) _intro(StudyPage p) => switch (p) {
        StudyPage.quiz => ('Quiz', 'Chọn nguồn, loại câu và độ khó. Trả lời từng câu, xem giải thích ngay và điểm theo chủ đề.'),
        StudyPage.test => ('Thi thử', 'Làm quiz trong thời gian giới hạn như thi thật. Hết giờ sẽ tự nộp bài và chấm điểm.'),
        StudyPage.flashcards => ('Thẻ ghi nhớ', 'Thẻ hai mặt tạo từ tài liệu. Lật thẻ để tự kiểm tra, hoặc chơi Ghép nhanh.'),
        StudyPage.arcade => ('Trò chơi', 'Ôn bài bằng trò chơi ngắn, dùng thẻ ghi nhớ và câu ghép cặp đã có.'),
        StudyPage.explainers => ('Tóm tắt & giải thích', 'Bản tóm tắt ý chính có trích nguồn, và ghi chú bạn lưu từ phần hỏi đáp.'),
        StudyPage.miniApps => ('Mini app', 'Mô tả một mô phỏng, AI viết thành ứng dụng nhỏ chạy ngay. Sửa tiếp bằng lời.'),
        _ => (p.label, ''),
      };

  bool _match(StudyArtifactKind k) => switch (page) {
        StudyPage.quiz || StudyPage.test => k.isQuiz,
        StudyPage.flashcards => k == StudyArtifactKind.flashcards,
        StudyPage.explainers => k == StudyArtifactKind.summary || k == StudyArtifactKind.note,
        StudyPage.miniApps => k == StudyArtifactKind.canvas,
        _ => false,
      };

  List<Widget> _actions(BuildContext context) {
    final c = course;
    return switch (page) {
      StudyPage.quiz => [
          FilledButton.icon(onPressed: () => StudyActions.quizBuilder(context, c), icon: const Icon(Icons.add), label: const Text('Tạo quiz')),
          OutlinedButton.icon(
              onPressed: () => StudyActions.create(context, c, StudyArtifactKind.quickQuiz), icon: const Icon(Icons.bolt), label: const Text('Quiz nhanh')),
        ],
      StudyPage.test => [
          FilledButton.icon(onPressed: () => StudyActions.quizBuilder(context, c), icon: const Icon(Icons.add), label: const Text('Tạo đề thi thử')),
        ],
      StudyPage.flashcards => [
          FilledButton.icon(
              onPressed: () => StudyActions.create(context, c, StudyArtifactKind.flashcards), icon: const Icon(Icons.add), label: const Text('Tạo bộ thẻ')),
          OutlinedButton.icon(
              onPressed: () => onNavigate(StudyPage.arcade), icon: const Icon(Icons.sports_esports_outlined), label: const Text('Chơi Ghép nhanh')),
        ],
      StudyPage.explainers => [
          FilledButton.icon(
              onPressed: () => StudyActions.create(context, c, StudyArtifactKind.summary), icon: const Icon(Icons.add), label: const Text('Tạo bản tóm tắt')),
        ],
      StudyPage.miniApps => [
          FilledButton.icon(onPressed: () => StudyActions.canvas(context, c), icon: const Icon(Icons.auto_awesome), label: const Text('Tạo mini app')),
        ],
      _ => const [],
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final c = course;
    final (title, intro) = _intro(page);
    final items = c.artifacts.reversed.where((a) => _match(a.kind)).toList();
    final busy = state.isBusy(c, 'artifact');
    return _PageList(maxWidth: 820, children: [
      SectionHeader(eyebrow: 'Luyện tập & hoạt động', title: title),
      Text(intro, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 12),
      if (page == StudyPage.arcade)
        ..._arcade(context)
      else ...[
        Wrap(spacing: 8, runSpacing: 8, children: _actions(context)),
        if (busy) const Padding(padding: EdgeInsets.only(top: 12), child: AiThinking(messages: ['AI đang đọc tài liệu…', 'Đang soạn nội dung…'])),
        const SizedBox(height: 16),
        if (items.isEmpty && !busy)
          _Panel(
            color: const Color(0xFFFAFAFA),
            child: Column(children: [
              Icon(page.icon, size: 36, color: AppColors.muted),
              const SizedBox(height: 8),
              Text(page == StudyPage.test ? 'Tạo một quiz rồi làm ở chế độ thi thử có đếm giờ.' : 'Chưa có ${title.toLowerCase()} nào trong sổ này.',
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
        for (final a in items)
          _ArtifactCard(
            course: c,
            artifact: a,
            trailing: page == StudyPage.test
                ? FilledButton.tonal(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuizPlayerScreen(courseId: c.id, artifactId: a.id, exam: true))),
                    child: const Text('Thi thử'),
                  )
                : null,
          ),
      ],
    ]);
  }

  List<Widget> _arcade(BuildContext context) {
    final pairs = MatchGameScreen.pairsFrom(course);
    return [
      _Panel(
        child: Row(children: [
          const CircleAvatar(radius: 24, backgroundColor: AppColors.accent, child: Icon(Icons.extension_outlined, color: AppColors.primary)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ghép nhanh', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(
                pairs.length < 3
                    ? 'Cần ít nhất 3 cặp thuật ngữ. Hãy tạo một bộ thẻ ghi nhớ trước.'
                    : 'Ghép thuật ngữ với nghĩa càng nhanh càng tốt. ${pairs.length} cặp sẵn có.${course.bestMatchMs == null ? '' : ' Kỷ lục: ${(course.bestMatchMs! / 1000).toStringAsFixed(1)} giây.'}',
                style: const TextStyle(color: AppColors.muted),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      if (pairs.length < 3)
        FilledButton.icon(
            onPressed: () => StudyActions.create(context, course, StudyArtifactKind.flashcards),
            icon: const Icon(Icons.style_outlined),
            label: const Text('Tạo bộ thẻ ghi nhớ'))
      else
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MatchGameScreen(courseId: course.id))),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Chơi ngay'),
        ),
    ];
  }
}
