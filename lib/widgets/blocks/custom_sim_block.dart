import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../screens/canvas_screen.dart';
import '../canvas_preview.dart';
import '../rich_content.dart';
import '../../services/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import 'common.dart';

/// Ung dung mo phong do AI viet rieng (kieu Gemini Canvas): HTML + Tailwind/Chart.js/three.js tu CDN cho phep,
/// chay trong khung cach ly (CSP chan moi ket noi khac, chan dieu huong). Trong chat ([auto]) tu dung ngay;
/// trong bai hoc thi bam nut moi dung. Xem truoc / xem ma, toan man hinh, sua bang loi, luu thanh Canvas.
class CustomSimBlock extends StatefulWidget {
  const CustomSimBlock({super.key, required this.block, required this.lesson, this.auto = false, this.question});
  final Block block;
  final Lesson lesson;
  final bool auto;
  final String? question;
  @override
  State<CustomSimBlock> createState() => _CustomSimBlockState();
}

class _CustomSimBlockState extends State<CustomSimBlock> {
  String? _error;
  bool _code = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    if (widget.auto && widget.block.sim == null && !state.isSimBusy(widget.block) && !state.simFailed(widget.block)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _generate();
      });
    }
  }

  Future<void> _generate({String? revise}) async {
    setState(() => _error = null);
    try {
      await context.read<AppState>().generateSimulation(widget.lesson, widget.block, question: widget.question, revise: revise);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa dựng được mô phỏng. Hãy kiểm tra kết nối rồi thử lại.');
    }
  }

  Future<void> _revise() async {
    final request = await showDialog<String>(context: context, builder: (_) => const _ReviseDialog());
    if (request != null && request.isNotEmpty && mounted) await _generate(revise: request);
  }

  Future<void> _openCanvas() async {
    final state = context.read<AppState>();
    final course = state.selectedCourse;
    if (course == null) return;
    final artifact = await state.saveSimulationAsCanvas(course, widget.block);
    if (artifact == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => CanvasScreen(courseId: course.id, artifactId: artifact.id)));
  }

  void _fullscreen(String title, String html) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => Scaffold(
                appBar: AppBar(title: Text(title)),
                body: SafeArea(child: CanvasPreview(html: html)),
              )));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final sim = widget.block.sim;
    final busy = state.isSimBusy(widget.block);
    final title = '${sim?['title'] ?? widget.block.title ?? 'Mô phỏng tương tác'}';
    final prompt = '${widget.block.raw['sim_prompt'] ?? widget.block.body ?? ''}';
    final html = '${sim?['html'] ?? ''}';
    if (sim == null || busy) {
      return BlockCard(
        icon: Icons.auto_awesome_motion_outlined,
        label: 'Mô phỏng do AI dựng riêng',
        title: title,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!busy && widget.block.body?.isNotEmpty == true) ...[RichContent(widget.block.body!), const SizedBox(height: 10)],
          if (busy)
            _Building(prompt: prompt, revising: sim != null)
          else ...[
            if (_error != null)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
            FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.play_circle_outline),
              label: Text(_error != null || state.simFailed(widget.block) ? 'Thử lại' : 'Tạo mô phỏng'),
            ),
          ],
        ]),
      );
    }
    // Khung kieu Canvas: thanh tieu de + Ma/Xem truoc + toan man hinh, ben duoi la ung dung.
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: const Color(0xFF1F1F1F),
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(children: [
            const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFFF8A94)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            _Toggle(code: _code, onChanged: (v) => setState(() => _code = v)),
            IconButton(
              tooltip: 'Toàn màn hình',
              visualDensity: VisualDensity.compact,
              onPressed: () => _fullscreen(title, html),
              icon: const Icon(Icons.fullscreen, color: Colors.white),
            ),
          ]),
        ),
        SizedBox(
          height: 560,
          child: _code
              ? Container(
                  color: const Color(0xFF111111),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(html,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFFE6E6E6), height: 1.35)),
                  ),
                )
              : CanvasPreview(html: html),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if ('${sim['instructions'] ?? ''}'.isNotEmpty) RichContent('${sim['instructions']}', style: const TextStyle(fontSize: 13.5)),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
            Wrap(spacing: 4, children: [
              TextButton.icon(onPressed: _revise, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Sửa bằng lời')),
              if (state.selectedCourse != null)
                TextButton.icon(onPressed: _openCanvas, icon: const Icon(Icons.widgets_outlined, size: 18), label: const Text('Mở trong Canvas')),
              if (_code)
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: html));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép mã.')));
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Sao chép mã'),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.code, required this.onChanged});
  final bool code;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String label, bool selected, bool value) => GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(14)),
            child: Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? const Color(0xFF1F1F1F) : Colors.white70)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [item('Mã', code, true), item('Xem trước', !code, false)]),
    );
  }
}

class _Building extends StatelessWidget {
  const _Building({required this.prompt, required this.revising});
  final String prompt;
  final bool revising;

  @override
  Widget build(BuildContext context) => Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 12),
          Text(revising ? 'Đang sửa ứng dụng mô phỏng…' : 'AI đang viết ứng dụng mô phỏng riêng cho câu hỏi này…',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Thường mất 30–90 giây.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 6),
          Flexible(
            child: Text(prompt, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
        ]),
      );
}

class _ReviseDialog extends StatefulWidget {
  const _ReviseDialog();
  @override
  State<_ReviseDialog> createState() => _ReviseDialogState();
}

class _ReviseDialogState extends State<_ReviseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sửa mô phỏng'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Ví dụ: thêm thanh trượt nhiệt độ, cho chạy chậm hơn'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('Sửa')),
        ],
      );
}
