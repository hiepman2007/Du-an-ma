import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/data/study_samples.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/home_shell.dart';
import 'package:hoc_thong_minh/services/api_client.dart';
import 'package:hoc_thong_minh/services/storage.dart';
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

class _Api extends ApiClient {
  final calls = <String>[];
  bool failLesson = true;
  static const text = {'type': 'text_section', 'title': 'Đọc đề', 'body': 'Dùng mẫu đã cho.'};
  static const question = {'type': 'true_false', 'topic': 'Xác suất', 'body': 'Biến cố chắc chắn có xác suất 1.', 'answer_bool': true};

  @override
  Future<Map<String, dynamic>> research(String topic, String scope) async {
    calls.add('research:$topic');
    return {'mode': 'catalog', 'missing': ['exam'], 'sources': []};
  }

  @override
  Future<Map<String, dynamic>> studyOutline(Map<String, dynamic> body) async {
    calls.add('outline');
    return {'title': 'Xác suất', 'subject': 'Toán', 'lessons': [
      {'id': 'l1', 'title': 'Biến cố', 'phase': 'Nền tảng', 'minutes': 15},
      {'id': 'l2', 'title': 'Xác suất có điều kiện', 'phase': 'Vận dụng', 'prerequisites': ['l1']},
    ]};
  }

  @override
  Future<Map<String, dynamic>> studyLesson(Map<String, dynamic> body) async {
    calls.add('lesson');
    if (failLesson) throw ApiException('Hết quota', status: 429);
    return {'blocks': [text, question]};
  }

  @override
  Future<Map<String, dynamic>> studyAsk(Map<String, dynamic> body) async {
    calls.add('ask');
    expect((body['texts'] as List).single['text'], 'Xác suất biến cố chắc chắn bằng 1.');
    return {'blocks': [text]};
  }

  @override
  Future<Map<String, dynamic>> studyArtifact(Map<String, dynamic> body) async {
    calls.add('artifact');
    return {'title': 'Kiểm tra xác suất', 'blocks': [question]};
  }
}

void main() {
  test('Khóa học nhiều môn tiếp tục từ bài lỗi và giữ tiến độ khi tạo thêm quiz', () async {
    final storage = _Store();
    final api = _Api();
    final state = AppState(api: api, storage: storage);
    await state.load();
    final course = await state.createNotebook();
    const brief = StudyBrief(topic: 'Xác suất', scope: 'Biến cố và xác suất có điều kiện');
    final first = state.planCourse(course, brief);
    final failure = expectLater(first, throwsA(isA<ApiException>()));
    await state.planCourse(course, brief);
    await failure;
    expect(api.calls, ['research:Xác suất', 'outline', 'lesson']);
    expect(course.missingCategories, ['exam']);

    final restored = AppState(api: api, storage: storage);
    await restored.load();
    final notebook = restored.selectedCourse!;
    expect(notebook.lessons.length, 2);
    api.failLesson = false;
    await restored.planCourse(notebook, notebook.brief!);
    expect(api.calls.last, 'lesson');
    expect(api.calls.where((call) => call == 'outline').length, 1);
    expect(notebook.artifacts.single.kind, StudyArtifactKind.quickQuiz);
    final lesson = notebook.lessons.first;
    await restored.setLessonStep(lesson, 1);
    await restored.setLessonCompleted(lesson, true);

    await restored.addSources(notebook, [SourceDraft.text(text: 'Xác suất biến cố chắc chắn bằng 1.')]);
    await restored.askNotebook(notebook, 'Xác suất biến cố chắc chắn bằng bao nhiêu?');
    final artifact = (await restored.createArtifact(notebook, StudyArtifactKind.quickQuiz))!;
    await restored.recordAttempt(notebook, artifact, QuizAttempt(id: 'attempt', results: {artifact.questionKey(0): true}, total: 1));
    await restored.createArtifact(notebook, StudyArtifactKind.quickQuiz, regenerate: true);

    final reloaded = AppState(storage: storage);
    await reloaded.load();
    final back = reloaded.selectedCourse!;
    expect(back.lessons.first.isDone, isTrue);
    expect(back.lessons.first.stepIndex, 1);
    expect(back.notebookChat, hasLength(2));
    expect(back.artifacts, hasLength(3));
    expect(back.artifacts[1].attempts.single.score, 1);
  });

  test('Thư viện mẫu có bài học từ nhiều môn', () {
    for (final id in studySamples.keys) {
      final notebook = buildStudySample(id);
      expect(notebook.isSample, isTrue);
      expect(notebook.lessons.first.blocks, isNotEmpty);
    }
  });

  testWidgets('Từ chủ đề bất kỳ mở mục tiêu và dựng Studio ở bố cục hẹp', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _Api()..failLesson = false;
    final state = AppState(api: api, storage: _Store());
    await state.load();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: state,
      child: MaterialApp(theme: buildTheme(), home: const HomeShell())));
    await tester.enterText(find.byType(TextField), 'Tìm nguồn và lên lộ trình cho môn Xác suất');
    await tester.tap(find.widgetWithText(FilledButton, 'Bắt đầu'));
    await tester.pumpAndSettle();
    expect(find.text('Mục tiêu học của bạn'), findsOneWidget);
    expect(find.text('Xác suất'), findsOneWidget);
    await tester.tap(find.text('Dùng mặc định'));
    await tester.pumpAndSettle();
    expect(find.text('Tiếp tục học'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
