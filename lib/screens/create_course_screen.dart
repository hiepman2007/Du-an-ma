import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/source_tile.dart';
import 'generating_screen.dart';
import 'roadmap_screen.dart';

class _Picked {
  _Picked(this.name, this.mimeType, this.bytes);
  final String name, mimeType;
  final Uint8List bytes;
}

/// Tao khoa hoc: tab "Tai lieu" (PDF/anh/van ban) va tab "Tim tren mang" (nguon co xac thuc).
class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key, required this.onCreated});
  final VoidCallback onCreated;
  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _goal = TextEditingController();
  final _text = TextEditingController();
  final _topic = TextEditingController();
  _Picked? _file;
  bool _showText = false;

  bool _searching = false;
  String? _searchError;
  List<WebSource> _results = [];
  final Set<String> _selected = {};

  static const _goalChips = ['Ôn thi cuối kỳ trong 2 tuần', 'Nắm vững kiến thức cơ bản', 'Luyện bài tập vận dụng'];

  @override
  void dispose() {
    _goal.dispose();
    _text.dispose();
    _topic.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (files.isEmpty) return;
    final f = files.first;
    final bytes = await f.xFile.readAsBytes();
    setState(() => _file = _Picked(f.name, 'application/pdf', bytes));
  }

  Future<void> _pickImage(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1800, imageQuality: 75);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final lower = x.name.toLowerCase();
    final mime = lower.endsWith('.png') ? 'image/png' : lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
    setState(() => _file = _Picked(x.name, mime, bytes));
  }

  Future<void> _search() async {
    final topic = _topic.text.trim();
    if (topic.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
      _results = [];
      _selected.clear();
    });
    try {
      final r = await context.read<AppState>().searchSources(topic);
      setState(() {
        _results = r;
        _selected.addAll(r.where((s) => s.trusted).take(3).map((s) => s.url));
        if (r.isEmpty) _searchError = 'Không tìm thấy nguồn phù hợp. Hãy thử chủ đề cụ thể hơn.';
      });
    } on ApiException catch (e) {
      setState(() => _searchError = e.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _create({required bool fromWeb}) async {
    final state = context.read<AppState>();
    final goal = _goal.text.trim().isEmpty ? _goalChips.first : _goal.text.trim();
    final sources = fromWeb ? _results.where((s) => _selected.contains(s.url)).toList() : <WebSource>[];
    final text = !fromWeb && _showText && _text.text.trim().isNotEmpty ? _text.text.trim() : null;
    if (!fromWeb && _file == null && text == null) return _snack('Hãy chọn tài liệu, chụp ảnh hoặc dán văn bản.');
    if (fromWeb && sources.isEmpty) return _snack('Hãy chọn ít nhất một nguồn.');
    final file = fromWeb ? null : _file;
    final course = await Navigator.push<Course>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => GeneratingScreen<Course>(
          title: 'Đang tạo khóa học',
          run: (onStep) => state.createCourse(
            goal: goal,
            fileName: file?.name,
            mimeType: file?.mimeType,
            bytes: file?.bytes,
            text: text,
            sources: sources,
            onStep: onStep,
          ),
        ),
      ),
    );
    if (course == null || !mounted) return;
    setState(() {
      _file = null;
      _text.clear();
      _results = [];
      _selected.clear();
    });
    widget.onCreated();
    Navigator.push(context, MaterialPageRoute(builder: (_) => RoadmapScreen(courseId: course.id)));
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _goalField() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Bước 2', title: 'Mục tiêu học'),
        TextField(controller: _goal, decoration: InputDecoration(hintText: _goalChips.first)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final g in _goalChips) ActionChip(label: Text(g), onPressed: () => setState(() => _goal.text = g)),
        ]),
      ]);

  Widget _cta(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: FilledButton(
          onPressed: onTap,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_awesome, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(label)),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, size: 18),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tạo khóa học'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.upload_file), text: 'Tài liệu'),
            Tab(icon: Icon(Icons.travel_explore), text: 'Tìm trên mạng'),
          ]),
        ),
        body: TabBarView(children: [_docTab(), _webTab()]),
      ),
    );
  }

  Widget _docTab() {
    Widget source(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(appRadius),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, size: 26, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SectionHeader(eyebrow: 'Bước 1', title: 'Chọn nguồn tài liệu'),
      Row(children: [
        source(Icons.picture_as_pdf_outlined, 'PDF / slide', _pickPdf),
        source(Icons.photo_camera_outlined, 'Chụp ảnh', () => _pickImage(ImageSource.camera)),
        source(Icons.photo_library_outlined, 'Ảnh có sẵn', () => _pickImage(ImageSource.gallery)),
      ]),
      if (_file != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Card(
            color: AppColors.accent,
            child: ListTile(
              leading: Icon(_file!.mimeType == 'application/pdf' ? Icons.picture_as_pdf : Icons.image, color: AppColors.primary),
              title: Text(_file!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${(_file!.bytes.length / 1024 / 1024).toStringAsFixed(1)} MB'),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _file = null)),
            ),
          ),
        ),
      if (_file != null && _file!.bytes.length > 4 * 1024 * 1024)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Tài liệu lớn hơn 4MB, có thể bị từ chối. Hãy dùng bản ngắn hơn.', style: TextStyle(color: AppColors.danger)),
        ),
      const SizedBox(height: 4),
      TextButton.icon(
        onPressed: () => setState(() => _showText = !_showText),
        icon: Icon(_showText ? Icons.expand_less : Icons.notes),
        label: const Text('Hoặc dán văn bản'),
      ),
      if (_showText)
        TextField(controller: _text, minLines: 4, maxLines: 10, decoration: const InputDecoration(hintText: 'Dán nội dung bài học, đề cương…')),
      _goalField(),
      _cta('AI lên lộ trình khóa học', () => _create(fromWeb: false)),
    ]);
  }

  Widget _webTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const SectionHeader(eyebrow: 'Bước 1', title: 'Chủ đề muốn học'),
      TextField(
        controller: _topic,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: 'Ví dụ: Định luật Ohm, Cung cầu thị trường…',
          suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _searching ? null : _search),
        ),
      ),
      const SizedBox(height: 12),
      if (_searching)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('AI đang tìm và kiểm tra nguồn…')]),
        ),
      if (_searchError != null) Text(_searchError!, style: const TextStyle(color: AppColors.danger)),
      if (_results.isNotEmpty) ...[
        const SizedBox(height: 8),
        const SectionHeader(eyebrow: 'Nguồn đã xác thực', title: 'Chọn nguồn để AI soạn bài'),
        const Text('Chỉ hiển thị link do công cụ tìm kiếm trả về. Nhãn “Đáng tin” dựa trên tên miền giáo dục, chính phủ, học thuật.',
            style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 10),
        for (final s in _results)
          SourceTile(
            source: s,
            selected: _selected.contains(s.url),
            onChanged: (v) => setState(() => v ? _selected.add(s.url) : _selected.remove(s.url)),
          ),
        _goalField(),
        _cta('Tạo khóa học từ ${_selected.length} nguồn', () => _create(fromWeb: true)),
      ],
    ]);
  }
}
