import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/services/chem.dart';

void main() {
  test('Khối lượng mol và đếm nguyên tử', () {
    expect(molarMass('H2O'), closeTo(18.015, 0.01));
    expect(molarMass('H₂SO₄'), closeTo(98.07, 0.05));
    expect(molarMass('Ca(OH)2'), closeTo(74.09, 0.05));
    expect(parseFormula('CuSO4·5H2O')!['O'], 9);
    expect(parseFormula('Xy2'), isNull);
    expect(parseFormula('H2O)'), isNull);
  });

  test('Hiển thị chỉ số dưới, giữ hệ số phương trình', () {
    expect(prettyFormula('H2SO4'), 'H₂SO₄');
    expect(prettyFormula('2H2 + O2 -> 2H2O'), '2H₂ + O₂ -> 2H₂O');
    expect(prettyFormula('Ca(OH)2'), 'Ca(OH)₂');
  });

  test('Khối bộ máy mới giữ nguyên dữ liệu khi lưu/mở lại', () {
    final b = Block.tryParse({
      'type': 'reaction_lab',
      'topic': 'Trung hòa',
      'reaction': {
        'setup': 'Cốc',
        'reagents': [
          {'id': 'a', 'name': 'HCl', 'formula': 'HCl', 'color': '#ffffff', 'state': 'solution'},
        ],
        'reactions': [],
        'no_reaction_text': 'Không',
        'safety': null,
      },
    })!;
    b.sim = {'html': '<p>x</p>'};
    final back = Block.tryParse(b.toJson())!;
    expect(back.type, BlockType.reactionLab);
    expect(back.rawMap('reaction')!['setup'], 'Cốc');
    expect(back.sim!['html'], '<p>x</p>');
    expect(Block.tryParse({'type': 'custom_sim', 'sim_prompt': 'p'})!.isInteractive, isTrue);
  });
}
