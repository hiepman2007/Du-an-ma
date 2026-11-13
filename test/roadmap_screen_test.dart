import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/data/sample_course.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/roadmap_screen.dart';
import 'package:hoc_thong_minh/state/app_state.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
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
