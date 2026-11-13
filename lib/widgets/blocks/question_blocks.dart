import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import 'common.dart';

String normalize(String s) => s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[.,;:!?]$'), '');

/// Trac nghiem 4 lua chon.
class McqBlock extends StatefulWidget {
  const McqBlock({super.key, required this.block, required this.onAnswered, this.onTutor});
  final Block block;
  final OnAnswered onAnswered;
  final void Function(String chosen, String correct)? onTutor;
  @override
  State<McqBlock> createState() => _McqBlockState();
}

class _McqBlockState extends State<McqBlock> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final correct = b.answerIndex ?? 0;
    final cs = Theme.of(context).colorScheme;
    return BlockCard(
      icon: Icons.quiz_outlined,
      label: 'Trắc nghiệm',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b.body ?? '', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (var i = 0; i < b.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionTile(
              text: b.options[i],
              letter: String.fromCharCode(65 + i),
              color: _picked == null
                  ? null
                  : i == correct
                      ? Colors.green.shade600
                      : i == _picked
                          ? Colors.red.shade600
                          : null,
              onTap: _picked != null
                  ? null
                  : () {
                      setState(() => _picked = i);
                      widget.onAnswered(i == correct, b.options[i], b.options[correct]);
                    },
              outline: cs.outlineVariant,
            ),
          ),
        if (_picked != null)
          AnswerFeedback(
            correct: _picked == correct,
            explanation: b.explanation,
            onTutor: widget.onTutor == null ? null : () => widget.onTutor!(b.options[_picked!], b.options[correct]),
          ),
        if (_picked != null) SourceNote(block: b),
      ]),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.text, required this.letter, required this.onTap, required this.outline, this.color});
  final String text, letter;
  final VoidCallback? onTap;
  final Color? color;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color?.withValues(alpha: 0.12) ?? Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color ?? outline, width: color == null ? 1 : 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              CircleAvatar(radius: 13, child: Text(letter, style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Dung / sai.
class TrueFalseBlock extends StatefulWidget {
  const TrueFalseBlock({super.key, required this.block, required this.onAnswered, this.onTutor});
  final Block block;
  final OnAnswered onAnswered;
  final void Function(String chosen, String correct)? onTutor;
  @override
  State<TrueFalseBlock> createState() => _TrueFalseBlockState();
}

class _TrueFalseBlockState extends State<TrueFalseBlock> {
  bool? _picked;

  String _label(bool v) => v ? 'Đúng' : 'Sai';

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final answer = b.answerBool ?? true;
    Widget btn(bool v) => Expanded(
          child: SizedBox(
            height: 56,
            child: _picked == null
                ? OutlinedButton(
                    onPressed: () {
                      setState(() => _picked = v);
                      widget.onAnswered(v == answer, _label(v), _label(answer));
                    },
                    child: Text(_label(v), style: const TextStyle(fontSize: 16)),
                  )
                : FilledButton(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: v == answer
                          ? Colors.green.shade600
                          : v == _picked
                              ? Colors.red.shade600
                              : null,
                      disabledForegroundColor: Colors.white,
                    ),
                    child: Text(_label(v), style: const TextStyle(fontSize: 16)),
                  ),
          ),
        );
    return BlockCard(
      icon: Icons.rule,
      label: 'Đúng hay sai?',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b.body ?? '', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(children: [btn(true), const SizedBox(width: 12), btn(false)]),
        if (_picked != null)
          AnswerFeedback(
            correct: _picked == answer,
            explanation: b.explanation,
            onTutor: widget.onTutor == null ? null : () => widget.onTutor!(_label(_picked!), _label(answer)),
          ),
        if (_picked != null) SourceNote(block: b),
      ]),
    );
  }
}

/// Dien khuyet: so khop sau khi chuan hoa chu thuong/khoang trang.
class FillBlankBlock extends StatefulWidget {
  const FillBlankBlock({super.key, required this.block, required this.onAnswered, this.onTutor});
  final Block block;
  final OnAnswered onAnswered;
  final void Function(String chosen, String correct)? onTutor;
  @override
  State<FillBlankBlock> createState() => _FillBlankBlockState();
}

class _FillBlankBlockState extends State<FillBlankBlock> {
  final _ctrl = TextEditingController();
  bool? _correct;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _check() {
    final input = _ctrl.text;
    if (input.trim().isEmpty) return;
    final ok = widget.block.answers.any((a) => normalize(a) == normalize(input));
    setState(() => _correct = ok);
    widget.onAnswered(ok, input, widget.block.answers.first);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    return BlockCard(
      icon: Icons.edit_note,
      label: 'Điền vào chỗ trống',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b.body ?? '', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: _correct == null,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _check(),
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Nhập đáp án'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _correct == null ? _check : null, child: const Text('Kiểm tra')),
        ]),
        if (_correct != null) ...[
          if (_correct == false)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Đáp án: ${b.answers.join(' / ')}')),
          AnswerFeedback(
            correct: _correct!,
            explanation: b.explanation,
            onTutor: widget.onTutor == null ? null : () => widget.onTutor!(_ctrl.text, b.answers.first),
          ),
          SourceNote(block: b),
        ],
      ]),
    );
  }
}
