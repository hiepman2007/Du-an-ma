import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/source_widgets.dart';
import 'roadmap_screen.dart';
import 'canvas_screen.dart';
import 'quiz_builder_screen.dart';
import 'quiz_player_screen.dart';
import 'study_artifact_screen.dart';
import 'study_goal_sheet.dart';
import 'tutor_chat_screen.dart';

const _sourceLabels = {
  'lecture': 'Bài giảng và tham khảo',
  'exam': 'Đề thi gốc',
  'practice': 'Bài luyện',
  'simulation': 'Mô phỏng',
};

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key, required this.course});

  final Course course;

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  String? _sourceError, _studioError;
  int _tab = 1;
  bool _addingSources = false;
  bool _webOnly = false;
  Course get _course => widget.course;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final prompt = state.openingPrompt;
    state.openingPrompt = null;
    if (state.openSourcesFirst) _tab = 0;
    state.openSourcesFirst = false;
    if (_course.isSample) _tab = 2;
    if (prompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _plan(topic: _topicFrom(prompt));
      });
    }
  }

  String _topicFrom(String input) {
    final result = input.trim().replaceFirst(RegExp(
      r'^(?:hãy\s+)?(?:tìm(?:\s+nguồn|\s+tài liệu)?(?:\s+cho\s+(?:tôi|mình))?\s+và\s+)?(?:lên|lập|tạo)\s+(?:lộ trình|khóa học)(?:\s+học)?(?:\s+cho\s+(?:tôi|mình))?(?:\s+(?:về|cho))?(?:\s+môn)?\s*',
      caseSensitive: false), '').trim();
    return result.isEmpty ? '' : result;
  }

  Future<void> _plan({String? topic, bool edit = false}) async {
    final state = context.read<AppState>();
    final brief = await showStudyGoal(context,
      topic: topic ?? _course.brief?.topic ?? (_course.title == 'Sổ học tập mới' ? '' : _course.title),
      previous: topic == null ? _course.brief : null, edit: edit);
    if (brief == null || !mounted) return;
    if (edit) {
      await _withError(() => state.updateSchedule(_course, brief), (message) => _studioError = message);
    } else {
      await _runPlan(brief);
    }
  }

  Future<void> _runPlan(StudyBrief brief) async {
    final state = context.read<AppState>();
    setState(() => _tab = 2);
    await _withError(() => state.planCourse(_course, brief), (message) => _studioError = message);
  }

  Future<void> _withError(Future<void> Function() operation, void Function(String?) setError) async {
    setState(() => setError(null));
    try {
      await operation();
    } on ApiException catch (error) {
      if (mounted) setState(() => setError(error.message));
    } catch (_) {
      if (mounted) setState(() => setError('Chưa thực hiện được thao tác này. Hãy kiểm tra kết nối rồi thử lại.'));
    }
  }

  /// Khung chat chuyen cau "lap lo trinh" sang bang muc tieu khi so chua co lo trinh.
  Future<bool> _intercept(String question) async {
    if (_course.lessons.isEmpty && RegExp(r'lộ trình|tạo khóa học|lập kế hoạch học', caseSensitive: false).hasMatch(question)) {
      await _plan(topic: _topicFrom(question));
      return true;
    }
    return false;
  }

  Future<void> _addSources(List<SourceDraft> sources) async {
    if (_addingSources) return;
    final state = context.read<AppState>();
    setState(() => _addingSources = true);
    await _withError(() => state.addSources(_course, sources), (message) => _sourceError = message);
    if (mounted) setState(() => _addingSources = false);
  }

  Future<void> _addUrl() async {
    final state = context.read<AppState>();
    final url = await showDialog<String>(context: context, builder: (_) => const _LinkDialog());
    if (url == null || !mounted) return;
    await _withError(() => state.addWebUrl(_course, url), (message) => _sourceError = message);
  }

  Future<void> _artifact(StudyArtifactKind kind, {bool regenerate = false}) async {
    final state = context.read<AppState>();
    setState(() => _tab = 2);
    if (_course.isSample && !regenerate) {
      final sample = _course.artifacts.where((item) => item.kind == kind).lastOrNull;
      if (sample != null) {
        _openArtifact(sample);
        return;
      }
    }
    await _withError(() async {
      final item = await state.createArtifact(_course, kind, webOnly: _webOnly, regenerate: regenerate);
      if (item != null && mounted) _openArtifact(item);
    }, (message) => _studioError = message);
  }

  void _openArtifact(StudyArtifact artifact) => Navigator.push(context, MaterialPageRoute(builder: (_) => artifact.kind.isQuiz
    ? QuizPlayerScreen(courseId: _course.id, artifactId: artifact.id)
    : artifact.kind == StudyArtifactKind.canvas ? CanvasScreen(courseId: _course.id, artifactId: artifact.id)
    : StudyArtifactScreen(courseId: _course.id, artifactId: artifact.id)));

  void _openQuizBuilder({String? lessonId}) => Navigator.push(context, MaterialPageRoute(builder: (_) =>
    QuizBuilderScreen(courseId: _course.id, lessonId: lessonId)));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1050;
      final sources = _sources(state);
      final chat = _chat(state);
      final studio = _studio(state);
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 285, child: sources),
          const VerticalDivider(width: 1),
          Expanded(child: chat),
          const VerticalDivider(width: 1),
          SizedBox(width: 340, child: studio),
        ]);
      }
      return Column(children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Nguồn'), icon: Icon(Icons.folder_outlined)),
            ButtonSegment(value: 1, label: Text('Hỏi đáp'), icon: Icon(Icons.chat_bubble_outline)),
            ButtonSegment(value: 2, label: Text('Studio'), icon: Icon(Icons.dashboard_customize_outlined)),
          ],
          selected: {_tab}, showSelectedIcon: false, onSelectionChanged: (value) => setState(() => _tab = value.first),
        ),
        const SizedBox(height: 8),
        Expanded(child: IndexedStack(index: _tab, children: [sources, chat, studio])),
      ]);
    });
  }

  Widget _heading(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _error(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
  );

  Widget _sources(AppState state) {
    final sources = _course.activeSources;
    final groups = {'': 'Tài liệu của sổ', ..._sourceLabels};
    return ListView(padding: const EdgeInsets.all(16), children: [
      _heading('Nguồn', Icons.folder_outlined),
      if (sources.isNotEmpty) Text('${_course.enabledSources.length}/${sources.length} nguồn đang chọn'),
      const SizedBox(height: 8),
      SourceAddBar(onAdd: _addSources, enabled: !_addingSources),
      OutlinedButton.icon(onPressed: state.isBusy(_course, 'url') ? null : _addUrl,
        icon: const Icon(Icons.link), label: const Text('Thêm liên kết web')),
      if (_addingSources || state.isBusy(_course, 'url')) const LinearProgressIndicator(),
      if (_sourceError != null) _error(_sourceError!),
      if (sources.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 14),
        child: Text('Thêm tài liệu để hỏi đáp, hoặc tìm nguồn theo chủ đề bạn muốn học.')),
      if (_course.researchMode == 'catalog' || _course.researchMode == 'partial')
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Một số kết quả có thể đến từ danh mục nguồn đã kiểm tra.')),
      if (_course.missingCategories.isNotEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(
          'Chưa tìm thấy ${_course.missingCategories.map((c) => _sourceLabels[c]?.toLowerCase() ?? c).join(', ')}.')),
      for (final group in groups.entries)
        if (sources.any((s) => group.key == '' ? !_sourceLabels.containsKey(s.category) : s.category == group.key)) ...[
          const SizedBox(height: 14),
          Text(group.value, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final source in sources.where((s) => group.key == '' ? !_sourceLabels.containsKey(s.category) : s.category == group.key))
            SourceRow(kind: source.kind, title: source.title, mimeType: source.mimeType, url: source.url,
              subtitle: source.kind == SourceKind.web
                ? [source.publisher.isEmpty ? source.domain : source.publisher,
                    if (source.extract.isEmpty) 'Chỉ liên kết'].where((v) => v.isNotEmpty).join(' · ')
                : source.kind == SourceKind.file && state.signedIn && source.storagePath == null
                    ? 'Cần đính kèm lại' : SourceRow.describe(source.kind, mimeType: source.mimeType, text: source.text),
              trusted: source.kind == SourceKind.web ? source.trusted : null,
              enabled: source.enabled, onToggle: (on) => state.setSourceEnabled(_course, source, on),
              onRemove: () => state.removeSource(_course, source)),
        ],
    ]);
  }

  Widget _chat(AppState state) => TutorChat(
    courseId: _course.id,
    onIntercept: _intercept,
    onSaveNote: (message) => state.saveChatNote(_course, message),
    emptyActions: [
      if (_course.lessons.isEmpty) ActionChip(avatar: const Icon(Icons.route_outlined, size: 18),
        label: const Text('Lập lộ trình'), onPressed: () => _plan()),
      if (_course.enabledSources.isNotEmpty) ...[
        ActionChip(label: const Text('Tóm tắt'), onPressed: () => _artifact(StudyArtifactKind.summary)),
        ActionChip(label: const Text('Tạo quiz'), onPressed: () => _artifact(StudyArtifactKind.quickQuiz)),
      ],
    ],
  );

  Widget _studio(AppState state) {
    final planning = state.isBusy(_course, 'plan');
    final artifactBusy = state.isBusy(_course, 'artifact');
    final brief = _course.brief;
    final hasPlan = _course.lessons.isNotEmpty;
    return ListView(padding: const EdgeInsets.all(16), children: [
      _heading('Studio', Icons.dashboard_customize_outlined),
      if (_course.isSample) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Sổ mẫu · Nội dung có sẵn')),
      if (!hasPlan) FilledButton.icon(onPressed: planning ? null : () => _plan(),
        icon: const Icon(Icons.route_outlined), label: const Text('Lập lộ trình')),
      if (planning) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: 6),
        Text(brief?.searchWeb == true && !_course.researchDone ? 'Đang tìm nguồn…'
          : !hasPlan ? 'Đang lập sơ đồ học…' : 'Đang chuẩn bị bài giảng đầu tiên…'),
      ],
      if (!planning && brief != null && (!hasPlan || _course.lessons.first.blocks == null))
        TextButton.icon(onPressed: () => _runPlan(brief), icon: const Icon(Icons.refresh), label: const Text('Tiếp tục chuẩn bị khóa học')),
      if (hasPlan) ...[
        if (brief != null) TextButton.icon(onPressed: planning ? null : () => _plan(edit: true),
          icon: const Icon(Icons.calendar_today_outlined), label: const Text('Điều chỉnh lịch học')),
        if (_course.lessons.any((lesson) => !lesson.completed && lesson.scheduledAt == null) && brief?.examDate != null)
          const Text('Một số bài vượt thời gian trước ngày thi. Tăng thời lượng mỗi ngày hoặc ưu tiên bài cần nhất.'),
        StudyRoadmap(courseId: _course.id, showSources: false),
      ],
      const SizedBox(height: 16),
      if (artifactBusy) const LinearProgressIndicator(),
      if (_studioError != null) _error(_studioError!),
      if (_course.enabledSources.any((source) => source.kind == SourceKind.web && source.extract.isNotEmpty))
        FilterChip(selected: _webOnly, label: const Text('Chỉ dùng nguồn web'),
          onSelected: (value) => setState(() => _webOnly = value)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: FilledButton.tonalIcon(
          onPressed: _course.enabledSources.isEmpty ? null : () => _openQuizBuilder(),
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('Tạo quiz'),
        )),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CanvasScreen(courseId: _course.id))),
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Canvas'),
        )),
      ]),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final kind in StudyArtifactKind.values.where((kind) => kind != StudyArtifactKind.note && kind != StudyArtifactKind.quiz && kind != StudyArtifactKind.canvas))
          ActionChip(label: Text(kind.label), onPressed: artifactBusy ? null : () => _artifact(kind)),
      ]),
      const SizedBox(height: 12),
      for (final artifact in _course.artifacts.reversed)
        Card(child: ListTile(
          leading: Icon(artifact.kind.isQuiz ? Icons.quiz_outlined : artifact.kind == StudyArtifactKind.canvas ? Icons.auto_awesome
            : Icons.description_outlined, color: AppColors.primary),
          title: Text(artifact.title),
          subtitle: Text(artifact.kind == StudyArtifactKind.canvas ? 'Canvas · ${artifact.blocks.length} phiên bản'
            : artifact.attempts.isEmpty ? '${artifact.kind.label} · v${artifact.version}'
            : '${artifact.attempts.length} lượt làm · v${artifact.version}'),
          onTap: () => _openArtifact(artifact),
          trailing: artifact.kind == StudyArtifactKind.note || artifact.kind == StudyArtifactKind.canvas || _course.isSample ? null : IconButton(
            tooltip: 'Tạo phiên bản mới', icon: const Icon(Icons.refresh),
            onPressed: artifact.kind == StudyArtifactKind.quiz ? () => _openQuizBuilder(lessonId: artifact.lessonId)
              : artifactBusy ? null : () => _artifact(artifact.kind, regenerate: true),
          ),
        )),
    ]);
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
    content: TextField(controller: _input, autofocus: true, keyboardType: TextInputType.url,
      onSubmitted: (_) => _submit(), decoration: InputDecoration(hintText: 'https://…', errorText: _error)),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
      FilledButton(onPressed: _submit, child: const Text('Thêm nguồn')),
    ],
  );
}
