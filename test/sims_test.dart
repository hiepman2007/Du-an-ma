import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/lab_screen.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:hoc_thong_minh/widgets/blocks/phenomenon_block.dart';
import 'package:hoc_thong_minh/widgets/sims/phenomenon_sim.dart';
import 'package:hoc_thong_minh/widgets/sims/sim_catalog.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _phone(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(375, 812) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: Scaffold(body: child)));
  await tester.pump();
}

void main() {
  for (final scene in simCatalog.values) {
    testWidgets('Cảnh ${scene.id}: dựng, chạy, đổi thanh trượt không lỗi', (tester) async {
      await _phone(tester, ListView(padding: const EdgeInsets.all(16), children: [PhenomenonSim(scene: scene)]));
      expect(tester.takeException(), isNull);
      final before = scene.model.readouts.call;
      expect(before, isNotNull);
      if (scene.model.animated) {
        await tester.tap(find.byTooltip('Chạy'));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(tester.takeException(), isNull);
      }
      for (final option in scene.options.skip(1)) {
        await tester.ensureVisible(find.text(option.$2));
        await tester.tap(find.text(option.$2));
        await tester.pump(const Duration(milliseconds: 50));
      }
      final slider = find.byKey(ValueKey('sim-${scene.id}-${scene.vars.first.name}'));
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(80, 0));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      if (scene.model.animated && find.byTooltip('Dừng').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('Dừng'));
        await tester.pump();
      }
    });
  }

  testWidgets('Khúc xạ: tăng góc tới từ thủy tinh ra không khí thì phản xạ toàn phần', (tester) async {
    await _phone(tester, ListView(children: [PhenomenonSim(scene: simCatalog['refraction']!)]));
    expect(find.textContaining('Phản xạ toàn phần'), findsNothing);
    final slider = find.byKey(const ValueKey('sim-refraction-angle'));
    await tester.ensureVisible(slider);
    await tester.drag(slider, const Offset(400, 0));
    await tester.pump();
    expect(find.textContaining('phản xạ toàn phần'), findsOneWidget);
  });

  testWidgets('Khối AI phenomenon_sim dùng thông số AI và câu thử thách riêng', (tester) async {
    final block = Block.tryParse({
      'type': 'phenomenon_sim', 'topic': 'Ohm', 'title': 'Thử mạch song song',
      'phenomenon': {'scene': 'circuit', 'option': 'parallel', 'challenges': ['Tháo bớt một đèn xem sao'],
        'variables': [{'name': 'U', 'label': 'U', 'unit': 'V', 'min': 0, 'max': 12, 'step': 1, 'default': 12}]},
    })!;
    await _phone(tester, ListView(children: [PhenomenonBlock(block: block)]));
    expect(find.text('Thử mạch song song'), findsOneWidget);
    expect(find.text('Tháo bớt một đèn xem sao'), findsOneWidget);
    expect(find.textContaining('Cường độ mạch chính'), findsOneWidget);
    expect(find.text('12 V'), findsOneWidget);
  });

  testWidgets('Phòng thí nghiệm liệt kê đủ cảnh và mở được một cảnh', (tester) async {
    tester.view.physicalSize = const Size(375, 812) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const LabScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Mạch điện và định luật Ohm'), findsOneWidget);
    await tester.tap(find.text('Mạch điện và định luật Ohm'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Chạy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
