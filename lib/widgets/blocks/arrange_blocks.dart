import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import 'common.dart';

/// Ghep cap: cham ben trai roi cham ben phai. Ben phai duoc xao tron.
class MatchingBlock extends StatefulWidget {
  const MatchingBlock({super.key, required this.block, required this.onAnswered});
  final Block block;
  final OnAnswered onAnswered;
  @override
  State<MatchingBlock> createState() => _MatchingBlockState();
}

class _MatchingBlockState extends State<MatchingBlock> {
  late final List<int> _rightOrder;
  final Map<int, int> _matched = {}; // left index -> right index
  int? _left;
  int _mistakes = 0;
  int? _wrongFlash;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _rightOrder = List.generate(widget.block.pairs.length, (i) => i)..shuffle(Random(widget.block.pairs.length * 7 + 3));
  }

  void _tapRight(int r) {
    final l = _left;
    if (l == null || _matched.containsValue(r)) return;
    if (l == r) {
      setState(() {
        _matched[l] = r;
        _left = null;
      });
      if (_matched.length == widget.block.pairs.length && !_reported) {
        _reported = true;
        widget.onAnswered(_mistakes == 0, 'Ghép sai $_mistakes lần', 'Ghép đúng tất cả');
      }
    } else {
      setState(() {
        _mistakes++;
        _wrongFlash = r;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _wrongFlash = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = widget.block.pairs;
    final cs = Theme.of(context).colorScheme;
    Widget chip(String text, {required bool done, required bool selected, bool wrong = false, VoidCallback? onTap}) {
      final bg = done
          ? Colors.green.withValues(alpha: 0.15)
          : wrong
              ? Colors.red.withValues(alpha: 0.15)
              : selected
                  ? cs.primaryContainer
                  : cs.surface;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: bg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? cs.primary : cs.outlineVariant)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: done ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(padding: const EdgeInsets.all(10), child: Center(child: Text(text, textAlign: TextAlign.center))),
            ),
          ),
        ),
      );
    }

    return BlockCard(
      icon: Icons.link,
      label: 'Ghép cặp',
      title: widget.block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.block.body?.isNotEmpty == true ? widget.block.body! : 'Chạm một mục bên trái, rồi chạm mục tương ứng bên phải.'),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(children: [
              for (var i = 0; i < pairs.length; i++)
                chip(pairs[i].$1,
                    done: _matched.containsKey(i), selected: _left == i, onTap: () => setState(() => _left = i)),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(children: [
              for (final r in _rightOrder)
                chip(pairs[r].$2,
                    done: _matched.containsValue(r), selected: false, wrong: _wrongFlash == r, onTap: () => _tapRight(r)),
            ]),
          ),
        ]),
        if (_reported) AnswerFeedback(correct: _mistakes == 0, explanation: widget.block.explanation),
      ]),
    );
  }
}

/// Sap xep thu tu: keo tha, bam Kiem tra.
class OrderingBlock extends StatefulWidget {
  const OrderingBlock({super.key, required this.block, required this.onAnswered});
  final Block block;
  final OnAnswered onAnswered;
  @override
  State<OrderingBlock> createState() => _OrderingBlockState();
}

class _OrderingBlockState extends State<OrderingBlock> {
  late List<String> _items;
  bool? _correct;

  @override
  void initState() {
    super.initState();
    _items = [...widget.block.items];
    final rnd = Random(_items.length * 13 + 1);
    // Xao tron cho den khi khac thu tu dung.
    for (var t = 0; t < 10; t++) {
      _items.shuffle(rnd);
      if (!_same()) break;
    }
  }

  bool _same() {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i] != widget.block.items[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlockCard(
      icon: Icons.swap_vert,
      label: 'Sắp xếp thứ tự',
      title: widget.block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.block.body?.isNotEmpty == true ? widget.block.body! : 'Giữ và kéo để sắp xếp đúng thứ tự.'),
        const SizedBox(height: 8),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: _correct == null,
          onReorderItem: (o, n) => setState(() => _items.insert(n, _items.removeAt(o))),
          children: [
            for (var i = 0; i < _items.length; i++)
              Card(
                key: ValueKey(_items[i]),
                elevation: 0,
                color: _correct == null
                    ? cs.surface
                    : _items[i] == widget.block.items[i]
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                child: ListTile(
                  leading: CircleAvatar(radius: 14, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  title: Text(_items[i]),
                  trailing: _correct == null ? const Icon(Icons.drag_handle) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_correct == null)
          FilledButton(
            onPressed: () {
              final ok = _same();
              setState(() => _correct = ok);
              widget.onAnswered(ok, _items.join(' → '), widget.block.items.join(' → '));
            },
            child: const Text('Kiểm tra'),
          )
        else ...[
          if (_correct == false) Text('Thứ tự đúng: ${widget.block.items.join(' → ')}'),
          AnswerFeedback(correct: _correct!, explanation: widget.block.explanation),
        ],
      ]),
    );
  }
}
