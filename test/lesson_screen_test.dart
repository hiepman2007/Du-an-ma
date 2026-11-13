import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/data/sample_course.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/lesson_screen.dart';
import 'package:hoc_thong_minh/state/app_state.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
  for (final lessonId in ['l1', 'l3', 'l4']) {
    testWidgets(
      'Bài $lessonId của khóa mẫu hiển thị không lỗi trên màn điện thoại',
      (tester) async {
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

        final course = buildSampleCourse();
        final state = AppState()
          ..loaded = true
          ..role = UserRole.student
          ..courses.add(course);
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: state,
            child: MaterialApp(
              theme: buildTheme(),
              home: LessonScreen(courseId: course.id, lessonId: lessonId),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final lesson = course.lessons.firstWhere(
          (lesson) => lesson.id == lessonId,
        );
        final stepCount = lesson.blocks!.length;
        for (var step = 1; step < stepCount; step++) {
          await tester.tap(find.text('Bước tiếp'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Bước ${step + 1}/$stepCount'),
            findsOneWidget,
          );
        }

        final list = find.byType(ListView).first;
        for (var i = 0; i < 40; i++) {
          await tester.drag(list, const Offset(0, -400));
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();

        expect(errors, isEmpty, reason: errors.join('\n----\n'));
        expect(find.text('Sinh thêm 5 câu'), findsOneWidget);

        await tester.tap(find.text('Hoàn thành bài'));
        await tester.pumpAndSettle();
        expect(lesson.isDone, isTrue);
        expect(find.text('Đã hoàn thành'), findsOneWidget);
      },
    );
  }

  testWidgets('Mở lại đúng bước đã lưu và giữ trạng thái hoàn thành', (
    tester,
  ) async {
    final course = Course(
      id: 'course',
      title: 'DSA',
      goal: 'Học nền tảng',
      createdAt: DateTime(2026, 11, 13),
      lessons: [
        Lesson(
          id: 'intro',
          title: 'Mảng',
          stepIndex: 1,
          completed: true,
          lastStudiedAt: DateTime(2026, 11, 13),
          blocks: Block.parseList([
            {
              'type': 'text_section',
              'title': 'Giải thích',
              'body': 'Mỗi phần tử có chỉ số.',
            },
            {
              'type': 'text_section',
              'title': 'Ví dụ',
              'body': 'Phần tử đầu có chỉ số 0.',
            },
          ]),
        ),
      ],
    );
    final state = AppState()..courses.add(course);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildTheme(),
          home: const LessonScreen(courseId: 'course', lessonId: 'intro'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Bước 2/2'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsOneWidget);
    await tester.tap(find.byTooltip('Bước trước'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Bước 1/2'), findsOneWidget);
    expect(course.lessons.single.stepIndex, 0);
    expect(course.lessons.single.isDone, isTrue);
  });
}
