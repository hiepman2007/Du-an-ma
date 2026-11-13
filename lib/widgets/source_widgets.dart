import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'source_tile.dart';

/// Hang nut them nguon kieu NotebookLM: PDF, chup anh, anh co san, van ban, tim tren mang.
class SourceAddBar extends StatelessWidget {
  const SourceAddBar({super.key, required this.onAdd, this.enabled = true});
  final ValueChanged<List<SourceDraft>> onAdd;
  final bool enabled;

  Future<void> _pdf() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final out = <SourceDraft>[];
    for (final f in files) {
      out.add(SourceDraft.file(title: f.name, mimeType: 'application/pdf', bytes: await f.xFile.readAsBytes()));
    }
    if (out.isNotEmpty) onAdd(out);
  }

  Future<void> _image(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1800, imageQuality: 75);
    if (x == null) return;
    final lower = x.name.toLowerCase();
    final mime = lower.endsWith('.png') ? 'image/png' : lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg';
    onAdd([SourceDraft.file(title: x.name, mimeType: mime, bytes: await x.readAsBytes())]);
  }

  Future<void> _text(BuildContext context) async {
    final title = TextEditingController(text: 'Văn bản dán vào');
    final body = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(eyebrow: 'Thêm nguồn', title: 'Dán văn bản'),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Tên nguồn')),
          const SizedBox(height: 10),
          TextField(controller: body, minLines: 5, maxLines: 10, autofocus: true, decoration: const InputDecoration(hintText: 'Dán nội dung bài học, đề cương, ghi chép…')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Thêm nguồn'))),
        ]),
      ),
    );
    if (ok == true && body.text.trim().isNotEmpty) {
      onAdd([SourceDraft.text(title: title.text.trim().isEmpty ? 'Văn bản dán vào' : title.text.trim(), text: body.text.trim())]);
    }
  }

  Future<void> _web(BuildContext context) async {
    final picked = await showModalBottomSheet<List<WebSource>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _DiscoverSheet(),
    );
    if (picked != null && picked.isNotEmpty) onAdd(picked.map(SourceDraft.web).toList());
  }

  @override
  Widget build(BuildContext context) {
    Widget btn(IconData icon, String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 8),
          child: ActionChip(
            avatar: Icon(icon, size: 18, color: AppColors.primary),
            label: Text(label),
            onPressed: enabled ? onTap : null,
          ),
        );
    return Wrap(children: [
      btn(Icons.picture_as_pdf_outlined, 'PDF / slide', _pdf),
      btn(Icons.photo_camera_outlined, 'Chụp ảnh', () => _image(ImageSource.camera)),
      btn(Icons.photo_library_outlined, 'Ảnh có sẵn', () => _image(ImageSource.gallery)),
      btn(Icons.notes, 'Dán văn bản', () => _text(context)),
      btn(Icons.travel_explore, 'Tìm nguồn trên mạng', () => _web(context)),
    ]);
  }
}

/// "Discover" kieu NotebookLM: tim nguon tren mang, chon nguon de them vao danh sach nguon.
class _DiscoverSheet extends StatefulWidget {
  const _DiscoverSheet();
  @override
  State<_DiscoverSheet> createState() => _DiscoverSheetState();
}

class _DiscoverSheetState extends State<_DiscoverSheet> {
  final _topic = TextEditingController();
  bool _loading = false;
  String? _error;
  List<WebSource> _results = [];
  final Set<String> _selected = {};

  Future<void> _search() async {
    final t = _topic.text.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _selected.clear();
    });
    try {
      final r = await context.read<AppState>().searchSources(t);
      setState(() {
        _results = r;
        _selected.addAll(r.where((s) => s.trusted).take(3).map((s) => s.url));
        if (r.isEmpty) _error = 'Không tìm thấy nguồn phù hợp. Hãy thử chủ đề cụ thể hơn.';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(eyebrow: 'Tìm nguồn trên mạng', title: 'Khám phá nguồn uy tín'),
          TextField(
            controller: _topic,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Ví dụ: Quang hợp, Định luật Ohm…',
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _loading ? null : _search),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.danger)),
          if (_results.isNotEmpty) ...[
            const Text('Chỉ hiển thị link thật từ công cụ tìm kiếm. Chọn nguồn để thêm vào khóa học.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final s in _results)
                  SourceTile(
                    source: s,
                    selected: _selected.contains(s.url),
                    onChanged: (v) => setState(() => v ? _selected.add(s.url) : _selected.remove(s.url)),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _results.where((s) => _selected.contains(s.url)).toList()),
                child: Text('Thêm ${_selected.length} nguồn'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

IconData sourceIcon(SourceKind k, String? mime) => switch (k) {
      SourceKind.file => (mime ?? '').startsWith('image/') ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
      SourceKind.text => Icons.notes,
      SourceKind.web => Icons.language,
    };

/// Mot dong nguon: bieu tuong, ten, mo ta, o tich bat/tat, nut xoa.
class SourceRow extends StatelessWidget {
  const SourceRow({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.mimeType,
    this.url,
    this.trusted,
    required this.enabled,
    this.onToggle,
    this.onRemove,
  });
  final SourceKind kind;
  final String title, subtitle;
  final String? mimeType, url;
  final bool? trusted;
  final bool enabled;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Card(
        color: enabled ? null : const Color(0xFFF5F5F5),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 4, right: 4),
          leading: onToggle == null
              ? Padding(padding: const EdgeInsets.only(left: 12), child: Icon(sourceIcon(kind, mimeType), color: AppColors.primary))
              : Checkbox(value: enabled, onChanged: (v) => onToggle!(v ?? false)),
          title: Row(children: [
            if (onToggle != null) ...[Icon(sourceIcon(kind, mimeType), size: 18, color: AppColors.primary), const SizedBox(width: 6)],
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          subtitle: Row(children: [
            if (trusted != null) ...[
              Icon(trusted! ? Icons.verified : Icons.help_outline, size: 14, color: trusted! ? AppColors.success : const Color(0xFFB26A00)),
              const SizedBox(width: 4),
            ],
            Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
          ]),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (url != null)
              IconButton(
                tooltip: 'Mở link gốc',
                icon: const Icon(Icons.open_in_new, size: 20),
                onPressed: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
              ),
            if (onRemove != null) IconButton(tooltip: 'Xóa nguồn', icon: const Icon(Icons.close, size: 20), onPressed: onRemove),
          ]),
        ),
      ),
    );
  }

  static String describe(SourceKind kind, {String? mimeType, int bytes = 0, String? domain, String? text}) => switch (kind) {
        SourceKind.file => '${(mimeType ?? '').startsWith('image/') ? 'Ảnh' : 'PDF'}${bytes > 0 ? ' · ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB' : ''}',
        SourceKind.text => 'Văn bản · ${(text ?? '').length} ký tự',
        SourceKind.web => domain ?? 'Trang web',
      };
}

/// Cong tac tra cuu web (mac dinh tat: AI chi dua vao nguon da nap).
class WebSwitch extends StatelessWidget {
  const WebSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          secondary: Icon(Icons.public, color: value ? AppColors.primary : AppColors.muted),
          title: const Text('Cho phép gia sư tra cứu thêm trên mạng', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(value
              ? 'Gia sư dùng nguồn của bạn + thông tin trên mạng (có ghi nguồn).'
              : 'Mặc định: gia sư CHỈ dựa vào các nguồn bạn đã thêm.'),
        ),
      );
}
