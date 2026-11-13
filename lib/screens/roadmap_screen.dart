import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/api_client.dart';
import '../widgets/source_widgets.dart';
import 'lesson_screen.dart';

/// Lo trinh khoa hoc: danh sach bai, keo de doi thu tu, sua ten, xoa bai.
class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key, required this.courseId});
  final String courseId;

  Future<void> _rename(BuildContext context, Lesson l) async {
    final ctrl = TextEditingController(text: l.title);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Đổi tên bài'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Lưu')),
        ],
      ),
    );
    if (v != null && v.isNotEmpty && context.mounted) await context.read<AppState>().renameLesson(l, v);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.courseById(courseId);
    if (c == null) return const Scaffold(body: Center(child: Text('Khóa học đã bị xóa')));
    final total = c.lessons.length;
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
                  content: const Text('Khóa học và tiến độ sẽ bị xóa khỏi máy.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Hủy')),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Xóa')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.pop(context);
                await context.read<AppState>().deleteCourse(c);
              }
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Eyebrow(c.sourceLabel),
        const SizedBox(height: 4),
        Text(c.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Mục tiêu: ${c.goal}', style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: total == 0 ? 0 : c.doneLessons / total, minHeight: 8, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 6),
        Text('Hoàn thành ${c.doneLessons}/$total bài', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 14),
        _SourcesPanel(course: c),
        const SizedBox(height: 18),
        const SectionHeader(eyebrow: 'Lộ trình do AI đề xuất', title: 'Các bài học'),
        const Text('Giữ và kéo để đổi thứ tự, chạm ⋮ để sửa hoặc xóa bài.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 8),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (o, n) => context.read<AppState>().reorderLesson(c, o, n),
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
      ]),
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
            ? 'Đã xong · đúng ${lesson.correctCount}/${lesson.gradedCount}'
            : lesson.gradedCount == 0
                ? 'Bài tương tác · ~${lesson.minutes} phút'
                : 'Đang học · ${lesson.results.length}/${lesson.gradedCount} câu';
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
