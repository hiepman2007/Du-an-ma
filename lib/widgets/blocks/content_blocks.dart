import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../simple_markdown.dart';
import 'common.dart';

class TextSectionBlock extends StatelessWidget {
  const TextSectionBlock({super.key, required this.block});
  final Block block;

  @override
  Widget build(BuildContext context) {
    return BlockCard(
      icon: Icons.menu_book_outlined,
      label: 'Bài giảng',
      title: block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SimpleMarkdown(block.body ?? ''),
        SourceNote(block: block),
      ]),
    );
  }
}

/// The ghi nho: cham de lat, vuot de qua the.
class FlashcardsBlock extends StatefulWidget {
  const FlashcardsBlock({super.key, required this.block});
  final Block block;
  @override
  State<FlashcardsBlock> createState() => _FlashcardsBlockState();
}

class _FlashcardsBlockState extends State<FlashcardsBlock> {
  final Set<int> _flipped = {};
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final cards = widget.block.cards;
    final cs = Theme.of(context).colorScheme;
    return BlockCard(
      icon: Icons.style_outlined,
      label: 'Thẻ ghi nhớ',
      title: widget.block.title,
      child: Column(children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            itemCount: cards.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (_, i) {
              final back = _flipped.contains(i);
              return GestureDetector(
                onTap: () => setState(() => back ? _flipped.remove(i) : _flipped.add(i)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: back ? cs.tertiaryContainer : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(back ? cards[i].$2 : cards[i].$1,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: back ? 15 : 19, fontWeight: back ? FontWeight.w400 : FontWeight.w700)),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text('Thẻ ${_page + 1}/${cards.length} · chạm để lật, vuốt để qua thẻ', style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}
