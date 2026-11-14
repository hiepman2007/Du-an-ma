import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/screens/home_screen.dart';
import 'package:hoc_thong_minh/screens/home_shell.dart';
import 'package:hoc_thong_minh/screens/match_game_screen.dart';
import 'package:hoc_thong_minh/services/intent.dart';
import 'package:hoc_thong_minh/services/storage.dart';
import 'package:hoc_thong_minh/services/topic_images.dart';
import 'package:hoc_thong_minh/state/app_state.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class _Store extends Storage {
  Map<String, dynamic> value = {};
  @override
  Future<Map<String, dynamic>> load() async => value;
  @override
  Future<void> save(Map<String, dynamic> data) async => value = data;
}

class _NoImages extends TopicImages {
  @override
  Future<String?> lookup(String topic, {String subject = ''}) async => null;
}

Future<AppState> _pump(WidgetTester tester, Size size, {String sample = 'sample-dsa', Widget home = const NotebookScreen()}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final state = AppState(storage: _Store(), images: _NoImages());
  await state.load();
  await state.openStudySample(sample);
  await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: MaterialApp(theme: buildTheme(), home: home)));
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('Trang chủ: thống kê, linh vật, sổ học và thí nghiệm, không tràn', (tester) async {
    await _pump(tester, const Size(375, 812), home: const HomeScreen());
    expect(find.text('ngày liên tiếp'), findsOneWidget);
    expect(find.text('Hỏi hoặc giao việc cho AI…'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final notebook = find.byKey(const ValueKey('notebook-sample-dsa'));
    await tester.scrollUntilVisible(notebook, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(notebook);
    await tester.pumpAndSettle();
    expect(find.text('Studio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sổ học kiểu NotebookLM: 3 tab Nguồn, Chat, Studio; ô Studio mở được mọi trang', (tester) async {
    await _pump(tester, const Size(375, 812));
    await tester.tap(find.text('Studio'));
    await tester.pumpAndSettle();
    for (final (page, _) in StudioPanel.tools) {
      final tile = find.descendant(of: find.byType(StudioPanel), matching: find.text(page.label));
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: page.label);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Nguồn'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Lộ trình: chặng có kiểm tra nhanh và bảng chi tiết bài', (tester) async {
    final state = await _pump(tester, const Size(375, 812));
    final context = tester.element(find.byType(NotebookScreen));
    openStudyPage(context, state.selectedCourse!, StudyPage.plan);
    await tester.pumpAndSettle();
    expect(find.text('Tiến độ'), findsOneWidget);
    expect(find.text('Kiểm tra nhanh'), findsOneWidget);
    await tester.ensureVisible(find.text('Tìm kiếm nhị phân').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm kiếm nhị phân').last);
    await tester.pumpAndSettle();
    expect(find.text('Học bài này'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sổ học: một thanh tiêu đề, chip công cụ trên ô chat mở được lộ trình', (tester) async {
    await _pump(tester, const Size(375, 812));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Gia sư AI'), findsNothing); // khong con thanh tieu de thu hai
    await tester.tap(find.widgetWithText(ActionChip, 'Lộ trình'));
    await tester.pumpAndSettle();
    expect(find.text('Tiến độ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Màn rộng: 3 cột, không có thanh tab dưới', (tester) async {
    await _pump(tester, const Size(1280, 800));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(StudioPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Nhận diện ý định từ câu chat', () {
    expect(detectIntent('Lập lộ trình ôn Vật lý 12'), ChatIntent.plan);
    expect(detectIntent('tạo quiz về định luật Ohm'), ChatIntent.quiz);
    expect(detectIntent('cho mình làm thí nghiệm khúc xạ'), ChatIntent.lab);
    expect(detectIntent('vì sao trời xanh'), ChatIntent.none);
    expect(detectIntent('Quang hợp diễn ra thế nào?'), ChatIntent.none);
    expect(detectIntent('tài liệu mac le nin'), ChatIntent.research);
    expect(detectIntent('Tìm nguồn và lên lộ trình cho môn Xác suất'), ChatIntent.plan);
    expect(wantsWeb('tra mạng đi'), isTrue);
    expect(wantsWeb('tìm trên mạng giúp mình'), isTrue);
    expect(wantsWeb('giải thích định luật Ohm'), isFalse);
  });

  testWidgets('Ghép nhanh: ghép đúng hết thì ghi kỷ lục', (tester) async {
    final state = await _pump(tester, const Size(375, 812), sample: 'sample-ohm');
    final course = state.selectedCourse!;
    final pairs = MatchGameScreen.pairsFrom(course);
    expect(pairs.length, greaterThanOrEqualTo(6));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: state, child: MaterialApp(theme: buildTheme(), home: MatchGameScreen(courseId: course.id, seed: 1))));
    await tester.pumpAndSettle();
    for (final (left, right) in pairs) {
      if (find.text(left).evaluate().isEmpty) continue;
      await tester.tap(find.text(left));
      await tester.pump();
      await tester.tap(find.text(right));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Kỷ lục mới!'), findsOneWidget);
    expect(course.bestMatchMs, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
