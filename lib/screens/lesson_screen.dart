import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/blocks/block_renderer.dart';
import '../widgets/motion.dart';
import '../widgets/study_citation.dart';
import 'tutor_chat_screen.dart';
import 'tutor_sheet.dart';

/// Bai hoc: chuoi khoi do AI chon (bai giang, bai tap, mo phong...). Sinh lan dau khi mo bai.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });
  final String courseId, lessonId;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _loading = false;
  String? _error;
  bool _exploring = false;
  final _contentScroll = ScrollController();

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
      if (!mounted) return;
      final l = _lesson(_course);
      if (l == null) return;
      if (l.blocks == null) {
        _generate();
      } else if (!l.isDone) {
        _changeStep(l, l.stepIndex);
      }
    });
  }

  @override
  void dispose() {
    _contentScroll.dispose();
    super.dispose();
  }

  Future<void> _changeStep(Lesson lesson, int index) async {
    if (_contentScroll.hasClients) _contentScroll.jumpTo(0);
    try {
      await context.read<AppState>().setLessonStep(lesson, index);
    } catch (_) {
      _snack('Chưa lưu được vị trí học. Hãy thử lại.');
    }
  }

  Future<void> _toggleCompleted(Lesson lesson) async {
    try {
      await context.read<AppState>().setLessonCompleted(lesson, !lesson.isDone);
    } catch (_) {
      _snack('Chưa lưu được trạng thái hoàn thành. Hãy thử lại.');
    }
  }

  Future<void> _generate() async {
    final c = _course, l = _lesson(c);
    if (c == null || l == null || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().generateLesson(c, l);
      if (mounted && l.blocks?.isNotEmpty == true) {
        await _changeStep(l, l.stepIndex);
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Chưa tạo được bài học. Hãy thử lại.';
    }
    if (mounted) {
      setState(() => _loading = false);
      if (_error != null && l.blocks != null) _snack(_error!);
    }
  }

  Future<void> _explore(Lesson l) async {
    var query = l.title;
    final concept = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(c).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              eyebrow: 'Chế độ tương tác sâu',
              title: 'Khám phá thêm',
            ),
            const Text(
              'AI sẽ tạo mô phỏng, đồ thị hoặc trò chơi ghép/sắp xếp cho khái niệm bạn muốn hiểu sâu hơn.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: query,
              onChanged: (text) => query = text,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Khái niệm'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(c, query.trim()),
                child: const Text('Tạo phần tương tác'),
              ),
            ),
          ],
        ),
      ),
    );
    if (concept == null || concept.isEmpty || !mounted) return;
    final c = _course;
    if (c == null) return;
    setState(() => _exploring = true);
    try {
      final firstAdded = l.blocks?.length ?? 0;
      final n = await context.read<AppState>().addInteractive(c, l, concept);
      if (mounted && n > 0) await _changeStep(l, firstAdded);
      _snack(
        n > 0
            ? 'Đã thêm $n phần tương tác ở cuối bài'
            : 'Chưa tạo được mô phỏng phù hợp.',
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Chưa thêm được phần tương tác.');
    }
    if (mounted) setState(() => _exploring = false);
  }

  bool _practicing = false;
  String _difficulty = 'medium';

  /// Bo de luyen: sinh them 5 cau tu cung tai lieu theo do kho.
  Future<void> _practice(Course c, Lesson l) async {
    setState(() => _practicing = true);
    try {
      final firstAdded = l.blocks?.length ?? 0;
      final n = await context.read<AppState>().addExercises(c, l, _difficulty);
      if (mounted && n > 0) await _changeStep(l, firstAdded);
      _snack(
        n > 0
            ? 'Đã thêm $n câu luyện tập ở cuối bài'
            : 'Chưa tạo được câu luyện tập.',
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Chưa thêm được câu luyện tập.');
    }
    if (mounted) setState(() => _practicing = false);
  }

  void _openChat(
    Course c,
    Lesson l, {
    String? question,
    Block? step,
    int? index,
  }) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TutorChatScreen(
        courseId: c.id,
        lessonId: l.id,
        initialQuestion: question,
        draftQuestion: step == null ? null : _stepQuestion(step, index!),
      ),
    ),
  );

  String _stepQuestion(Block step, int index) {
    final description = step.title?.trim() ?? '';
    final body = step.body?.trim() ?? '';
    final context = [
      if (description.isNotEmpty) description,
      if (body.isNotEmpty) body,
    ].join('\n');
    final excerpt = context.length > 280
        ? '${context.substring(0, 280)}…'
        : context;
    return 'Giải thích thêm bước ${index + 1}${excerpt.isEmpty ? '' : '\n$excerpt'}';
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = s.courseById(widget.courseId);
    final l = _lesson(c);
    if (c == null || l == null) {
      return const Scaffold(
        body: Center(child: Text('Bài học không còn tồn tại')),
      );
    }
    final blocks = l.blocks;
    final active = blocks == null || blocks.isEmpty
        ? null
        : l.stepIndex.clamp(0, blocks.length - 1);

    Widget body;
    if (_loading) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: AiThinking(
            eyebrow: 'AI đang soạn bài',
            hint: 'Thường mất 10–40 giây',
            messages: [
              'Đọc lại các nguồn của bạn…',
              'Chọn ý chính cho bài giảng…',
              'Chọn mô phỏng phù hợp với bài…',
              'Soạn câu hỏi có trích nguồn…',
              'Kiểm tra công thức và đáp án…',
            ],
          ),
        ),
      );
    } else if (_error != null && active == null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _generate, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    } else if (active == null) {
      body = Center(
        child: FilledButton(
          onPressed: _generate,
          child: const Text('Tạo bài học'),
        ),
      );
    } else {
      final content = blocks!;
      final step = content[active];
      final graded = l.gradedCount;
      final last = active == content.length - 1;
      body = Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  controller: _contentScroll,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  children: [
                    Text(
                      l.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (active == 0 && l.objectives.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l.objectives.map((goal) => '• $goal').join('\n')),
                    ],
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (active + 1) / content.length,
                      minHeight: 5,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bước ${active + 1}/${content.length} · ${_stepLabel(step)}',
                          ),
                        ),
                        if (l.isDone)
                          const Icon(
                            Icons.check_circle,
                            size: 19,
                            color: AppColors.success,
                            semanticLabel: 'Đã hoàn thành',
                          ),
                        IconButton(
                          tooltip: 'Xem các bước',
                          icon: const Icon(Icons.format_list_numbered),
                          onPressed: () => _chooseStep(l, content, active),
                        ),
                      ],
                    ),
                    if (graded > 0)
                      Text('Đã làm ${l.results.length}/$graded câu', style: Theme.of(context).textTheme.bodySmall),
                    if (l.results[active] case final bool wasCorrect
                        when step.isGraded)
                      Text(
                        wasCorrect
                            ? 'Lần đầu: trả lời đúng'
                            : 'Lần đầu: cần ôn lại',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    BlockRenderer(
                      key: ObjectKey(step),
                      block: step,
                      lesson: l,
                      onAnswered: (ok, chosen, correct) =>
                          s.recordResult(l, active, ok),
                      onTutor: (chosen, correct) => showTutorSheet(
                        context,
                        step,
                        chosen,
                        correct,
                        onAskMore: (q) => _openChat(c, l, question: q),
                      ),
                    ),
                    if (step.sourceId != null)
                      StudyCitation(course: c, block: step),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            _openChat(c, l, step: step, index: active),
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('Hỏi về bước này'),
                      ),
                    ),
                    if (last && l.results.isNotEmpty && graded > 0)
                      _ResultCard(lesson: l),
                    const SizedBox(height: 8),
                    if (last)
                      _ExercisePanel(
                        busy: _practicing,
                        difficulty: _difficulty,
                        onDifficulty: (d) => setState(() => _difficulty = d),
                        onGenerate: () => _practice(c, l),
                      ),
                    if (l.isDone || !last)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _toggleCompleted(l),
                          icon: Icon(
                            l.isDone ? Icons.undo : Icons.check_circle_outline,
                          ),
                          label: Text(
                            l.isDone
                                ? 'Đánh dấu chưa hoàn thành'
                                : 'Đánh dấu hoàn thành',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          _StepNavigation(
            previous: active == 0 ? null : () => _changeStep(l, active - 1),
            next: last
                ? (l.isDone ? null : () => _toggleCompleted(l))
                : () => _changeStep(l, active + 1),
            label: last
                ? (l.isDone ? 'Đã hoàn thành' : 'Hoàn thành bài')
                : 'Bước tiếp',
            icon: last ? Icons.check : Icons.arrow_forward,
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (active != null && !_loading)
            IconButton(
              tooltip: 'Khám phá thêm',
              icon: _exploring
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined),
              onPressed: _exploring ? null : () => _explore(l),
            ),
          if (active != null && !_loading)
            IconButton(
              tooltip: 'Tạo lại bài',
              icon: const Icon(Icons.refresh),
              onPressed: _generate,
            ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _chooseStep(
    Lesson lesson,
    List<Block> blocks,
    int current,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: blocks.length,
          itemBuilder: (context, index) => ListTile(
            selected: index == current,
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(blocks[index].title ?? _stepLabel(blocks[index])),
            trailing: index == current ? const Icon(Icons.chevron_right) : null,
            onTap: () => Navigator.pop(context, index),
          ),
        ),
      ),
    );
    if (picked != null && mounted) await _changeStep(lesson, picked);
  }

  String _stepLabel(Block block) => switch (block.type) {
    BlockType.mcq ||
    BlockType.trueFalse ||
    BlockType.fillBlank ||
    BlockType.matching ||
    BlockType.ordering => 'Kiểm tra',
    BlockType.codeDemo || BlockType.stepSolver => 'Ví dụ',
    BlockType.flashcards => 'Ghi nhớ',
    _ => block.isInteractive ? 'Thử tương tác' : 'Bài giảng',
  };
}

class _StepNavigation extends StatelessWidget {
  const _StepNavigation({
    required this.previous,
    required this.next,
    required this.label,
    required this.icon,
  });

  final VoidCallback? previous;
  final VoidCallback? next;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 828),
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: 'Bước trước',
                onPressed: previous,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: next,
                  icon: Icon(icon),
                  label: Text(label),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Bo de luyen: chon do kho roi sinh them 5 cau tu tai lieu.
class _ExercisePanel extends StatelessWidget {
  const _ExercisePanel({required this.busy, required this.difficulty, required this.onDifficulty, required this.onGenerate});
  final bool busy;
  final String difficulty;
  final ValueChanged<String> onDifficulty;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Eyebrow('Bộ đề luyện'),
          const SizedBox(height: 2),
          const Text('Luyện thêm từ chính tài liệu của bạn', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'easy', label: Text('Dễ')),
              ButtonSegment(value: 'medium', label: Text('Vừa')),
              ButtonSegment(value: 'hard', label: Text('Khó')),
            ],
            selected: {difficulty},
            onSelectionChanged: busy ? null : (s) => onDifficulty(s.first),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : onGenerate,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(busy ? 'AI đang soạn đề…' : 'Sinh thêm 5 câu'),
            ),
          ),
        ]),
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
        if (!e.value && e.key >= 0 && e.key < blocks.length && blocks[e.key].topic.isNotEmpty)
          blocks[e.key].topic,
    };
    final answered = lesson.results.length;
    final ratio = lesson.correctCount / answered;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          HeroBackground(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow(
                        'Kết quả bài học',
                        color: Color(0xFFFFE3E6),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Đúng ${lesson.correctCount}/$answered câu đã làm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        weak.isNotEmpty
                            ? 'Cần ôn lại: ${weak.join(', ')}'
                            : answered < lesson.gradedCount
                                ? 'Còn ${lesson.gradedCount - answered} câu chưa làm.'
                                : 'Đã trả lời tất cả câu hỏi.',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ProgressRing(
                  value: ratio,
                  size: 70,
                  stroke: 7,
                  color: Colors.white,
                  track: Colors.white.withValues(alpha: 0.25),
                ),
              ],
            ),
          ).correctPop(context),
          if (answered >= lesson.gradedCount && ratio >= 0.7)
            const Positioned(
              right: 0,
              top: -40,
              child: CelebrateBurst(size: 180),
            ),
        ],
      ),
    );
  }
}
