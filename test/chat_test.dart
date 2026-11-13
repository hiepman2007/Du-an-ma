import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';

void main() {
  test('Lịch sử chat gia sư được lưu và đọc lại cùng bài học', () {
    final l = Lesson(id: 'l1', title: 'Định luật Ohm')
      ..chat.add(ChatMessage(fromUser: true, text: 'Vì sao I tỉ lệ nghịch với R?'))
      ..chat.add(ChatMessage(fromUser: false, blocks: Block.parseList([
        {'type': 'text_section', 'topic': 'Ohm', 'body': r'Vì $I = \frac{U}{R}$ nên R tăng thì I giảm.'},
        {'type': 'code_demo', 'topic': 'Ohm', 'code': {'language': 'python', 'source': 'print(12/4)', 'output': '3.0'}},
      ])));
    final back = Lesson.fromJson(l.toJson());
    expect(back.chat.length, 2);
    expect(back.chat.first.fromUser, isTrue);
    expect(back.chat.last.blocks.map((b) => b.type), [BlockType.textSection, BlockType.codeDemo]);
    expect(back.chat.last.plainText, contains('R tăng'));
    expect(back.chat.last.blocks.last.rawMap('code')!['output'], '3.0');
  });
}
