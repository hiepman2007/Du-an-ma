import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/tutor_chat_screen.dart';
import 'package:hoc_thong_minh/state/app_state.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Màn gia sư hiển thị câu trả lời nhiều khối (LaTeX, code, đồ thị) cỡ điện thoại', (tester) async {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final lesson = Lesson(id: 'l1', title: 'Hàm số bậc hai')
      ..chat.addAll([
        ChatMessage(fromUser: true, text: 'Đỉnh parabol nằm ở đâu?'),
        ChatMessage(fromUser: false, blocks: Block.parseList([
          {
            'type': 'text_section',
            'topic': 'Đỉnh parabol',
            'body': r'Đỉnh của $y = ax^2 + bx + c$ có hoành độ:' '\n' r'$$x_0 = -\frac{b}{2a}$$' '\n' '- Nếu **a > 0** thì đỉnh là điểm thấp nhất.',
          },
          {
            'type': 'code_demo',
            'topic': 'Tính đỉnh',
            'body': 'Tính đỉnh bằng Python:',
            'code': {'language': 'python', 'source': 'a, b = 1, -4\nprint(-b / (2 * a))  # 2.0', 'output': '2.0'},
          },
          {
            'type': 'function_graph',
            'topic': 'Đỉnh parabol',
            'title': 'Kéo b để thấy đỉnh dịch chuyển',
            'graph': {
              'expression': 'x^2+b*x',
              'extra_expressions': [],
              'x_min': -5,
              'x_max': 5,
              'tools': ['extrema'],
              'params': [
                {'name': 'b', 'label': 'b', 'unit': '', 'min': -4, 'max': 4, 'step': 1, 'default': -4},
              ],
            },
          },
          {'type': 'true_false', 'topic': 'Đỉnh parabol', 'body': r'Với $a < 0$, đỉnh là điểm cao nhất.', 'answer_bool': true},
        ]), webMode: 'wikipedia', web: [
          WebSource(title: 'Parabol (hình học) – bài viết rất dài để thử tràn dòng', url: 'https://vi.wikipedia.org/wiki/Parabol', domain: 'vi.wikipedia.org', snippet: '', trusted: true),
          WebSource(title: 'Blog toán', url: 'https://example.com/a', domain: 'example.com', snippet: '', trusted: false),
        ]),
      ]);
    final state = AppState()
      ..loaded = true
      ..role = UserRole.student
      ..courses.add(Course(id: 'c1', title: 'Toán 10', goal: 'Ôn thi', createdAt: DateTime(2026, 11, 13), lessons: [lesson]));

    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add(d.toString());
      previous?.call(d);
    };
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: buildTheme(), home: const TutorChatScreen(courseId: 'c1', lessonId: 'l1')),
    ));
    await tester.pumpAndSettle();

    expect(errors, isEmpty, reason: errors.join('\n----\n'));
    expect(tester.takeException(), isNull);
    expect(find.text('Gia sư AI'), findsWidgets);
    expect(find.text('Đỉnh parabol nằm ở đâu?'), findsOneWidget);
    expect(find.text('Code minh họa'.toUpperCase()), findsOneWidget);
    expect(find.text('Khám phá hàm số'.toUpperCase()), findsOneWidget);

    // Tra loi cau dung/sai trong chat khong lam hong man hinh.
    await tester.dragUntilVisible(find.text('Đúng'), find.byType(ListView).first, const Offset(0, -250));
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đúng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Chính xác!'), findsOneWidget);
  });
}
