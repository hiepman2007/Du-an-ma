import 'package:material_ui/material_ui.dart';

/// Hien thi markdown don gian do AI sinh: tieu de (#), danh sach (-, *, 1.), **dam**, *nghieng*.
class SimpleMarkdown extends StatelessWidget {
  const SimpleMarkdown(this.data, {super.key});
  final String data;

  static final _inline = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');

  List<InlineSpan> _spans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        spans.add(TextSpan(text: m.group(3), style: const TextStyle(fontFamily: 'monospace')));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final base = (theme.bodyLarge ?? const TextStyle()).copyWith(fontSize: 15, height: 1.5);
    final children = <Widget>[];
    for (final raw in data.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }
      final h = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*•]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (h != null) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text.rich(TextSpan(children: _spans(h.group(2)!, base)),
              style: (h.group(1)!.length <= 2 ? theme.titleMedium : theme.titleSmall)?.copyWith(fontWeight: FontWeight.w700)),
        ));
      } else if (bullet != null || numbered != null) {
        final marker = bullet != null ? '•' : '${numbered!.group(1)}.';
        final text = bullet != null ? bullet.group(1)! : numbered!.group(2)!;
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text(marker, style: base)),
            Expanded(child: Text.rich(TextSpan(children: _spans(text, base)), style: base)),
          ]),
        ));
      } else {
        children.add(Text.rich(TextSpan(children: _spans(line, base)), style: base));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
