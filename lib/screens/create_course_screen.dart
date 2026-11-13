import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/source_widgets.dart';
import 'generating_screen.dart';
import 'roadmap_screen.dart';

/// Tao khoa hoc kieu NotebookLM: mot danh sach nguon chung (PDF, anh, van ban, trang web tim duoc),
/// cong tac "tra cuu web" mac dinh tat -> AI chi dua vao nguon da them.
class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key, required this.onCreated});
  final VoidCallback onCreated;
  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _goal = TextEditingController();
  final List<SourceDraft> _drafts = [];
  bool _allowWeb = false;

  static const _goalChips = ['Ôn thi cuối kỳ trong 2 tuần', 'Nắm vững kiến thức cơ bản', 'Luyện bài tập vận dụng'];
  static const _maxBytes = 4 * 1024 * 1024;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  void _add(List<SourceDraft> ds) => setState(() {
        for (final d in ds) {
          final dup = d.kind == SourceKind.web && _drafts.any((x) => x.web?.url == d.web!.url);
          if (!dup) _drafts.add(d);
        }
      });

  Future<void> _create() async {
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hãy thêm ít nhất một nguồn: tài liệu, văn bản hoặc nguồn web.')));
      return;
    }
    final state = context.read<AppState>();
    final goal = _goal.text.trim().isEmpty ? _goalChips.first : _goal.text.trim();
    final course = await Navigator.push<Course>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GeneratingScreen<Course>(
          title: 'Đang tạo khóa học',
          run: (onStep) => state.createCourse(goal: goal, drafts: List.of(_drafts), allowWeb: _allowWeb, onStep: onStep),
        ),
      ),
    );
    if (course == null || !mounted) return;
    setState(() {
      _drafts.clear();
      _allowWeb = false;
    });
    widget.onCreated();
    Navigator.push(context, MaterialPageRoute(builder: (_) => RoadmapScreen(courseId: course.id)));
  }

  @override
  Widget build(BuildContext context) {
    final tooBig = _drafts.any((d) => d.sizeBytes > _maxBytes);
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo khóa học')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionHeader(eyebrow: 'Bước 1', title: 'Nguồn (${_drafts.length})'),
        const Text('Thêm tài liệu của bạn, hoặc tìm nguồn uy tín trên mạng. AI chỉ dùng các nguồn trong danh sách này.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 10),
        SourceAddBar(onAdd: _add),
        if (_drafts.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(appRadius),
              border: Border.all(color: AppColors.border),
              color: Colors.white,
            ),
            child: const Column(children: [
              Icon(Icons.library_add_outlined, size: 36, color: AppColors.primary),
              SizedBox(height: 6),
              Text('Chưa có nguồn nào', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('Có thể thêm nhiều nguồn: slide, đề cương, ảnh chụp vở, trang web…', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        for (var i = 0; i < _drafts.length; i++)
          SourceRow(
            kind: _drafts[i].kind,
            title: _drafts[i].title,
            mimeType: _drafts[i].mimeType,
            url: _drafts[i].web?.url,
            trusted: _drafts[i].web?.trusted,
            subtitle: SourceRow.describe(_drafts[i].kind,
                mimeType: _drafts[i].mimeType, bytes: _drafts[i].sizeBytes, domain: _drafts[i].web?.domain, text: _drafts[i].text),
            enabled: true,
            onRemove: () => setState(() => _drafts.removeAt(i)),
          ),
        if (tooBig)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Có tài liệu lớn hơn 4MB, có thể bị từ chối. Hãy dùng bản ngắn hơn.', style: TextStyle(color: AppColors.danger)),
          ),
        const SizedBox(height: 8),
        WebSwitch(value: _allowWeb, onChanged: (v) => setState(() => _allowWeb = v)),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Bước 2', title: 'Mục tiêu học'),
        TextField(controller: _goal, decoration: InputDecoration(hintText: _goalChips.first)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final g in _goalChips) ActionChip(label: Text(g), onPressed: () => setState(() => _goal.text = g)),
        ]),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _create,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_awesome, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(_drafts.isEmpty ? 'AI lên lộ trình khóa học' : 'AI lên lộ trình từ ${_drafts.length} nguồn')),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, size: 18),
          ]),
        ),
      ]),
    );
  }
}
