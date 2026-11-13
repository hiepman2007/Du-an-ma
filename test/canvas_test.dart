import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/canvas_screen.dart';
import 'package:hoc_thong_minh/services/api_client.dart';
import 'package:hoc_thong_minh/services/storage.dart';
import 'package:hoc_thong_minh/state/app_state.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:hoc_thong_minh/widgets/canvas_preview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class _Store extends Storage {
  Map<String, dynamic> value = {};

  @override
  Future<Map<String, dynamic>> load() async => value;

  @override
  Future<void> save(Map<String, dynamic> data) async => value = data;
}

class _Api extends ApiClient {
  final bodies = <Map<String, dynamic>>[];
  bool fail = true;

  @override
  Future<Map<String, dynamic>> simulation(Map<String, dynamic> body) async {
    bodies.add(body);
    if (fail) {
      fail = false;
      throw ApiException('AI chưa tạo được mô phỏng an toàn, hãy thử lại', status: 502);
    }
    final revised = body['previousHtml'] != null;
    return {
      'title': 'Con lắc đơn',
      'instructions': revised ? 'Đã thêm ma sát.' : 'Kéo chiều dài dây.',
      'html': revised ? '<body><h1>Con lắc có ma sát</h1></body>' : '<body><h1>Con lắc</h1></body>',
    };
  }
}

void main() {
  setUp(() => CanvasPreview.debugBuilder = (html) => Text(html.contains('ma sát') ? 'XEM TRƯỚC v2' : 'XEM TRƯỚC v1'));
  tearDown(() => CanvasPreview.debugBuilder = null);

  testWidgets('Canvas: tạo từ mô tả, sửa thành phiên bản mới, quay lại bản cũ, xem mã', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = _Api();
    final course = Course(id: 'ly', title: 'Vật lý 10', goal: 'Ôn thi', createdAt: DateTime(2026, 11, 13),
        lessons: [Lesson(id: 'dao-dong', title: 'Dao động', objectives: const ['Chu kỳ con lắc'])]);
    final state = AppState(api: api, storage: _Store())..courses.add(course);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: buildTheme(), home: const CanvasScreen(
        courseId: 'ly', lessonId: 'dao-dong', initialPrompt: 'Con lắc đơn kéo chiều dài')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bạn muốn dựng mô phỏng gì?'), findsOneWidget);
    await tester.tap(find.text('Tạo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('XEM TRƯỚC v1'), findsOneWidget);
    expect(find.text('v1'), findsOneWidget);
    expect(api.bodies.last['lessonTitle'], 'Dao động');
    expect(api.bodies.last['simPrompt'], 'Con lắc đơn kéo chiều dài');

    await tester.enterText(find.byType(TextField), 'Thêm ma sát');
    await tester.tap(find.byTooltip('Gửi yêu cầu sửa'));
    await tester.pumpAndSettle();
    expect(api.bodies.last['previousHtml'], '<body><h1>Con lắc</h1></body>');
    expect(find.text('XEM TRƯỚC v2'), findsOneWidget);
    expect(find.text('Đã thêm ma sát.'), findsOneWidget);
    final canvas = course.artifacts.single;
    expect((canvas.kind, canvas.blocks.length, canvas.lessonId), (StudyArtifactKind.canvas, 2, 'dao-dong'));

    await tester.tap(find.text('v1'));
    await tester.pumpAndSettle();
    expect(find.text('XEM TRƯỚC v1'), findsOneWidget);
    expect(find.text('Sửa tiếp từ v1 (bản mới sẽ là v3)'), findsOneWidget);

    await tester.tap(find.byTooltip('Xem mã'));
    await tester.pumpAndSettle();
    expect(find.text('<body><h1>Con lắc</h1></body>'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final reloaded = StudyArtifact.fromJson(canvas.toJson());
    expect(reloaded.blocks[1].sim?['html'], contains('ma sát'));
  });
}
