import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/blocks/block_renderer.dart';
import '../widgets/study_citation.dart';
import 'tutor_chat_screen.dart';

/// Lam quiz: mot cau moi man, tra loi xong hien giai thich ngay, cuoi bai co diem theo chu de.
/// [only] = chi lam lai cac cau nay (luot luyen lai cau sai, khong ghi vao lich su diem).
class QuizPlayerScreen extends StatefulWidget {
  const QuizPlayerScreen({super.key, required this.courseId, required this.artifactId, this.only});

  final String courseId, artifactId;
  final List<int>? only;

  @override
  State<QuizPlayerScreen> createState() => _QuizPlayerScreenState();
}

class _QuizPlayerScreenState extends State<QuizPlayerScreen> {
  final _answers = <int, bool>{};
  String _attemptId = const Uuid().v4();
  int _index = 0;
  bool _finished = false;

  /// Doan tinh huong ap dung cho cau [i]: khoi text_section gan nhat dung truoc cau do.
  int? _passageFor(List<Block> blocks, int i) {
    for (var j = i - 1; j >= 0; j--) {
      if (blocks[j].type == BlockType.textSection) return j;
    }
    return null;
  }

  Future<void> _finish(AppState state, Course course, StudyArtifact artifact, List<int> questions) async {
    setState(() => _finished = true);
    if (widget.only != null) return;
    try {
      await state.recordAttempt(course, artifact, QuizAttempt(id: _attemptId,
          results: {for (final e in _answers.entries) artifact.questionKey(e.key): e.value}, total: questions.length));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa lưu được kết quả lượt làm này.')));
      }
    }
  }

  void _restart() => setState(() {
        _answers.clear();
        _attemptId = const Uuid().v4();
        _index = 0;
        _finished = false;
      });

  void _askTutor(Course course, Lesson lesson, Block block, {String? chosen, String? correct}) {
    final question = (block.body ?? block.title ?? '').trim();
    Navigator.push(context, MaterialPageRoute(builder: (_) => TutorChatScreen(
      courseId: course.id, lessonId: lesson.id,
      draftQuestion: chosen == null
          ? 'Giải thích giúp mình câu này: "$question"'
          : 'Câu "$question": mình chọn "$chosen" nhưng đáp án là "$correct". Vì sao vậy?',
    )));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = state.courseById(widget.courseId);
    final artifact = course?.artifacts.where((a) => a.id == widget.artifactId).firstOrNull;
    if (course == null || artifact == null) {
      return const Scaffold(body: Center(child: Text('Quiz không còn trong sổ.')));
    }
    final blocks = artifact.blocks;
    final questions = [
      for (var i = 0; i < blocks.length; i++)
        if (blocks[i].isGraded && (widget.only?.contains(i) ?? true)) i,
    ];
    final lesson = artifact.lessonId == null ? null : course.lessons.where((l) => l.id == artifact.lessonId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(widget.only == null ? artifact.title : 'Làm lại câu sai')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: questions.isEmpty
                ? const Center(child: Text('Quiz này chưa có câu hỏi.'))
                : _finished
                    ? _results(course, artifact, questions, lesson)
                    : _question(state, course, artifact, questions, lesson),
          ),
        ),
      ),
    );
  }

  Widget _question(AppState state, Course course, StudyArtifact artifact, List<int> questions, Lesson? lesson) {
    final i = questions[_index];
    final block = artifact.blocks[i];
    final passage = _passageFor(artifact.blocks, i);
    final answered = _answers.containsKey(i);
    final last = _index + 1 == questions.length;
    final list = ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Text('Câu ${_index + 1}/${questions.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        Text('Đúng ${_answers.values.where((v) => v).length}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: (_index + (answered ? 1 : 0)) / questions.length, minHeight: 6, borderRadius: BorderRadius.circular(3)),
      const SizedBox(height: 16),
      if (passage != null) ...[
        const Text('TÌNH HUỐNG', style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.muted)),
        BlockRenderer(block: artifact.blocks[passage], lesson: Lesson(id: artifact.id, title: artifact.title), onAnswered: (_, _, _) {}),
      ],
      BlockRenderer(
        key: ValueKey('$_attemptId-$i'),
        block: block,
        lesson: lesson ?? Lesson(id: artifact.id, title: artifact.title),
        onAnswered: (correct, _, _) => setState(() => _answers.putIfAbsent(i, () => correct)),
        onTutor: lesson == null ? null : (chosen, correct) => _askTutor(course, lesson, block, chosen: chosen, correct: correct),
      ),
      StudyCitation(course: course, block: block),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: list),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: answered
            ? FilledButton.icon(
                onPressed: last ? () => _finish(state, course, artifact, questions) : () => setState(() => _index++),
                icon: Icon(last ? Icons.flag_outlined : Icons.arrow_forward),
                label: Text(last ? 'Xem kết quả' : 'Câu tiếp'),
              )
            : const Text('Trả lời để xem giải thích và sang câu tiếp.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      ),
    ]);
  }

  Widget _results(Course course, StudyArtifact artifact, List<int> questions, Lesson? lesson) {
    final score = _answers.values.where((v) => v).length;
    final percent = (score * 100 / questions.length).round();
    final wrong = [for (final i in questions) if (_answers[i] == false) i];
    final topics = <String, (int, int)>{};
    for (final i in questions) {
      final topic = artifact.blocks[i].topic.trim().isEmpty ? 'Chung' : artifact.blocks[i].topic.trim();
      final (correct, total) = topics[topic] ?? (0, 0);
      topics[topic] = (correct + (_answers[i] == true ? 1 : 0), total + 1);
    }
    final color = percent >= 80 ? AppColors.success : percent >= 60 ? AppColors.foreground : AppColors.danger;
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SizedBox(height: 8),
      Center(
        child: SizedBox(
          width: 120,
          height: 120,
          child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(value: score / questions.length, strokeWidth: 10, color: color,
                backgroundColor: AppColors.border.withValues(alpha: 0.5)),
            Center(child: Text('$score/${questions.length}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color))),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        percent >= 80 ? 'Rất tốt! Bạn đã nắm vững phần này.' : percent >= 60 ? 'Khá ổn, ôn lại vài chỗ là chắc.' : 'Cần ôn lại: xem giải thích các câu sai bên dưới.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      if (widget.only == null && lesson != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Đã cập nhật mức nắm vững của bài "${lesson.title}".',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
      const SizedBox(height: 20),
      Text('Theo chủ đề', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      for (final MapEntry(key: topic, value: (correct, total)) in topics.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(topic)),
              Text('$correct/$total', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: correct / total,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: correct / total >= 0.8 ? AppColors.success : correct / total >= 0.6 ? AppColors.primary : AppColors.danger,
            ),
          ]),
        ),
      if (wrong.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('Câu trả lời sai', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        for (final i in wrong)
          Card(
            child: ListTile(
              leading: const Icon(Icons.close, color: AppColors.danger),
              title: Text((artifact.blocks[i].body ?? artifact.blocks[i].title ?? 'Câu ${questions.indexOf(i) + 1}').trim(),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: (artifact.blocks[i].explanation ?? '').isEmpty
                  ? null
                  : Text(artifact.blocks[i].explanation!, maxLines: 3, overflow: TextOverflow.ellipsis),
              trailing: lesson == null ? null : IconButton(
                tooltip: 'Hỏi gia sư về câu này',
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => _askTutor(course, lesson, artifact.blocks[i]),
              ),
            ),
          ),
      ],
      const SizedBox(height: 16),
      if (wrong.isNotEmpty)
        FilledButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => QuizPlayerScreen(courseId: course.id, artifactId: artifact.id, only: wrong))),
          icon: const Icon(Icons.replay),
          label: Text('Làm lại ${wrong.length} câu sai'),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: _restart, icon: const Icon(Icons.restart_alt), label: const Text('Làm lại cả bài')),
      const SizedBox(height: 8),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
      if (widget.only == null && artifact.attempts.length > 1) ...[
        const SizedBox(height: 16),
        Text('Lịch sử làm bài', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        for (final attempt in artifact.attempts.reversed)
          ListTile(
            dense: true,
            leading: const Icon(Icons.history),
            title: Text('${attempt.score}/${attempt.total} câu đúng'),
            subtitle: Text(MaterialLocalizations.of(context).formatShortDate(attempt.at.toLocal())),
          ),
      ],
    ]);
  }
}
