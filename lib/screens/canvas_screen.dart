import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/canvas_preview.dart';
import '../widgets/rich_content.dart';

/// Canvas: mo ta bang loi → AI viet mot ung dung/mo phong nho chay ngay;
/// sua tiep bang loi, moi lan sua la mot phien ban, xem truoc hoac xem ma.
class CanvasScreen extends StatefulWidget {
  const CanvasScreen({super.key, required this.courseId, this.artifactId, this.lessonId, this.initialPrompt});

  final String courseId;
  final String? artifactId, lessonId, initialPrompt;

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  late String? _artifactId = widget.artifactId;
  late final _prompt = TextEditingController(text: widget.initialPrompt ?? '');
  final _revision = TextEditingController();
  int? _version;
  bool _showCode = false;
  String? _error;

  @override
  void dispose() {
    _prompt.dispose();
    _revision.dispose();
    super.dispose();
  }

  Future<void> _create(AppState state, Course course) async {
    final text = _prompt.text.trim();
    if (text.isEmpty) return;
    setState(() => _error = null);
    try {
      final canvas = await state.createCanvas(course, text, lessonId: widget.lessonId);
      if (canvas != null && mounted) setState(() => _artifactId = canvas.id);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _revise(AppState state, Course course, StudyArtifact canvas, int from) async {
    final text = _revision.text.trim();
    if (text.isEmpty) return;
    setState(() => _error = null);
    try {
      final ok = await state.reviseCanvas(course, canvas, from, text);
      if (ok == true && mounted) {
        _revision.clear();
        setState(() {
          _version = canvas.blocks.length - 1;
          _showCode = false;
        });
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
    final canvas = _artifactId == null ? null : course.artifacts.where((a) => a.id == _artifactId).firstOrNull;
    final busy = state.isBusy(course, 'canvas');
    if (canvas == null || canvas.blocks.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Canvas')),
        body: SafeArea(child: busy ? const _Working(text: 'AI đang viết ứng dụng…') : _composer(state, course)),
      );
    }
    final version = (_version ?? canvas.blocks.length - 1).clamp(0, canvas.blocks.length - 1);
    final current = canvas.blocks[version];
    final html = '${current.sim?['html'] ?? ''}';
    return Scaffold(
      appBar: AppBar(
        title: Text(canvas.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _showCode ? 'Xem trước' : 'Xem mã',
            icon: Icon(_showCode ? Icons.play_circle_outline : Icons.code),
            onPressed: () => setState(() => _showCode = !_showCode),
          ),
          IconButton(
            tooltip: 'Toàn màn hình',
            icon: const Icon(Icons.fullscreen),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
              appBar: AppBar(title: Text('${canvas.title} · v${version + 1}')),
              body: CanvasPreview(html: html),
            ))),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final stage = _stage(html, busy, version);
          final panel = _panel(state, course, canvas, version, busy, wide: constraints.maxWidth >= 900);
          if (constraints.maxWidth >= 900) {
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: 360, child: panel),
              const VerticalDivider(width: 1),
              Expanded(child: Padding(padding: const EdgeInsets.all(16), child: stage)),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _versionBar(canvas, version),
            Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: stage)),
            panel,
          ]);
        }),
      ),
    );
  }

  Widget _composer(AppState state, Course course) {
    final lesson = course.lessons.where((l) => l.id == widget.lessonId).firstOrNull;
    final ideas = [
      if (lesson != null) 'Mô phỏng tương tác giúp hiểu bài "${lesson.title}"',
      for (final l in course.lessons.take(3))
        if (l != lesson) 'Mô phỏng cho bài "${l.title}" có thanh trượt và nút chạy từng bước',
      'Con lắc đơn: kéo chiều dài và góc, xem chu kỳ thay đổi',
      'Đồ thị y = ax² + bx + c với thanh trượt a, b, c',
      'Sắp xếp nổi bọt từng bước với mảng ngẫu nhiên',
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Icon(Icons.auto_awesome, size: 36, color: AppColors.primary),
      const SizedBox(height: 8),
      Text('Bạn muốn dựng mô phỏng gì?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Mô tả bằng lời. AI viết thành một ứng dụng nhỏ chạy ngay, bạn sửa tiếp bằng lời.',
          style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 16),
      if (_error != null) _ErrorBox(message: _error!, onRetry: () => _create(state, course)),
      TextField(
        controller: _prompt,
        minLines: 3,
        maxLines: 6,
        maxLength: 600,
        decoration: const InputDecoration(hintText: 'Ví dụ: mô phỏng ném xiên, kéo góc và vận tốc ban đầu, hiện quỹ đạo'),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _prompt.text.trim().isEmpty ? null : () => _create(state, course),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Tạo'),
      ),
      const SizedBox(height: 20),
      const Text('Gợi ý', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      for (final idea in ideas)
        Card(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.lightbulb_outline, color: AppColors.primary),
            title: Text(idea),
            onTap: () => setState(() => _prompt.text = idea),
          ),
        ),
    ]);
  }

  Widget _stage(String html, bool busy, int version) {
    final body = _showCode
        ? Stack(children: [
            Container(
              color: const Color(0xFF1E1E1E),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 48),
                child: SelectableText(html,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFD4D4D4), height: 1.4)),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: html));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép mã')));
                  }
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Sao chép'),
              ),
            ),
          ])
        : CanvasPreview(key: ValueKey('canvas-$version-${html.length}'), html: html);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
        child: Stack(fit: StackFit.expand, children: [
          body,
          if (busy)
            const ColoredBox(color: Color(0xB3FFFFFF), child: _Working(text: 'AI đang sửa…')),
        ]),
      ),
    );
  }

  Widget _versionBar(StudyArtifact canvas, int version) => SizedBox(
        height: 52,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
          for (var i = 0; i < canvas.blocks.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Tooltip(
                message: '${canvas.blocks[i].raw['sim_prompt'] ?? ''}',
                child: ChoiceChip(
                  label: Text('v${i + 1}'),
                  selected: i == version,
                  onSelected: (_) => setState(() => _version = i),
                ),
              ),
            ),
        ]),
      );

  Widget _panel(AppState state, Course course, StudyArtifact canvas, int version, bool busy, {required bool wide}) {
    final current = canvas.blocks[version];
    final last = version == canvas.blocks.length - 1;
    final composer = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      if (_error != null) _ErrorBox(message: _error!, onRetry: () => _revise(state, course, canvas, version)),
      if (!last)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('Sửa tiếp từ v${version + 1} (bản mới sẽ là v${canvas.blocks.length + 1})',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _revision,
            enabled: !busy,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _revise(state, course, canvas, version),
            decoration: const InputDecoration(hintText: 'Yêu cầu sửa: thêm nút tạm dừng, đổi màu…', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Gửi yêu cầu sửa',
          onPressed: busy ? null : () => _revise(state, course, canvas, version),
          icon: const Icon(Icons.arrow_upward),
        ),
      ]),
    ]);
    if (!wide) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if ('${current.sim?['instructions'] ?? ''}'.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 72),
              child: SingleChildScrollView(
                child: RichContent('${current.sim?['instructions']}', style: const TextStyle(fontSize: 13)),
              ),
            ),
          const SizedBox(height: 8),
          composer,
        ]),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.all(12), children: [
          for (var i = 0; i < canvas.blocks.length; i++)
            Card(
              color: i == version ? AppColors.accent : null,
              child: ListTile(
                onTap: () => setState(() => _version = i),
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                title: Text('${canvas.blocks[i].raw['sim_prompt'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
                subtitle: Text('${canvas.blocks[i].sim?['instructions'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            ),
        ]),
      ),
      Padding(padding: const EdgeInsets.all(12), child: composer),
    ]);
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Thường mất 20–40 giây.', style: TextStyle(color: AppColors.muted)),
        ]),
      );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.primaryDark, fontSize: 13))),
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}
