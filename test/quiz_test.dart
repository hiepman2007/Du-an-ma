import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/quiz_builder_screen.dart';
import 'package:hoc_thong_minh/services/api_client.dart';
import 'package:hoc_thong_minh/services/storage.dart';
import 'package:hoc_thong_minh/state/app_state.dart';
import 'package:hoc_thong_minh/theme.dart';
import 'package:hoc_thong_minh/widgets/roadmap_map.dart';
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
  Map<String, dynamic>? body;
  bool fail = true;

  @override
  Future<Map<String, dynamic>> studyQuiz(Map<String, dynamic> body) async {
    this.body = body;
    if (fail) {
      fail = false;
      throw ApiException('Máy chủ AI đang quá tải. Thử lại sau ít phút.', status: 503);
    }
    return {
      'title': 'Quiz hàng đợi',
      'blocks': [
        {'type': 'text_section', 'body': 'Máy in nhận lệnh in theo thứ tự gửi tới.'},
        {'type': 'mcq', 'topic': 'Hàng đợi', 'body': 'Máy in xử lý lệnh theo nguyên tắc nào?',
          'options': ['FIFO', 'LIFO', 'Ngẫu nhiên', 'Ưu tiên'], 'answer_index': 0, 'explanation': 'Lệnh đến trước được in trước.'},
        {'type': 'true_false', 'topic': 'Ngăn xếp', 'body': 'Ngăn xếp lấy phần tử vào sau cùng ra trước.', 'answer_bool': true},
      ],
    };
  }
}

void main() {
  testWidgets('Tạo quiz 3 bước, làm từng câu, xem điểm theo chủ đề và làm lại câu sai', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = _Api();
    final course = Course(
      id: 'dsa',
      title: 'Cấu trúc dữ liệu',
      goal: 'Ôn thi',
      createdAt: DateTime(2026, 11, 13),
      lessons: [Lesson(id: 'queue', title: 'Hàng đợi', objectives: const ['Hiểu FIFO'])],
    )..sources.add(CourseSource(id: 'text:1', kind: SourceKind.text, title: 'Ghi chú', text: 'Hàng đợi là FIFO.'));
    final state = AppState(api: api, storage: _Store())..courses.add(course);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: buildTheme(), home: const QuizBuilderScreen(courseId: 'dsa', lessonId: 'queue')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1 nguồn đang bật'), findsOneWidget);
    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng: 8/15 câu'), findsOneWidget);
    await tester.tap(find.byTooltip('Thêm Đoạn văn 3 tầng'));
    await tester.pumpAndSettle();
    expect(find.text('Tổng: 11/15 câu'), findsOneWidget);
    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Khó'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo quiz · 11 câu'));
    await tester.pumpAndSettle();

    // Lỗi lần đầu: báo rõ và cho thử lại, không mất cấu hình.
    expect(find.textContaining('quá tải'), findsOneWidget);
    expect(api.body!['difficulty'], 'hard');
    expect(api.body!['counts'], {'mcq': 5, 'true_false': 2, 'matching': 1, 'passage': 1});
    expect(api.body!['topic'], 'Hàng đợi');
    expect(api.body!['focus'], contains('Hiểu FIFO'));
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Câu 1/2'), findsOneWidget);
    expect(find.text('TÌNH HUỐNG'), findsOneWidget);
    await tester.tap(find.text('LIFO'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lệnh đến trước được in trước.'), findsOneWidget);
    await tester.tap(find.text('Câu tiếp'));
    await tester.pumpAndSettle();
    expect(find.text('Câu 2/2'), findsOneWidget);
    await tester.tap(find.text('Đúng').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem kết quả'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Hàng đợi'), findsOneWidget);
    expect(find.text('Ngăn xếp'), findsOneWidget);
    final lesson = course.lessons.single;
    expect((lesson.quizCorrect, lesson.quizTotal), (1, 2));
    expect(lessonMastery(lesson), 0.5);
    expect(course.artifacts.single.attempts.single.score, 1);

    await tester.scrollUntilVisible(find.text('Làm lại 1 câu sai'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Làm lại 1 câu sai'));
    await tester.pumpAndSettle();
    expect(find.text('Câu 1/1'), findsOneWidget);
    expect(find.text('Máy in xử lý lệnh theo nguyên tắc nào?'), findsOneWidget);
  });

  test('Cấu hình quiz giữ đúng tổng số câu và đọc lại được từ JSON', () {
    const spec = QuizSpec(counts: {'mcq': 4, 'passage': 2}, difficulty: 'easy', lessonId: 'l1');
    expect(spec.total, 10);
    final back = QuizSpec.fromJson(spec.toJson());
    expect((back.total, back.difficulty, back.lessonId), (10, 'easy', 'l1'));
  });
}
