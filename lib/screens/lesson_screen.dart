import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/blocks/block_renderer.dart';
import 'tutor_sheet.dart';

/// Bai hoc: chuoi khoi do AI chon (bai giang, bai tap, mo phong...). Sinh lan dau khi mo bai.
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.courseId, required this.lessonId});
  final String courseId, lessonId;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _loading = false;
  String? _error;
  bool _exploring = false;

  Course? get _course => context.read<AppState>().courseById(widget.courseId);
  Lesson? _lesson(Course? c) {
    for (final l in c?.lessons ?? <Lesson>[]) {
      if (l.id == widget.lessonId) return l;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final l = _lesson(_course);
      if (l != null && l.blocks == null) _generate();
    });
  }

  Future<void> _generate() async {
    final c = _course, l = _lesson(c);
    if (c == null || l == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().generateLesson(c, l);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Có lỗi xảy ra: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _explore(Lesson l) async {
    final ctrl = TextEditingController(text: l.title);
    final concept = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(eyebrow: 'Chế độ tương tác sâu', title: 'Khám phá thêm'),
          const Text('AI sẽ tạo mô phỏng, đồ thị hoặc trò chơi ghép/sắp xếp cho khái niệm bạn muốn hiểu sâu hơn.'),
          const SizedBox(height: 12),
          TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Khái niệm')),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Tạo phần tương tác')),
          ),
        ]),
      ),
    );
    if (concept == null || concept.isEmpty || !mounted) return;
    final c = _course;
    if (c == null) return;
    setState(() => _exploring = true);
    try {
      final n = await context.read<AppState>().addInteractive(c, l, concept);
      _snack('Đã thêm $n phần tương tác ở cuối bài');
    } on ApiException catch (e) {
      _snack(e.message);
    }
    if (mounted) setState(() => _exploring = false);
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.courseById(widget.courseId);
    final l = _lesson(c);
    if (c == null || l == null) return const Scaffold(body: Center(child: Text('Bài học không còn tồn tại')));
    final blocks = l.blocks;

    Widget body;
    if (_loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5)),
            SizedBox(height: 20),
            Eyebrow('AI đang soạn bài'),
            SizedBox(height: 6),
            Text('Chọn bài giảng, bài tập và mô phỏng phù hợp…', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            SizedBox(height: 6),
            Text('Thường mất 15–40 giây', style: TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
    } else if (_error != null && blocks == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _generate, child: const Text('Thử lại')),
          ]),
        ),
      );
    } else if (blocks == null) {
      body = Center(child: FilledButton(onPressed: _generate, child: const Text('Tạo bài học')));
    } else {
      final graded = l.gradedCount;
      body = ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
        Text(l.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (graded > 0) ...[
          LinearProgressIndicator(value: l.results.length / graded, minHeight: 6, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 4),
          Text('Đã làm ${l.results.length}/$graded câu · đúng ${l.correctCount}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < blocks.length; i++)
          BlockRenderer(
            key: ValueKey('${l.id}-$i'),
            block: blocks[i],
            lesson: l,
            onAnswered: (ok, chosen, correct) => s.recordResult(l, i, ok),
            onTutor: (chosen, correct) => showTutorSheet(context, blocks[i], chosen, correct),
          ),
        if (l.isDone) _ResultCard(lesson: l),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          if (blocks != null && !_loading)
            IconButton(tooltip: 'Tạo lại bài', icon: const Icon(Icons.refresh), onPressed: _generate),
        ],
      ),
      body: body,
      floatingActionButton: blocks == null || _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _exploring ? null : () => _explore(l),
              icon: _exploring
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.science_outlined),
              label: Text(_exploring ? 'Đang tạo…' : 'Khám phá thêm'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.lesson});
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final blocks = lesson.blocks ?? [];
    final weak = <String>{
      for (final e in lesson.results.entries)
        if (!e.value && e.key < blocks.length && blocks[e.key].topic.isNotEmpty) blocks[e.key].topic,
    };
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(appRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Kết quả bài học', color: Color(0xFFFFD6DA)),
        const SizedBox(height: 4),
        Text('Đúng ${lesson.correctCount}/${lesson.gradedCount} câu',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          weak.isEmpty ? 'Tuyệt vời! Bạn đã nắm chắc bài này.' : 'Cần ôn lại: ${weak.join(', ')}',
          style: const TextStyle(color: Colors.white),
        ),
      ]),
    );
  }
}
