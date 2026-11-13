import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Gia su goi mo: goi y truoc (khong lo dap an), bam moi xem giai thich + goc loi.
Future<void> showTutorSheet(BuildContext context, Block block, String chosen, String correct) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TutorSheet(block: block, chosen: chosen, correct: correct),
  );
}

class _TutorSheet extends StatefulWidget {
  const _TutorSheet({required this.block, required this.chosen, required this.correct});
  final Block block;
  final String chosen, correct;
  @override
  State<_TutorSheet> createState() => _TutorSheetState();
}

class _TutorSheetState extends State<_TutorSheet> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _showFull = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await context.read<AppState>().explain(widget.block, widget.chosen, widget.correct);
      if (mounted) setState(() => _data = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionHeader(eyebrow: 'Gia sư AI', title: 'Cùng nghĩ lại nhé'),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _load, child: const Text('Thử lại')),
          ] else if (d == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else ...[
            _box('Gợi ý', d['hint'] ?? '', AppColors.accent),
            if (!_showFull)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(onPressed: () => setState(() => _showFull = true), child: const Text('Xem giải thích đầy đủ')),
              )
            else ...[
              _box('Đáp án đúng', widget.correct, const Color(0xFFEAF6EC)),
              _box('Giải thích', d['explanation'] ?? '', const Color(0xFFF5F5F5)),
              _box('Gốc của lỗi', d['root_cause'] ?? '', const Color(0xFFFFF8E1)),
              if ((d['weak_topic'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Chip(avatar: const Icon(Icons.flag_outlined, size: 18), label: Text('Chủ đề cần ôn: ${d['weak_topic']}')),
                ),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _box(String label, String text, Color bg) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(label, color: AppColors.foreground),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 15, height: 1.45)),
        ]),
      );
}
