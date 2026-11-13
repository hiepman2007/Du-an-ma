import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:hoc_thong_minh/widgets/study/dsa_simulation.dart';
import 'package:hoc_thong_minh/widgets/study/dsa_simulation_block.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('Tìm kiếm nhị phân thu hẹp khoảng và cho biết khi không tìm thấy', () {
    final data = {
      'algorithm': 'binary_search',
      'values': [1, 3, 5, 7, 9],
    };
    final hit = DsaSimulation.tryParse({...data, 'target': 9})!
        .binarySearchSteps();
    expect(hit.map((step) => (step.low, step.high, step.middle)), [
      (0, 4, 2),
      (3, 4, 3),
      (4, 4, 4),
    ]);
    expect(hit.last.comparison, 0);

    final miss = DsaSimulation.tryParse({...data, 'target': 8})!
        .binarySearchSteps();
    expect(miss.last.middle, isNull);
    expect(miss.last.low, greaterThan(miss.last.high));
    expect(
      DsaSimulation.tryParse({
        ...data,
        'values': [3, 1],
        'target': 1,
      }),
      isNull,
    );
    expect(
      DsaSimulation.tryParse({
        ...data,
        'values': List.filled(17, 1),
        'target': 1,
      }),
      isNull,
    );
  });

  test('BFS dùng hàng đợi, DFS dùng ngăn xếp và bỏ đỉnh không tới được', () {
    final data = {
      'nodes': ['A', 'B', 'C', 'D', 'E'],
      'edges': [
        ['A', 'B'],
        ['A', 'C'],
        {'from': 'B', 'to': 'D'},
        ['D', 'A'],
      ],
      'start': 'A',
      'directed': true,
    };
    final breadth = DsaSimulation.tryParse({...data, 'algorithm': 'bfs'})!
        .traversalSteps();
    final depth = DsaSimulation.tryParse({...data, 'algorithm': 'dfs'})!
        .traversalSteps();
    expect(breadth.first.pending, ['B', 'C']);
    expect(breadth.last.visited, ['A', 'B', 'C', 'D']);
    expect(depth.last.visited, ['A', 'B', 'D', 'C']);
    expect(
      DsaSimulation.tryParse({...data, 'algorithm': 'bfs', 'start': 'Z'}),
      isNull,
    );
  });

  testWidgets('Mô phỏng tiến, lùi và đặt lại từng bước', (tester) async {
    final block = Block.tryParse({
      'type': 'dsa_sim',
      'title': 'Tìm số 9',
      'dsa_sim': {
        'algorithm': 'binary_search',
        'values': [1, 3, 5, 7, 9],
        'target': 9,
      },
    })!;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(body: DsaSimulationBlock(block: block)),
      ),
    );

    expect(find.text('Bước mô phỏng 1/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Tiến bước mô phỏng'));
    await tester.pumpAndSettle();
    expect(find.text('Bước mô phỏng 2/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Lùi bước mô phỏng'));
    await tester.pumpAndSettle();
    expect(find.text('Bước mô phỏng 1/3'), findsOneWidget);
    await tester.tap(find.byTooltip('Chạy mô phỏng'));
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('Tìm thấy 9 ở chỉ số 4.'), findsOneWidget);
    await tester.tap(find.byTooltip('Đặt lại mô phỏng'));
    await tester.pumpAndSettle();
    expect(find.text('Bước mô phỏng 1/3'), findsOneWidget);
  });
}
