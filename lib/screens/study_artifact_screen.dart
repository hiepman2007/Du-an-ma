import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/blocks/block_renderer.dart';
import '../widgets/study_citation.dart';

class StudyArtifactScreen extends StatefulWidget {
  const StudyArtifactScreen({super.key, required this.courseId, required this.artifactId});

  final String courseId, artifactId;

  @override
  State<StudyArtifactScreen> createState() => _StudyArtifactScreenState();
}

class _StudyArtifactScreenState extends State<StudyArtifactScreen> {
  final _answers = <String, bool>{};
  String _attemptId = const Uuid().v4();
  int _index = 0;
  bool _submitted = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = state.courseById(widget.courseId);
    final artifact = course?.artifacts.where((a) => a.id == widget.artifactId).firstOrNull;
    if (course == null || artifact == null) {
      return const Scaffold(body: Center(child: Text('Nội dung không còn trong sổ.')));
    }
    final questions = [for (var i = 0; i < artifact.blocks.length; i++) if (artifact.blocks[i].isGraded) i];
    final quiz = artifact.kind.isQuiz && questions.isNotEmpty;
    final score = _answers.values.where((answer) => answer).length;
    Widget render(int i) => Column(
      key: ValueKey('$_attemptId-$i'), crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlockRenderer(block: artifact.blocks[i], lesson: Lesson(id: artifact.id, title: artifact.title),
          onAnswered: (correct, _, _) {
            if (quiz && !_submitted) setState(() => _answers.putIfAbsent(artifact.questionKey(i), () => correct));
          }),
        StudyCitation(course: course, block: artifact.blocks[i]),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(artifact.title)),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 780), child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(course.isSample ? 'Bản mẫu' : artifact.kind == StudyArtifactKind.note ? 'Ghi chú đã lưu'
            : '${artifact.webOnly ? 'Từ nguồn web · ' : ''}AI tạo · Phiên bản ${artifact.version}'),
          const SizedBox(height: 12),
          if (quiz) ...[
            LinearProgressIndicator(value: _answers.length / questions.length),
            const SizedBox(height: 10),
            Text('Câu ${_index + 1}/${questions.length} · Đã trả lời ${_answers.length}'),
            render(questions[_index]),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton(onPressed: _index == 0 ? null : () => setState(() => _index--), child: const Text('Câu trước')),
              OutlinedButton(onPressed: _index + 1 == questions.length ? null : () => setState(() => _index++), child: const Text('Câu sau')),
              if (!_submitted)
                FilledButton(onPressed: _saving || _answers.length < questions.length ? null : () async {
                  setState(() => _saving = true);
                  try {
                    await state.recordAttempt(course, artifact, QuizAttempt(id: _attemptId, results: Map.of(_answers), total: questions.length));
                    if (mounted) setState(() => _submitted = true);
                  } catch (_) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa lưu được lượt làm.')));
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                }, child: const Text('Lưu kết quả')),
              if (_submitted) FilledButton.tonal(onPressed: () => setState(() {
                _answers.clear();
                _attemptId = const Uuid().v4();
                _index = 0;
                _submitted = false;
              }), child: const Text('Làm lại')),
            ]),
            if (_submitted) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Kết quả $score/${questions.length}')),
            if (artifact.attempts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Lịch sử làm bài', style: Theme.of(context).textTheme.titleMedium),
              for (final attempt in artifact.attempts.reversed)
                ListTile(dense: true, title: Text('${attempt.score}/${attempt.total} câu đúng'),
                  subtitle: Text(MaterialLocalizations.of(context).formatShortDate(attempt.at.toLocal()))),
            ],
          ] else
            for (var i = 0; i < artifact.blocks.length; i++) render(i),
        ],
      ))),
    );
  }
}
