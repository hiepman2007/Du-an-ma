import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/services/expr.dart';
import 'package:hoc_thong_minh/widgets/rich_content.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('Tách công thức riêng dòng và khối code', () {
    final s = RichContent.segments('Định luật:\n\$\$I = \\frac{U}{R}\$\$\nVí dụ code:\n```python\nprint(1)\n```\nHết');
    expect(s.map((e) => e.$1).toList(), ['text', 'math', 'text', 'code', 'text']);
    expect(s[1].$2, r'I = \frac{U}{R}');
    expect(s[3].$3, 'python');
  });

  test('Đổi biểu thức máy sang TeX', () {
    expect(exprToTex('a*x^2+b*x+c'), 'a x^{2}+b x+c');
    expect(exprToTex('U/R'), r'\frac{U}{R}');
    expect(exprToTex('sqrt(2*g*h)'), r'\sqrt{2 g h}');
  });

  testWidgets('Hiển thị LaTeX trong dòng, LaTeX lỗi không làm vỡ giao diện', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          RichContent(r'Công thức $I = \frac{U}{R}$ và **đậm**'),
          RichContent(r'Lỗi cú pháp $\frac{1}{$ vẫn hiện'),
          RichContent('Không có công thức, chi phí 5 USD'),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('vẫn hiện', findRichText: true), findsOneWidget);
  });
}
