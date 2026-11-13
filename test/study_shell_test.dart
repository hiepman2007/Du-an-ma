import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/screens/home_shell.dart';
import 'package:hoc_thong_minh/screens/match_game_screen.dart';
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

Future<AppState> _pump(WidgetTester tester, Size size, {String sample = 'sample-dsa'}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final state = AppState(storage: _Store(), images: _NoImages());
  await state.load();
  await state.openStudySample(sample);
  await tester.pumpWidget(ChangeNotifierProvider.value(value: state, child: MaterialApp(theme: buildTheme(), home: const HomeShell())));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _openFromDrawer(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('Open navigation menu'));
  await tester.pumpAndSettle();
  final item = find.descendant(of: find.byType(Drawer), matching: find.text(label));
  await tester.ensureVisible(item.first);
  await tester.tap(item.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Điện thoại: mọi trang trong thanh bên hiển thị không lỗi tràn', (tester) async {
    await _pump(tester, const Size(375, 812));
    expect(find.text('Tổng quan'), findsOneWidget);
    expect(find.text('Luyện tập & hoạt động'), findsOneWidget);
    for (final page in StudyPage.values.where((p) => p != StudyPage.dashboard)) {
      await _openFromDrawer(tester, page.label);
      expect(tester.takeException(), isNull, reason: page.label);
      expect(find.text(page.label), findsWidgets, reason: page.label);
    }
  });

  testWidgets('Lộ trình kiểu StudyFetch: chặng mở ra có kiểm tra nhanh và bảng chi tiết bài', (tester) async {
    await _pump(tester, const Size(375, 812));
    await _openFromDrawer(tester, 'Lộ trình');
    expect(find.text('Bắt đầu'), findsWidgets);
    expect(find.text('Tiến độ'), findsOneWidget);
    expect(find.text('Kiểm tra nhanh'), findsOneWidget);
    await tester.ensureVisible(find.text('Tìm kiếm nhị phân').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tìm kiếm nhị phân').last);
    await tester.pumpAndSettle();
    expect(find.text('Học bài này'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nút trợ lý AI mở khung chat và đóng lại được', (tester) async {
    await _pump(tester, const Size(375, 812));
    await tester.tap(find.byTooltip('Trợ lý AI'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay mình giúp gì cho bạn?'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng trợ lý'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay mình giúp gì cho bạn?'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Màn rộng: thanh bên cố định, không có ngăn kéo', (tester) async {
    await _pump(tester, const Size(1280, 800));
    expect(find.byTooltip('Open navigation menu'), findsNothing);
    await tester.tap(find.text('Lộ trình').first);
    await tester.pumpAndSettle();
    expect(find.text('Tiến độ'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
