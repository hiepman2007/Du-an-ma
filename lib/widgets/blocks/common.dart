import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../theme.dart';

/// Ham goi lai khi nguoi hoc tra loi mot khoi co cham diem.
typedef OnAnswered = void Function(bool correct, String chosen, String correctText);

class BlockCard extends StatelessWidget {
  const BlockCard({super.key, required this.icon, required this.label, required this.child, this.title});
  final IconData icon;
  final String label;
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 16, color: cs.primary),
              const SizedBox(width: 6),
              Eyebrow(label),
            ]),
            if (title != null && title!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(title!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Trich dan nguon: trang PDF hoac link web (bam de mo).
class SourceNote extends StatelessWidget {
  const SourceNote({super.key, required this.block});
  final Block block;

  @override
  Widget build(BuildContext context) {
    final quote = block.sourceQuote;
    final page = block.sourcePage;
    final url = block.sourceUrl;
    if ((quote == null || quote.isEmpty) && page == null && url == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final where = [
      if (page != null) 'Trang $page',
      if (url != null) Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? url,
    ].join(' · ');
    return InkWell(
      onTap: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(url != null ? Icons.link : Icons.menu_book_outlined, size: 16, color: cs.onSecondaryContainer),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Nguồn${where.isEmpty ? '' : ': $where'}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
            ),
          ]),
          if (quote != null && quote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('“$quote”', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: cs.onSecondaryContainer)),
            ),
        ]),
      ),
    );
  }
}

/// Phan hoi sau khi tra loi: dung/sai + giai thich.
class AnswerFeedback extends StatelessWidget {
  const AnswerFeedback({super.key, required this.correct, this.explanation, this.onTutor});
  final bool correct;
  final String? explanation;
  final VoidCallback? onTutor;

  @override
  Widget build(BuildContext context) {
    final color = correct ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(correct ? Icons.check_circle : Icons.cancel, color: color),
          const SizedBox(width: 8),
          Text(correct ? 'Chính xác!' : 'Chưa đúng', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ]),
        if (correct && explanation != null && explanation!.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(explanation!)),
        if (!correct && onTutor != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FilledButton.tonalIcon(
              onPressed: onTutor,
              icon: const Icon(Icons.psychology_alt_outlined),
              label: const Text('Gia sư AI gợi ý'),
            ),
          ),
      ]),
    );
  }
}
