import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'quiz_player_screen.dart';

/// Ten, mo ta va bieu tuong cua tung loai cau hoi trong man tao quiz.
const quizTypeInfo = <String, (String, String, IconData)>{
  'mcq': ('Trắc nghiệm', 'Chọn 1 trong 4 đáp án', Icons.quiz_outlined),
  'true_false': ('Đúng / Sai', 'Nhận định đúng hay sai', Icons.rule),
  'fill_blank': ('Điền khuyết', 'Điền từ còn thiếu', Icons.short_text),
  'matching': ('Ghép cặp', 'Nối khái niệm với ý nghĩa', Icons.compare_arrows),
  'ordering': ('Sắp xếp', 'Xếp các bước theo đúng thứ tự', Icons.format_list_numbered),
  'passage': ('Đoạn văn 3 tầng', 'Tình huống + 3 câu: nhận biết → cơ chế → vận dụng', Icons.layers_outlined),
};

/// Tao quiz 3 buoc: pham vi → so cau theo loai → do kho va kieu giai thich.
class QuizBuilderScreen extends StatefulWidget {
  const QuizBuilderScreen({super.key, required this.courseId, this.lessonId});

  final String courseId;
  final String? lessonId;

  @override
  State<QuizBuilderScreen> createState() => _QuizBuilderScreenState();
}

class _QuizBuilderScreenState extends State<QuizBuilderScreen> {
  static const _steps = ['Phạm vi', 'Loại câu hỏi', 'Độ khó'];
  int _step = 0;
  late QuizSpec _spec = QuizSpec(counts: const {'mcq': 5, 'true_false': 2, 'matching': 1}, lessonId: widget.lessonId);
  final _focus = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _setCount(String type, int value) {
    setState(() => _spec = _spec.copyWith(counts: {..._spec.counts, type: value}..removeWhere((_, n) => n <= 0)));
  }

  Future<void> _create(AppState state, Course course) async {
    setState(() => _error = null);
    try {
      final quiz = await state.createQuiz(course, _spec.copyWith(focus: _focus.text.trim()));
      if (quiz != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => QuizPlayerScreen(courseId: course.id, artifactId: quiz.id)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = state.courseById(widget.courseId);
    if (course == null) return const Scaffold(body: Center(child: Text('Sổ học tập không còn.')));
    final busy = state.isBusy(course, 'quiz');
    final sources = course.enabledSources.length;
    final canNext = switch (_step) {
      0 => sources > 0,
      1 => _spec.total > 0,
      _ => _spec.total > 0 && !busy,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo quiz')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: busy
                ? _Generating(total: _spec.total, sources: sources)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text('Bước ${_step + 1}/3 · ${_steps[_step]}',
                          style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: LinearProgressIndicator(value: (_step + 1) / 3, borderRadius: BorderRadius.circular(3)),
                    ),
                    Expanded(
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        if (_error != null) _ErrorBox(message: _error!, onRetry: () => _create(state, course)),
                        ...switch (_step) {
                          0 => _scope(course, sources),
                          1 => _types(),
                          _ => _options(course),
                        },
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(children: [
                        if (_step > 0) ...[
                          OutlinedButton(onPressed: () => setState(() => _step--), child: const Text('Quay lại')),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton(
                            onPressed: !canNext
                                ? null
                                : _step < 2
                                    ? () => setState(() => _step++)
                                    : () => _create(state, course),
                            child: Text(_step < 2 ? 'Tiếp' : 'Tạo quiz · ${_spec.total} câu'),
                          ),
                        ),
                      ]),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _scope(Course course, int sources) => [
        Text('Quiz dựa trên đâu?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(sources > 0 ? Icons.folder_open : Icons.warning_amber, color: sources > 0 ? AppColors.primary : AppColors.danger),
            title: Text(sources > 0 ? '$sources nguồn đang bật' : 'Chưa có nguồn nào được bật'),
            subtitle: Text(sources > 0
                ? 'AI chỉ soạn câu hỏi từ các nguồn này. Bật/tắt nguồn ở tab Nguồn.'
                : 'Hãy thêm tài liệu hoặc bật nguồn ở tab Nguồn rồi quay lại.'),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Phạm vi', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ChoiceChip(
            label: const Text('Cả sổ học'),
            selected: _spec.lessonId == null,
            onSelected: (_) => setState(() => _spec = _spec.copyWith(clearLesson: true)),
          ),
          for (final lesson in course.lessons)
            ChoiceChip(
              label: Text(lesson.title),
              selected: _spec.lessonId == lesson.id,
              onSelected: (_) => setState(() => _spec = _spec.copyWith(lessonId: lesson.id)),
            ),
        ]),
        if (_spec.lessonId != null)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Điểm quiz sẽ được tính vào mức nắm vững của bài này trên lộ trình.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
      ];

  List<Widget> _types() {
    final total = _spec.total;
    return [
      Text('Bao nhiêu câu mỗi loại?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('Tổng: $total/${QuizSpec.maxQuestions} câu', style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 12),
      for (final type in QuizSpec.types)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(children: [
              Icon(quizTypeInfo[type]!.$3, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(quizTypeInfo[type]!.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(quizTypeInfo[type]!.$2, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              IconButton(
                tooltip: 'Bớt ${quizTypeInfo[type]!.$1}',
                onPressed: (_spec.counts[type] ?? 0) == 0 ? null : () => _setCount(type, (_spec.counts[type] ?? 0) - 1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: 24,
                child: Text('${_spec.counts[type] ?? 0}', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: 'Thêm ${quizTypeInfo[type]!.$1}',
                onPressed: total + (type == 'passage' ? 3 : 1) > QuizSpec.maxQuestions
                    ? null
                    : () => _setCount(type, (_spec.counts[type] ?? 0) + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ]),
          ),
        ),
    ];
  }

  List<Widget> _options(Course course) {
    final lesson = course.lessons.where((l) => l.id == _spec.lessonId).firstOrNull;
    return [
      Text('Độ khó và cách giải thích', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      const Text('Độ khó', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'easy', label: Text('Dễ')),
          ButtonSegment(value: 'medium', label: Text('Vừa')),
          ButtonSegment(value: 'hard', label: Text('Khó')),
        ],
        selected: {_spec.difficulty},
        onSelectionChanged: (v) => setState(() => _spec = _spec.copyWith(difficulty: v.first)),
      ),
      const SizedBox(height: 16),
      const Text('Giải thích đáp án', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'brief', label: Text('Ngắn gọn')),
          ButtonSegment(value: 'detailed', label: Text('Chi tiết, có ví dụ')),
        ],
        selected: {_spec.explain},
        onSelectionChanged: (v) => setState(() => _spec = _spec.copyWith(explain: v.first)),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _focus,
        decoration: const InputDecoration(
          labelText: 'Chủ đề trọng tâm (không bắt buộc)',
          hintText: 'Ví dụ: độ phức tạp thời gian',
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text([
            '${_spec.total} câu',
            lesson == null ? 'cả sổ học' : 'bài "${lesson.title}"',
            for (final e in _spec.counts.entries) '${e.value} ${quizTypeInfo[e.key]!.$1.toLowerCase()}',
          ].join(' · ')),
        ),
      ),
    ];
  }
}

class _Generating extends StatelessWidget {
  const _Generating({required this.total, required this.sources});
  final int total, sources;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text('AI đang soạn $total câu từ $sources nguồn…',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Thường mất 10–30 giây.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 24),
          for (final width in [1.0, 0.85, 0.7])
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 14,
              width: 280 * width,
              decoration: BoxDecoration(color: AppColors.border.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(7)),
            ),
        ]),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.primaryDark))),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}
