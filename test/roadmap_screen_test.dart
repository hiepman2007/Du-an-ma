import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/data/sample_course.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/roadmap_screen.dart';
import 'package:hoc_thong_minh/state/app_state.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:hoc_thong_minh/widgets/roadmap_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
  test('Lộ trình không ghi bài học trước thì nối thành đường thẳng và khóa bài sau', () {
    final lessons = [
      Lesson(id: 'a', title: 'A', completed: true),
      Lesson(id: 'b', title: 'B'),
      Lesson(id: 'c', title: 'C'),
    ];
    final graph = RoadmapGraph(lessons);
    expect(graph.prerequisitesOf(lessons[1]), ['a']);
    expect(graph.statusOf(lessons[0]), LessonStatus.done);
    expect(graph.statusOf(lessons[1]), LessonStatus.available);
    expect(graph.statusOf(lessons[2]), LessonStatus.locked);
    expect(graph.next(), lessons[1]);
  });

  test('Bài cùng độ sâu đứng cùng hàng, mức nắm vững tính từ kết quả câu hỏi', () {
    final lessons = [
      Lesson(id: 'a', title: 'A', phase: 'P'),
      Lesson(id: 'b', title: 'B', phase: 'P', prerequisites: const ['a']),
      Lesson(id: 'c', title: 'C', phase: 'P', prerequisites: const ['a'], results: {0: true, 1: false, 2: false}),
      Lesson(id: 'd', title: 'D', phase: 'P', prerequisites: const ['b', 'c'], results: {0: true, 1: true}),
    ];
    final graph = RoadmapGraph(lessons);
    final layout = RoadmapLayout(graph, roadmapPhases(lessons), 360);
    expect(layout.nodes['b']!.top, layout.nodes['c']!.top);
    expect(layout.nodes['d']!.top, greaterThan(layout.nodes['b']!.bottom));
    expect(needsReview(lessons[2]), isTrue);
    expect(isMastered(lessons[3]), isTrue);
  });

  testWidgets('Sơ đồ có trạng thái, bảng chi tiết bài và đánh dấu đã xong trên điện thoại', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final course = Course(
      id: 'dsa',
      title: 'Cấu trúc dữ liệu và giải thuật',
      goal: 'Ôn thi',
      createdAt: DateTime(2026, 11, 13),
      lessons: [
        Lesson(id: 'arrays', title: 'Mảng', phase: 'Nền tảng', completed: true),
        Lesson(id: 'list', title: 'Danh sách liên kết', phase: 'Nền tảng', prerequisites: const ['arrays']),
        Lesson(id: 'stack', title: 'Ngăn xếp', phase: 'Nền tảng', prerequisites: const ['arrays']),
        Lesson(id: 'queue', title: 'Hàng đợi', phase: 'Nền tảng', prerequisites: const ['arrays']),
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
        Lesson(id: 'bfs', title: 'Duyệt đồ thị BFS', phase: 'Thuật toán', prerequisites: const ['queue']),
      ],
    );
    final state = AppState()..courses.add(course);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: buildTheme(), home: const RoadmapScreen(courseId: 'dsa', showSources: false)),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Nền tảng'), findsOneWidget);
    expect(find.text('Thuật toán'), findsOneWidget);
    expect(find.text('Đã học 1/6 bài · Nắm vững 0'), findsOneWidget);
    expect(find.text('Chưa mở khóa'), findsWidgets);

    await tester.ensureVisible(find.text('Duyệt đồ thị BFS'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duyệt đồ thị BFS'));
    await tester.pumpAndSettle();
    expect(find.text('Cần học trước'), findsOneWidget);
    expect(find.textContaining('Nên học "Hàng đợi" trước'), findsOneWidget);
    await tester.tap(find.text('Đánh dấu đã xong'));
    await tester.pumpAndSettle();
    expect(course.lessons.last.completed, isTrue);
    expect(find.text('Bỏ đánh dấu đã xong'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Đã học 2/6 bài · Nắm vững 0'), findsOneWidget);

    await tester.ensureVisible(find.text('Tiếp tục học'));
    await tester.pumpAndSettle();
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
