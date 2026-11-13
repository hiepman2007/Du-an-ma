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
    testWidgets('Bài $lessonId của khóa mẫu hiển thị không lỗi trên màn điện thoại', (tester) async {
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
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(theme: buildTheme(), home: LessonScreen(courseId: course.id, lessonId: lessonId)),
      ));
      await tester.pumpAndSettle();

      // Cuon het bai de dung tung khoi (bo may, bo de luyen o cuoi).
      final list = find.byType(ListView).first;
      for (var i = 0; i < 40; i++) {
        await tester.drag(list, const Offset(0, -400));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(errors, isEmpty, reason: errors.join('\n----\n'));
      expect(find.text('Sinh thêm 5 câu'), findsOneWidget);
    });
  }
}
