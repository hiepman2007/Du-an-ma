import '../models/models.dart';
import 'sample_course.dart';

const studySamples = {
  'sample-dsa': 'Cấu trúc dữ liệu và giải thuật',
  'sample-math': 'Hàm số bậc hai',
  'sample-ohm': 'Vật lý · Định luật Ohm',
  'sample-chem': 'Hóa học · Mol và khối lượng',
};

Course buildStudySample(String id) {
  if (id == 'sample-ohm') return Course.fromJson({...buildSampleCourse().toJson(), 'is_sample': true});
  final (topic, phase, explanation, sim, quick, interactive, source) = switch (id) {
    'sample-dsa' => (
      'Tìm kiếm nhị phân', 'Tìm kiếm và sắp xếp',
      'Tìm kiếm nhị phân cần một dãy đã sắp xếp. So sánh đích với phần tử giữa, rồi bỏ nửa không thể chứa đích. Ví dụ với dãy 2, 4, 7, 9, 12, 15, 21 và đích 12, so sánh với 9 rồi tiếp tục ở nửa phải.',
      <String, dynamic>{'type': 'dsa_sim', 'title': 'Theo dõi tìm kiếm nhị phân', 'algorithm': 'binary_search',
        'values': [2, 4, 7, 9, 12, 15, 21], 'target': 12},
      <String, dynamic>{'type': 'mcq', 'body': 'Dãy đầu vào cần có tính chất gì?', 'options': ['Đã sắp xếp', 'Chỉ chứa số chẵn', 'Có đúng 8 phần tử'], 'answer_index': 0},
      <String, dynamic>{'type': 'ordering', 'body': 'Xếp các bước tìm kiếm.', 'items': ['Xác định khoảng tìm', 'Chọn phần tử giữa', 'So sánh với đích', 'Thu hẹp khoảng nếu cần']},
      'https://ocw.mit.edu/courses/6-006-introduction-to-algorithms-spring-2020/',
    ),
    'sample-math' => (
      'Đỉnh của parabol', 'Đồ thị và cực trị',
      'Với y = ax² + bx + c và a khác 0, đỉnh có hoành độ −b/(2a). Với y = x² − 4x + 3, đỉnh nằm tại (2, −1). Khi a dương, đỉnh là điểm thấp nhất.',
      <String, dynamic>{'type': 'function_graph', 'title': 'Quan sát đỉnh trên đồ thị',
        'graph': {'expression': 'x^2-4*x+3', 'x_min': -2, 'x_max': 6, 'tools': ['extrema', 'roots']}},
      <String, dynamic>{'type': 'mcq', 'body': 'Hoành độ đỉnh của y = x² − 4x + 3 là bao nhiêu?', 'options': ['−2', '2', '3'], 'answer_index': 1},
      <String, dynamic>{'type': 'matching', 'body': 'Ghép hệ số với dạng parabol.', 'pairs': [
        {'left': 'a > 0', 'right': 'Mở lên'}, {'left': 'a < 0', 'right': 'Mở xuống'},
      ]},
      'https://openstax.org/books/college-algebra-2e/pages/5-1-quadratic-functions',
    ),
    'sample-chem' => (
      'Mol và khối lượng mol', 'Tính theo công thức',
      'Khối lượng mol cho biết khối lượng của một mol chất. Với nước, hai nguyên tử H và một nguyên tử O cho khối lượng mol xấp xỉ 18 g/mol. Hai mol nước có khối lượng xấp xỉ 36 g.',
      <String, dynamic>{'type': 'formula_lab', 'title': 'Thay số mol và khối lượng mol',
        'lab': {'formula': 'n*M', 'result_label': 'Khối lượng', 'result_unit': 'g', 'variables': [
          {'name': 'n', 'label': 'Số mol', 'unit': 'mol', 'min': 0, 'max': 5, 'step': 0.5, 'default': 2},
          {'name': 'M', 'label': 'Khối lượng mol', 'unit': 'g/mol', 'min': 1, 'max': 60, 'step': 1, 'default': 18},
        ]}},
      <String, dynamic>{'type': 'fill_blank', 'body': 'Hai mol nước có khối lượng xấp xỉ bao nhiêu gam?', 'answers': ['36', '36 g']},
      <String, dynamic>{'type': 'matching', 'body': 'Ghép đại lượng với đơn vị.', 'pairs': [
        {'left': 'Lượng chất', 'right': 'mol'}, {'left': 'Khối lượng mol', 'right': 'g/mol'},
      ]},
      'https://openstax.org/books/chemistry-2e/pages/3-1-formula-mass-and-the-mole-concept',
    ),
    _ => throw ArgumentError.value(id, 'id'),
  };
  final title = studySamples[id]!;
  final evidence = CourseSource(id: '$id-note', kind: SourceKind.text, title: 'Bài giảng mẫu', text: explanation);
  Block cited(Map<String, dynamic> json) => Block.tryParse({
    'topic': topic, 'source_id': evidence.id, 'source_quote': explanation, ...json,
  })!;
  final quickBlock = cited(quick);
  final interactiveBlock = cited(interactive);
  final reading = cited({'type': 'text_section', 'title': 'Ý chính và ví dụ', 'body': explanation});
  final blocks = [reading, cited(sim), quickBlock];
  final lessons = [Lesson(id: '$id-lesson', title: topic, phase: phase, sourceIds: [evidence.id],
    objectives: ['Giải thích $topic bằng một ví dụ'], blocks: blocks)];
  if (id == 'sample-dsa') {
    lessons.add(Lesson(id: '$id-graph', title: 'Duyệt đồ thị BFS và DFS', phase: 'Cây và đồ thị',
      prerequisites: [lessons.first.id], objectives: ['So sánh thứ tự duyệt BFS và DFS'], blocks: Block.parseList([
        {'type': 'text_section', 'title': 'Hai cách duyệt', 'body': 'BFS thăm lần lượt theo lớp bằng hàng đợi. DFS đi sâu theo nhánh bằng ngăn xếp.'},
        {'type': 'dsa_sim', 'title': 'Thử duyệt BFS', 'algorithm': 'bfs', 'nodes': ['A', 'B', 'C', 'D', 'E'],
          'edges': [['A', 'B'], ['A', 'C'], ['B', 'D'], ['C', 'E']], 'start': 'A'},
        {'type': 'dsa_sim', 'title': 'Thử duyệt DFS', 'algorithm': 'dfs', 'nodes': ['A', 'B', 'C', 'D', 'E'],
          'edges': [['A', 'B'], ['A', 'C'], ['B', 'D'], ['C', 'E']], 'start': 'A'},
      ])));
  }
  return Course(id: id, title: title, goal: 'Học nền tảng', subject: title, createdAt: DateTime.now(),
    brief: StudyBrief(topic: title, searchWeb: false), isSample: true, lessons: lessons, sources: [
      evidence,
      CourseSource(id: '$id-reference', kind: SourceKind.web, title: id == 'sample-dsa' ? 'MIT OpenCourseWare' : 'OpenStax',
        url: source, domain: Uri.parse(source).host, trusted: true, category: 'lecture'),
      if (id == 'sample-dsa') CourseSource(id: '$id-exams', kind: SourceKind.web, title: 'Đề thi MIT 6.006',
        url: '${source}pages/quizzes/', domain: Uri.parse(source).host, trusted: true, category: 'exam'),
    ], artifacts: [
      StudyArtifact(id: '$id-summary', kind: StudyArtifactKind.summary, title: 'Tóm tắt · $topic', blocks: [reading], sourceIds: [evidence.id]),
      StudyArtifact(id: '$id-quick', kind: StudyArtifactKind.quickQuiz, title: 'Quiz nhanh · $topic', blocks: [quickBlock], sourceIds: [evidence.id]),
      StudyArtifact(id: '$id-interactive', kind: StudyArtifactKind.interactiveQuiz, title: 'Quiz tương tác · $topic', blocks: [interactiveBlock], sourceIds: [evidence.id]),
    ]);
}
