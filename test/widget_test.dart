import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/services/expr.dart';

Map<String, dynamic> _block(String type, [Map<String, dynamic> extra = const {}]) => {
      'type': type,
      'topic': 'Điện học',
      'title': null,
      'body': null,
      'options': <String>[],
      'answer_index': null,
      'answer_bool': null,
      'answers': <String>[],
      'pairs': <Map>[],
      'items': <String>[],
      'cards': <Map>[],
      'lab': null,
      'graph': null,
      'explanation': null,
      'source_quote': null,
      'source_page': null,
      'source_url': null,
      ...extra,
    };

void main() {
  test('Block.parseList bỏ qua loại khối lạ', () {
    final blocks = Block.parseList([
      _block('text_section', {'body': 'Xin chào'}),
      _block('widget_khong_ton_tai'),
      _block('mcq', {'body': 'Q?', 'options': ['a', 'b'], 'answer_index': 1}),
    ]);
    expect(blocks.length, 2);
    expect(blocks[1].type, BlockType.mcq);
    expect(blocks[1].isGraded, isTrue);
  });

  test('Course toJson/fromJson giữ nguyên dữ liệu và kết quả', () {
    final lesson = Lesson(id: 'l1', title: 'Định luật Ohm', objectives: ['Hiểu I = U/R'])
      ..blocks = Block.parseList([
        _block('mcq', {'body': 'Q?', 'options': ['a', 'b'], 'answer_index': 0}),
        _block('formula_lab', {
          'lab': {
            'formula': 'U/R',
            'result_label': 'I',
            'result_unit': 'A',
            'variables': [
              {'name': 'U', 'label': 'U', 'unit': 'V', 'min': 0, 'max': 24, 'step': 1, 'default': 12},
              {'name': 'R', 'label': 'R', 'unit': 'Ω', 'min': 1, 'max': 10, 'step': 1, 'default': 4},
            ],
          },
        }),
      ])
      ..results[0] = false;
    final c = Course(id: 'c1', title: 'Điện học', goal: 'Ôn thi', createdAt: DateTime(2026, 11, 13), lessons: [lesson], sources: [
      CourseSource(id: 'file:1', kind: SourceKind.file, title: 'slide.pdf', fileId: 'file-1', mimeType: 'application/pdf'),
      CourseSource(id: 'file:2', kind: SourceKind.file, title: 'de-cuong.pdf', fileId: 'file-2', mimeType: 'application/pdf'),
      CourseSource(id: 'text:1', kind: SourceKind.text, title: 'Ghi chú', text: 'I = U/R'),
      CourseSource.fromWeb(WebSource(title: 'Định luật Ohm', url: 'https://vi.wikipedia.org/wiki/Ohm', domain: 'vi.wikipedia.org', snippet: '', trusted: true)),
    ]);
    c.sources[1].enabled = false; // tat mot nguon: AI khong duoc dung
    final back = Course.fromJson(c.toJson());
    expect(back.title, 'Điện học');
    expect(back.lessons.first.blocks!.length, 2);
    expect(back.lessons.first.results[0], isFalse);
    expect(back.lessons.first.blocks![1].lab!.variables.length, 2);
    expect(back.weakTopics['Điện học'], 1);
    final m = back.materialJson();
    expect((m['files'] as List).map((f) => f['fileId']), ['file-1']);
    expect(m['text'], 'I = U/R');
    expect((m['sources'] as List).single['url'], 'https://vi.wikipedia.org/wiki/Ohm');
    expect(back.allowWeb, isFalse);
  });

  test('Đọc được dữ liệu khóa học kiểu cũ (một file, văn bản, nguồn web rời)', () {
    final old = Course.fromJson({
      'id': 'c0', 'title': 'Cũ', 'goal': '', 'createdAt': '2026-11-13T00:00:00Z', 'lessons': [],
      'fileId': 'f-old', 'mimeType': 'application/pdf', 'fileName': 'cu.pdf', 'text': 'abc',
      'sources': [{'title': 'W', 'url': 'https://x.edu/a', 'domain': 'x.edu', 'snippet': '', 'trust': 'trusted'}],
    });
    expect(old.sources.map((s) => s.kind), [SourceKind.file, SourceKind.text, SourceKind.web]);
    expect(old.sourceLabel, '1 tài liệu · 1 nguồn web · 1 văn bản');
  });

  test('Formula tính định luật Ohm trên máy', () {
    final f = Formula.parse('U/R');
    expect(f.eval({'U': 12, 'R': 4}), closeTo(3, 1e-9));
    expect(f.eval({'U': 12, 'R': 0}), isNull); // chia cho 0 -> không hiển thị
    final g = Formula.parse('a*x^2+b*x+c');
    expect(g.eval({'a': 1, 'b': 0, 'c': -1, 'x': 2}), closeTo(3, 1e-9));
  });
}
