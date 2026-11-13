import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/data/sample_course.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/roadmap_screen.dart';
import 'package:hoc_thong_minh/state/app_state.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('Sơ đồ nối các chặng và tiếp tục bài gần nhất', (tester) async {
    tester.view.physicalSize = const Size(1024, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final course = Course(
      id: 'dsa',
      title: 'Cấu trúc dữ liệu và giải thuật',
      goal: 'Ôn thi',
      createdAt: DateTime(2026, 11, 13),
      lessons: [
        Lesson(id: 'arrays', title: 'Mảng', phase: 'Nền tảng', completed: true),
        Lesson(
          id: 'search',
          title: 'Tìm kiếm nhị phân',
          phase: 'Thuật toán',
          prerequisites: const ['arrays'],
          lastStudiedAt: DateTime(2026, 11, 13),
          blocks: Block.parseList([
            {'type': 'text_section', 'body': 'Giữ mảng đã sắp xếp.'},
            {'type': 'text_section', 'body': 'Thu hẹp khoảng tìm kiếm.'},
          ]),
          stepIndex: 1,
        ),
      ],
    );
    final state = AppState()..courses.add(course);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: buildTheme(), home: const RoadmapScreen(courseId: 'dsa')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Nền tảng'), findsOneWidget);
    expect(find.text('Thuật toán'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.text('Học trước Mảng'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục học'));
    await tester.pumpAndSettle();

    expect(find.text('Thu hẹp khoảng tìm kiếm.'), findsOneWidget);
    expect(find.textContaining('Bước 2/2'), findsOneWidget);
  });

  testWidgets('Khung Nguồn kiểu NotebookLM: tích bỏ chọn nguồn, bật tra cứu web', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add(d.toString());
      previous?.call(d);
    };
    addTearDown(() => FlutterError.onError = previous);

    final course = buildSampleCourse()
      ..sources.addAll([
        CourseSource(id: 'file:1', kind: SourceKind.file, title: 'Slide chương 3 - Phản ứng hóa học trong dung dịch.pdf', fileId: 'f1', mimeType: 'application/pdf'),
        CourseSource.fromWeb(WebSource(title: 'Quang hợp', url: 'https://vi.wikipedia.org/wiki/Quang_hợp', domain: 'vi.wikipedia.org', snippet: '', trusted: true)),
      ]);
    final state = AppState()
      ..loaded = true
      ..role = UserRole.student
      ..courses.add(course);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: buildTheme(), home: RoadmapScreen(courseId: course.id)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Nguồn (3/3'));
    await tester.pumpAndSettle();
    expect(find.text('Tìm nguồn trên mạng'), findsOneWidget);

    // Bo chon nguon web -> khong con gui len AI.
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(course.sources.last.enabled, isFalse);
    expect(course.materialJson().containsKey('sources'), isFalse);
    expect(find.textContaining('Nguồn (2/3'), findsOneWidget);

    // Bat tra cuu web (mac dinh tat).
    expect(course.allowWeb, isFalse);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(course.allowWeb, isTrue);

    expect(errors, isEmpty, reason: errors.join('\n----\n'));
  });
}
