import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../theme.dart';
import '../rich_content.dart';
import 'common.dart';

/// Code minh hoa (Tin hoc/lap trinh): to mau co ban, sao chep, ket qua chay do AI ghi (khong chay code tren may).
class CodeDemoBlock extends StatefulWidget {
  const CodeDemoBlock({super.key, required this.block});
  final Block block;
  @override
  State<CodeDemoBlock> createState() => _CodeDemoBlockState();
}

class _CodeDemoBlockState extends State<CodeDemoBlock> {
  bool _showOutput = false;

  @override
  Widget build(BuildContext context) {
    final code = widget.block.rawMap('code') ?? {};
    final source = '${code['source'] ?? ''}';
    final output = '${code['output'] ?? ''}';
    return BlockCard(
      icon: Icons.code,
      label: 'Code minh họa',
      title: widget.block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.block.body?.isNotEmpty == true) RichContent(widget.block.body!),
        CodeView(code: source, language: '${code['language'] ?? ''}'),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: source));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép code')));
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Sao chép'),
          ),
          if (output.isNotEmpty)
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _showOutput = !_showOutput),
              icon: Icon(_showOutput ? Icons.visibility_off_outlined : Icons.play_arrow),
              label: Text(_showOutput ? 'Ẩn kết quả' : 'Xem kết quả chạy'),
            ),
        ]),
        if (_showOutput)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Kết quả', color: AppColors.muted),
              const SizedBox(height: 4),
              Text(output, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ]),
          ),
      ]),
    );
  }
}
