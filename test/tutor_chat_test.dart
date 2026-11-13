import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoc_thong_minh/models/models.dart';
import 'package:hoc_thong_minh/screens/tutor_chat_screen.dart';
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
  final bodies = <Map<String, dynamic>>[];
  Completer<void>? gate;
  int answers = 0;

  @override
  Future<Map<String, dynamic>> studyAsk(Map<String, dynamic> body) async {
    bodies.add(body);
    await gate?.future;
    answers++;
    return {'blocks': [
      {'type': 'text_section', 'topic': 'Ôm', 'body': 'Trả lời số $answers: ' r'cường độ dòng điện $I = U/R$ tỉ lệ nghịch với điện trở.'},
    ]};
  }
}

Course _course() => Course(id: 'c1', title: 'Vật lý 11', goal: 'Ôn thi', createdAt: DateTime(2026, 11, 13), lessons: [
      Lesson(id: 'l1', title: 'Định luật Ôm', blocks: Block.parseList([
        {'type': 'text_section', 'title': 'Phát biểu', 'body': 'I = U/R'},
        {'type': 'true_false', 'topic': 'Ôm', 'body': 'Tăng R thì I tăng.', 'answer_bool': false},
      ]), results: {1: false}),
    ]);

Future<(AppState, _Api)> _pump(WidgetTester tester, {String? lessonId}) async {
  tester.view.physicalSize = const Size(375 * 3, 812 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = _Api();
  final state = AppState(api: api, storage: _Store())
    ..loaded = true
    ..role = UserRole.student
    ..courses.add(_course());
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(theme: buildTheme(), home: TutorChatScreen(courseId: 'c1', lessonId: lessonId)),
  ));
  await tester.pumpAndSettle();
  return (state, api);
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).last, text);
  await tester.pump();
  await tester.tap(find.byTooltip('Gửi'));
}

void main() {
  testWidgets('Gợi ý đổi theo bài và câu vừa sai; gửi câu hỏi kèm chế độ Gợi mở', (tester) async {
    final (state, api) = await _pump(tester, lessonId: 'l1');
    expect(find.textContaining('Vì sao mình sai câu'), findsOneWidget);
    expect(find.text('Định luật Ôm'), findsOneWidget); // ngu canh o dau man

    await tester.tap(find.text('Gợi mở'));
    await _send(tester, 'Vì sao I giảm khi R tăng?');
    await tester.pumpAndSettle();

    expect(api.bodies.single['socratic'], isTrue);
    expect(api.bodies.single['lessonTitle'], 'Định luật Ôm');
    expect(find.text('Vì sao I giảm khi R tăng?'), findsOneWidget);
    expect(find.textContaining(findRichText: true, 'Trả lời số 1'), findsOneWidget);
    final thread = state.courses.single.threads.single;
    expect(thread.title, 'Vì sao I giảm khi R tăng?');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dừng khi đang sinh, tạo lại và sửa câu hỏi', (tester) async {
    final (state, api) = await _pump(tester);
    expect(find.text('Hôm nay mình giúp gì cho bạn?'), findsOneWidget);

    api.gate = Completer();
    await _send(tester, 'Câu hỏi thứ nhất');
    await tester.pump();
    expect(find.text('Gia sư đang soạn câu trả lời…'), findsOneWidget);
    await tester.tap(find.byTooltip('Dừng'));
    await tester.pump();
    api.gate!.complete();
    await tester.pumpAndSettle();
    final thread = state.courses.single.threads.single;
    expect(thread.messages.map((m) => m.fromUser), [true]); // giu cau hoi, bo cau tra loi den muon
    api.gate = null;

    await _send(tester, 'Câu hỏi thứ hai');
    await tester.pumpAndSettle();
    expect(find.textContaining(findRichText: true, 'Trả lời số 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Tạo lại câu trả lời'));
    await tester.pumpAndSettle();
    expect(find.textContaining(findRichText: true, 'Trả lời số 2'), findsNothing);
    expect(find.textContaining(findRichText: true, 'Trả lời số 3'), findsOneWidget);
    expect(thread.messages, hasLength(3));

    await tester.tap(find.byTooltip('Sửa câu hỏi'));
    await tester.pumpAndSettle();
    expect(thread.messages, hasLength(1));
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'Câu hỏi thứ hai');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ngăn kéo hội thoại: tìm kiếm, mở lại, tạo mới; đổi ngữ cảnh sang một bài', (tester) async {
    final (state, _) = await _pump(tester);
    await _send(tester, 'Điện trở là gì?');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cuộc trò chuyện mới'));
    await tester.pumpAndSettle();
    await _send(tester, 'Công suất tính thế nào?');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Các cuộc trò chuyện'));
    await tester.pumpAndSettle();
    expect(find.text('Điện trở là gì?'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Tìm cuộc trò chuyện'), 'công suất');
    await tester.pumpAndSettle();
    expect(find.text('Điện trở là gì?'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Tìm cuộc trò chuyện'), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Điện trở là gì?'));
    await tester.pumpAndSettle();
    expect(find.textContaining(findRichText: true, 'Trả lời số 1'), findsOneWidget);

    // Doi ngu canh khi da co tin nhan -> cuoc tro chuyen moi gan voi bai.
    await tester.tap(find.textContaining('Cả khóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Định luật Ôm').last);
    await tester.pumpAndSettle();
    expect(find.text('Hỏi về bài "Định luật Ôm"'), findsOneWidget);
    expect(state.courses.single.threads.where((t) => t.messages.isNotEmpty), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  test('Dữ liệu cũ (chat của sổ và chat từng bài) chuyển thành cuộc trò chuyện', () {
    final old = _course().toJson()
      ..remove('threads')
      ..['notebook_chat'] = [ChatMessage(fromUser: true, text: 'Hỏi cả sổ').toJson()];
    (old['lessons'] as List).first['chat'] = [
      ChatMessage(fromUser: true, text: 'Hỏi trong bài').toJson(),
      ChatMessage(fromUser: false, blocks: Block.parseList([{'type': 'text_section', 'body': 'Đáp'}])).toJson(),
    ];
    final back = Course.fromJson(old);
    expect(back.threads, hasLength(2));
    expect(back.threads.where((t) => t.lessonId == 'l1').single.title, 'Hỏi trong bài');
    expect(back.lessons.single.chat, isEmpty);
    final again = Course.fromJson(back.toJson());
    expect(again.threads, hasLength(2));
  });
}
