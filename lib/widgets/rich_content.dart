import 'package:flutter_math_fork/flutter_math.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Doan noi dung do AI sinh: markdown don gian + cong thuc LaTeX.
/// - Trong dong: $...$ hoac \( ... \)
/// - Rieng dong: $$...$$ hoac \[ ... \]
/// - Markdown: tieu de (#), danh sach (-, *, 1.), **dam**, *nghieng*, `code`, khoi ``` code ```
/// Cong thuc loi cu phap thi hien chu goc, khong lam vo giao dien.
class RichContent extends StatelessWidget {
  const RichContent(this.data, {super.key, this.style, this.textAlign = TextAlign.start});
  final String data;
  final TextStyle? style;
  final TextAlign textAlign;

  static final _blockRe = RegExp(r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]|```(\w*)\n?([\s\S]*?)```');
  static final _inlineRe = RegExp(r'\$([^\$\n]+?)\$|\\\((.+?)\\\)|\*\*(.+?)\*\*|(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])|`([^`]+)`');

  /// Tach thanh cac doan: ('text'|'math'|'code', noi dung, ngon ngu code).
  static List<(String, String, String)> segments(String s) {
    final out = <(String, String, String)>[];
    var last = 0;
    for (final m in _blockRe.allMatches(s)) {
      if (m.start > last) out.add(('text', s.substring(last, m.start), ''));
      if (m.group(1) != null || m.group(2) != null) {
        out.add(('math', (m.group(1) ?? m.group(2))!.trim(), ''));
      } else {
        out.add(('code', m.group(4) ?? '', m.group(3) ?? ''));
      }
      last = m.end;
    }
    if (last < s.length) out.add(('text', s.substring(last), ''));
    return out;
  }

  static Widget math(String tex, TextStyle style, {bool display = false}) => Math.tex(
        tex,
        mathStyle: display ? MathStyle.display : MathStyle.text,
        textStyle: style,
        onErrorFallback: (_) => Text(display ? '\$\$$tex\$\$' : '\$$tex\$', style: style),
      );

  List<InlineSpan> _spans(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineRe.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      final tex = m.group(1) ?? m.group(2);
      if (tex != null) {
        spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: math(tex.trim(), base)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(children: _spans(m.group(3)!, base), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(text: m.group(4), style: const TextStyle(fontStyle: FontStyle.italic)));
      } else {
        spans.add(TextSpan(
          text: m.group(5),
          style: const TextStyle(fontFamily: 'monospace', backgroundColor: Color(0xFFF2F2F2)),
        ));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  Widget _rich(String text, TextStyle style) =>
      Text.rich(TextSpan(children: _spans(text, style)), style: style, textAlign: textAlign);

  List<Widget> _textLines(String block, TextStyle base, TextTheme theme) {
    final children = <Widget>[];
    final lines = block.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        if (i > 0 && i < lines.length - 1) children.add(const SizedBox(height: 6));
        continue;
      }
      final h = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(line);
      final bullet = RegExp(r'^\s*[-*•]\s+(.*)$').firstMatch(line);
      final numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(line);
      if (h != null) {
        final st = (h.group(1)!.length <= 2 ? theme.titleMedium : theme.titleSmall)?.copyWith(fontWeight: FontWeight.w800) ?? base;
        children.add(Padding(padding: const EdgeInsets.only(top: 6, bottom: 2), child: _rich(h.group(2)!, st)));
      } else if (bullet != null || numbered != null) {
        final marker = bullet != null ? '•' : '${numbered!.group(1)}.';
        final text = bullet != null ? bullet.group(1)! : numbered!.group(2)!;
        children.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 22, child: Text(marker, style: base)),
            Expanded(child: _rich(text, base)),
          ]),
        ));
      } else {
        children.add(_rich(line, base));
      }
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final base = style ?? (theme.bodyLarge ?? const TextStyle()).copyWith(fontSize: 15, height: 1.5, color: AppColors.foreground);
    final children = <Widget>[];
    for (final (kind, content, lang) in segments(data)) {
      switch (kind) {
        case 'math':
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(
              child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: math(content, base.copyWith(fontSize: (base.fontSize ?? 15) + 2), display: true)),
            ),
          ));
        case 'code':
          children.add(CodeView(code: content, language: lang));
        default:
          children.addAll(_textLines(content, base, theme));
      }
    }
    if (children.length == 1) return children.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }
}

/// Khoi code: nen toi, chu don sac, to mau tu khoa co ban, cuon ngang.
class CodeView extends StatelessWidget {
  const CodeView({super.key, required this.code, this.language = ''});
  final String code, language;

  static final _kw = RegExp(
      r'\b(def|return|if|elif|else|for|while|in|import|from|class|function|const|let|var|int|float|double|void|public|private|static|new|true|false|True|False|None|null|print|printf|include|using|namespace|struct|break|continue|and|or|not)\b');
  static final _str = RegExp(r'''("[^"\n]*"|'[^'\n]*')''');
  static final _comment = RegExp(r'(#.*$|//.*$)', multiLine: true);
  static final _num = RegExp(r'\b\d+(\.\d+)?\b');

  List<TextSpan> _highlight(String src) {
    // Gan mau theo thu tu uu tien: chu thich > chuoi > tu khoa > so.
    final colors = List<Color?>.filled(src.length, null);
    void paint(RegExp re, Color c) {
      for (final m in re.allMatches(src)) {
        for (var i = m.start; i < m.end; i++) {
          colors[i] ??= c;
        }
      }
    }

    paint(_comment, const Color(0xFF7F8C98));
    paint(_str, const Color(0xFFB5E3A1));
    paint(_kw, const Color(0xFFFF8A94));
    paint(_num, const Color(0xFFF7C873));
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= src.length; i++) {
      if (i == src.length || colors[i] != colors[start]) {
        spans.add(TextSpan(text: src.substring(start, i), style: TextStyle(color: colors[start] ?? const Color(0xFFECEFF4))));
        start = i;
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF1F2328), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (language.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(language, style: const TextStyle(color: Color(0xFF9AA4AE), fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Text.rich(
            TextSpan(children: _highlight(code.trimRight())),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
          ),
        ),
      ]),
    );
  }
}
