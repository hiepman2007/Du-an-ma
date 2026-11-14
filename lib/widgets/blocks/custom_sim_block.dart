import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../canvas_preview.dart';
import '../rich_content.dart';
import '../../services/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import 'common.dart';

/// Mo phong tuong tac do AI viet rieng (HTML + canvas), chay trong khung cach ly:
/// CSP chan moi ket noi ngoai, chan dieu huong. Trong chat ([auto]) tu dung ngay nhu ChatGPT;
/// trong bai hoc thi bam nut moi dung. Sua tiep bang loi, xem toan man hinh.
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
    return BlockCard(
      icon: Icons.auto_awesome_motion_outlined,
      label: 'Mô phỏng do AI dựng riêng',
      title: title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (sim != null && '${sim['instructions'] ?? ''}'.isNotEmpty) ...[RichContent('${sim['instructions']}'), const SizedBox(height: 10)],
        if (sim == null && !busy && widget.block.body?.isNotEmpty == true) ...[RichContent(widget.block.body!), const SizedBox(height: 10)],
        if (busy)
          _Building(prompt: prompt, revising: sim != null)
        else if (sim == null) ...[
          if (_error != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.play_circle_outline),
            label: Text(_error != null || state.simFailed(widget.block) ? 'Thử lại' : 'Tạo mô phỏng'),
          ),
        ] else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(height: 440, child: CanvasPreview(html: '${sim['html'] ?? ''}')),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
          Wrap(spacing: 4, children: [
            TextButton.icon(
                onPressed: () => _fullscreen(title, '${sim['html'] ?? ''}'),
                icon: const Icon(Icons.fullscreen, size: 18),
                label: const Text('Toàn màn hình')),
            TextButton.icon(onPressed: _revise, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Sửa bằng lời')),
          ]),
        ],
        const SizedBox(height: 2),
        const Text('Chạy cách ly: không truy cập mạng hay dữ liệu của ứng dụng.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}

class _Building extends StatelessWidget {
  const _Building({required this.prompt, required this.revising});
  final String prompt;
  final bool revising;

  @override
  Widget build(BuildContext context) => Container(
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 12),
          Text(revising ? 'Đang sửa mô phỏng…' : 'Đang dựng mô phỏng riêng cho câu hỏi này…',
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
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
