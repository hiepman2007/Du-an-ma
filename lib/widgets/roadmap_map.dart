import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../theme.dart';

enum LessonStatus { locked, available, inProgress, done }

extension LessonStatusView on LessonStatus {
  String get label => switch (this) {
        LessonStatus.locked => 'Chưa mở khóa',
        LessonStatus.available => 'Có thể học',
        LessonStatus.inProgress => 'Đang học',
        LessonStatus.done => 'Đã xong',
      };

  IconData get icon => switch (this) {
        LessonStatus.locked => Icons.lock_outline,
        LessonStatus.available => Icons.radio_button_unchecked,
        LessonStatus.inProgress => Icons.play_circle,
        LessonStatus.done => Icons.check_circle,
      };

  Color get color => switch (this) {
        LessonStatus.locked => AppColors.muted,
        LessonStatus.available => AppColors.foreground,
        LessonStatus.inProgress => AppColors.primary,
        LessonStatus.done => AppColors.success,
      };
}

/// Tỉ lệ đúng gộp từ câu kiểm tra trong bài (lần đầu) và lần làm quiz gần nhất của bài;
/// null khi chưa đủ 2 câu để đánh giá.
double? lessonMastery(Lesson lesson) {
  final answered = lesson.results.length + lesson.quizTotal;
  return answered < 2 ? null : (lesson.correctCount + lesson.quizCorrect) / answered;
}

bool needsReview(Lesson lesson) => (lessonMastery(lesson) ?? 1) < 0.6;

bool isMastered(Lesson lesson) => (lessonMastery(lesson) ?? 0) >= 0.8;

/// Quan hệ học trước giữa các bài. Khi AI không ghi bài nào cần học trước,
/// lộ trình được coi là một đường thẳng theo thứ tự bài.
class RoadmapGraph {
  RoadmapGraph(this.lessons) {
    final order = {for (var i = 0; i < lessons.length; i++) lessons[i].id: i};
    final explicit = [
      for (var i = 0; i < lessons.length; i++)
        [for (final id in lessons[i].prerequisites) if ((order[id] ?? i) < i) id],
    ];
    final linear = explicit.every((ids) => ids.isEmpty);
    for (var i = 0; i < lessons.length; i++) {
      _prerequisites[lessons[i].id] = linear ? [if (i > 0) lessons[i - 1].id] : explicit[i];
    }
  }

  final List<Lesson> lessons;
  final _prerequisites = <String, List<String>>{};

  List<String> prerequisitesOf(Lesson lesson) => _prerequisites[lesson.id] ?? const [];

  Lesson? byId(String id) => lessons.where((lesson) => lesson.id == id).firstOrNull;

  List<Lesson> missingPrerequisites(Lesson lesson) => [
        for (final id in prerequisitesOf(lesson))
          if (byId(id) case final Lesson before when !before.completed) before,
      ];

  LessonStatus statusOf(Lesson lesson) {
    if (lesson.completed) return LessonStatus.done;
    if (lesson.lastStudiedAt != null) return LessonStatus.inProgress;
    return missingPrerequisites(lesson).isEmpty ? LessonStatus.available : LessonStatus.locked;
  }

  /// Bài nên học tiếp: bài đang học gần nhất, rồi bài đầu tiên đã mở khóa.
  Lesson? next() {
    Lesson? recent;
    for (final lesson in lessons) {
      if (statusOf(lesson) != LessonStatus.inProgress) continue;
      if (recent == null || lesson.lastStudiedAt!.isAfter(recent.lastStudiedAt!)) recent = lesson;
    }
    return recent ??
        lessons.where((lesson) => statusOf(lesson) == LessonStatus.available).firstOrNull ??
        lessons.where((lesson) => !lesson.completed).firstOrNull;
  }
}

class RoadmapPhase {
  RoadmapPhase(this.name);
  final String name;
  final lessons = <Lesson>[];
}

/// Gom các bài liền nhau cùng chặng; bài không có tên chặng được gom 3 bài một chặng.
List<RoadmapPhase> roadmapPhases(List<Lesson> lessons) {
  final phases = <RoadmapPhase>[];
  for (final lesson in lessons) {
    final name = lesson.phase.trim();
    if (phases.isEmpty || phases.last.name != name || (name.isEmpty && phases.last.lessons.length == 3)) {
      phases.add(RoadmapPhase(name));
    }
    phases.last.lessons.add(lesson);
  }
  return phases;
}

/// Vị trí các ô bài học: mỗi chặng chia thành nhiều hàng theo độ sâu học trước,
/// các bài không phụ thuộc nhau đứng cùng hàng.
class RoadmapLayout {
  static const nodeWidth = 156.0;
  static const nodeHeight = 100.0;
  static const gapX = 12.0;
  static const gapY = 40.0;
  static const headerHeight = 36.0;
  static const phaseGap = 28.0;

  RoadmapLayout(RoadmapGraph graph, List<RoadmapPhase> phases, double minWidth) {
    final phaseRows = <List<List<Lesson>>>[];
    var widest = 1;
    for (final phase in phases) {
      final inPhase = {for (final lesson in phase.lessons) lesson.id};
      final depth = <String, int>{};
      for (final lesson in phase.lessons) {
        final parents = graph.prerequisitesOf(lesson).where(inPhase.contains).map((id) => depth[id] ?? 0);
        depth[lesson.id] = parents.isEmpty ? 0 : parents.reduce(math.max) + 1;
      }
      final rows = <List<Lesson>>[];
      for (final lesson in phase.lessons) {
        final row = depth[lesson.id]!;
        while (rows.length <= row) {
          rows.add([]);
        }
        rows[row].add(lesson);
      }
      for (final row in rows) {
        widest = math.max(widest, row.length);
      }
      phaseRows.add(rows);
    }

    final width = math.max(minWidth, widest * nodeWidth + (widest - 1) * gapX);
    var y = 0.0;
    for (var p = 0; p < phases.length; p++) {
      if (p > 0) y += phaseGap;
      headers.add(y);
      y += headerHeight;
      final rows = phaseRows[p];
      for (var r = 0; r < rows.length; r++) {
        if (r > 0) y += gapY;
        final row = rows[r];
        final rowWidth = row.length * nodeWidth + (row.length - 1) * gapX;
        var x = (width - rowWidth) / 2;
        for (final lesson in row) {
          nodes[lesson.id] = Rect.fromLTWH(x, y, nodeWidth, nodeHeight);
          x += nodeWidth + gapX;
        }
        y += nodeHeight;
      }
    }
    size = Size(width, y);
  }

  /// Toạ độ y của tiêu đề từng chặng.
  final headers = <double>[];
  final nodes = <String, Rect>{};
  late final Size size;
}

class RoadmapMap extends StatelessWidget {
  const RoadmapMap({super.key, required this.graph, required this.next, required this.onTap});

  final RoadmapGraph graph;
  final Lesson? next;
  final ValueChanged<Lesson> onTap;

  @override
  Widget build(BuildContext context) {
    final phases = roadmapPhases(graph.lessons);
    return LayoutBuilder(builder: (context, constraints) {
      final layout = RoadmapLayout(graph, phases, constraints.maxWidth);
      final edges = [
        for (final lesson in graph.lessons)
          for (final id in graph.prerequisitesOf(lesson))
            if (layout.nodes[id] case final Rect from)
              (from, layout.nodes[lesson.id]!, graph.byId(id)!.completed),
      ];
      final map = SizedBox.fromSize(
        size: layout.size,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _EdgePainter(edges))),
          for (var p = 0; p < phases.length; p++)
            Positioned(
              left: 0,
              right: 0,
              top: layout.headers[p],
              height: RoadmapLayout.headerHeight,
              child: _PhaseHeader(index: p, phase: phases[p]),
            ),
          for (final lesson in graph.lessons)
            Positioned.fromRect(
              rect: layout.nodes[lesson.id]!,
              child: _LessonNode(
                lesson: lesson,
                status: graph.statusOf(lesson),
                isNext: lesson == next,
                onTap: () => onTap(lesson),
              ),
            ),
        ]),
      );
      if (layout.size.width <= constraints.maxWidth) return map;
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: map);
    });
  }
}

class RoadmapLegend extends StatelessWidget {
  const RoadmapLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final status in LessonStatus.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(status.icon, size: 14, color: status.color),
              const SizedBox(width: 4),
              Text(status.label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
        ],
      );
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.index, required this.phase});
  final int index;
  final RoadmapPhase phase;

  @override
  Widget build(BuildContext context) {
    final done = phase.lessons.where((lesson) => lesson.completed).length;
    final allDone = done == phase.lessons.length;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: allDone ? AppColors.success : AppColors.ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('CHẶNG ${index + 1}  ',
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          Text(phase.name.isEmpty ? 'Phần ${index + 1}' : phase.name,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          Text('  ·  $done/${phase.lessons.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      ),
    );
  }
}

class _LessonNode extends StatelessWidget {
  const _LessonNode({required this.lesson, required this.status, required this.isNext, required this.onTap});

  final Lesson lesson;
  final LessonStatus status;
  final bool isNext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mastery = lessonMastery(lesson);
    final (background, border) = switch (status) {
      LessonStatus.done => (const Color(0xFFEAF5ED), AppColors.success),
      LessonStatus.inProgress => (AppColors.accent, AppColors.primary),
      LessonStatus.available => (Colors.white, AppColors.border),
      LessonStatus.locked => (const Color(0xFFF0F0F0), AppColors.border),
    };
    final footer = mastery != null
        ? (needsReview(lesson) ? 'Nên ôn lại · ${(mastery * 100).round()}%' : 'Nắm vững ${(mastery * 100).round()}%')
        : lesson.scheduledAt != null && !lesson.completed
            ? 'Lịch ${lesson.scheduledAt!.day}/${lesson.scheduledAt!.month}'
            : '';
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.1,
      child: Semantics(
        button: true,
        label: '${lesson.title}, ${status.label}',
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isNext ? AppColors.primary : border, width: isNext ? 2 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(status.icon, size: 15, color: status.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(isNext && status != LessonStatus.inProgress ? 'Học tiếp' : status.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: status.color)),
                  ),
                  Text('${lesson.minutes} phút', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(lesson.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: status == LessonStatus.locked ? AppColors.muted : AppColors.foreground,
                      )),
                ),
                if (footer.isNotEmpty)
                  Text(footer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: needsReview(lesson) ? AppColors.danger : AppColors.muted,
                      )),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.edges);
  final List<(Rect, Rect, bool)> edges;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (from, to, done) in edges) {
      final paint = Paint()
        ..color = done ? AppColors.success : AppColors.border
        ..strokeWidth = done ? 2 : 1.6
        ..style = PaintingStyle.stroke;
      final start = from.bottomCenter;
      final end = to.topCenter.translate(0, -3);
      final bend = (end.dy - start.dy) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(start.dx, start.dy + bend, end.dx, end.dy - bend, end.dx, end.dy),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(end.dx - 5, end.dy - 6)
          ..lineTo(end.dx, end.dy + 1)
          ..lineTo(end.dx + 5, end.dy - 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => true;
}
