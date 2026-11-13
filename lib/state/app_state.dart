import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/sample_course.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/storage.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? api, Storage? storage})
      : api = api ?? ApiClient(),
        _storage = storage ?? Storage();

  final ApiClient api;
  final Storage _storage;
  final _uuid = const Uuid();

  bool loaded = false;
  UserRole? role;
  final List<Course> courses = [];

  Future<void> load() async {
    final data = await _storage.load();
    role = UserRole.fromId(data['role']);
    courses
      ..clear()
      ..addAll(((data['courses'] as List?) ?? []).map((e) {
        try {
          return Course.fromJson(Map<String, dynamic>.from(e));
        } catch (_) {
          return null;
        }
      }).whereType<Course>());
    loaded = true;
    notifyListeners();
    api.health(); // danh thuc backend som (cold start)
  }

  Future<void> _save() => _storage.save({'role': role?.id, 'courses': courses.map((c) => c.toJson()).toList()});

  Future<void> setRole(UserRole r) async {
    role = r;
    notifyListeners();
    await _save();
  }

  String get _roleId => (role ?? UserRole.student).id;

  Course? courseById(String id) {
    for (final c in courses) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Bien nguon nhap (file chua tai len / van ban / web) thanh nguon cua khoa hoc. File thi tai len server.
  Future<CourseSource> _materialize(SourceDraft d) async {
    switch (d.kind) {
      case SourceKind.file:
        final up = await api.upload(filename: d.title, mimeType: d.mimeType!, bytes: d.bytes!);
        return CourseSource(id: 'file:${up['fileId']}', kind: SourceKind.file, title: d.title, fileId: up['fileId'], mimeType: d.mimeType);
      case SourceKind.text:
        return CourseSource(id: 'text:${_uuid.v4()}', kind: SourceKind.text, title: d.title, text: d.text);
      case SourceKind.web:
        return CourseSource.fromWeb(d.web!);
    }
  }

  /// Buoc 1 + 2: tai cac nguon len -> AI lap lo trinh tu toan bo nguon. onStep bao tien trinh.
  Future<Course> createCourse({
    required String goal,
    required List<SourceDraft> drafts,
    bool allowWeb = false,
    void Function(String step)? onStep,
  }) async {
    final sources = <CourseSource>[];
    final files = drafts.where((d) => d.kind == SourceKind.file).length;
    var done = 0;
    for (final d in drafts) {
      if (d.kind == SourceKind.file) onStep?.call('Đang tải tài liệu lên (${++done}/$files)…');
      sources.add(await _materialize(d));
    }
    onStep?.call('AI đang đọc ${sources.length} nguồn và lên lộ trình…');
    final draft = Course(id: _uuid.v4(), title: '', goal: goal, createdAt: DateTime.now(), lessons: [], sources: sources);
    final out = await api.outline({'role': _roleId, 'goal': goal, ...draft.materialJson()});
    final course = Course(
      id: draft.id,
      title: out['title'] ?? 'Khóa học mới',
      goal: goal,
      language: out['language'] ?? '',
      subject: out['subject'] ?? '',
      createdAt: draft.createdAt,
      lessons: ((out['lessons'] as List?) ?? []).map((e) => Lesson.fromJson(Map<String, dynamic>.from(e))).toList(),
      sources: sources,
      allowWeb: allowWeb,
    );
    courses.insert(0, course);
    notifyListeners();
    await _save();
    return course;
  }

  // --- Quan ly nguon kieu NotebookLM ---
  Future<void> addSources(Course c, List<SourceDraft> drafts) async {
    for (final d in drafts) {
      final s = await _materialize(d);
      if (!c.sources.any((x) => x.id == s.id)) c.sources.add(s);
    }
    notifyListeners();
    await _save();
  }

  Future<void> setSourceEnabled(Course c, CourseSource s, bool on) async {
    s.enabled = on;
    notifyListeners();
    await _save();
  }

  Future<void> removeSource(Course c, CourseSource s) async {
    c.sources.remove(s);
    notifyListeners();
    await _save();
  }

  Future<void> setAllowWeb(Course c, bool on) async {
    c.allowWeb = on;
    notifyListeners();
    await _save();
  }

  Future<void> generateLesson(Course course, Lesson lesson) async {
    final out = await api.lesson({
      'role': _roleId,
      'course': {'title': course.title, 'subject': course.subject, 'lessons': course.lessons.map((l) => l.toOutlineJson()).toList()},
      'lessonId': lesson.id,
      ...course.materialJson(),
    });
    lesson.blocks = Block.parseList(out['blocks']);
    lesson.results.clear();
    notifyListeners();
    await _save();
  }

  /// "Kham pha them": AI them 1-2 khoi tuong tac vao cuoi bai.
  Future<int> addInteractive(Course course, Lesson lesson, String concept) async {
    final out = await api.interactive({
      'role': _roleId,
      'lessonTitle': lesson.title,
      'subject': course.subject,
      'concept': concept,
      ...course.materialJson(),
    });
    final blocks = Block.parseList(out['blocks']);
    lesson.blocks = [...?lesson.blocks, ...blocks];
    notifyListeners();
    await _save();
    return blocks.length;
  }

  /// Mo phong tuy bien (tang du phong): sinh HTML khi hoc sinh bam, luu vao khoi de mo lai khong goi AI.
  Future<void> generateSimulation(Lesson lesson, Block block) async {
    final out = await api.simulation({
      'role': _roleId,
      'lessonTitle': lesson.title,
      'topic': block.topic,
      'simPrompt': block.raw['sim_prompt'] ?? block.body ?? '',
    });
    block.sim = {'title': out['title'], 'instructions': out['instructions'], 'html': out['html']};
    notifyListeners();
    await _save();
  }

  /// Gia su hoi dap: them tin nguoi hoc, goi AI, them cau tra loi (chuoi khoi). Loi thi bo tin nguoi hoc va nem loi.
  /// [webSearch]: cho phep tra cuu them tren mang (mac dinh lay theo cai dat cua khoa hoc).
  Future<void> ask(Course course, Lesson lesson, String question, {bool? webSearch}) async {
    final web = webSearch ?? course.allowWeb;
    final history = lesson.chat.map((m) => {'from': m.fromUser ? 'user' : 'tutor', 'text': m.plainText}).toList();
    final userMsg = ChatMessage(fromUser: true, text: question, webMode: web ? 'requested' : 'off');
    lesson.chat.add(userMsg);
    notifyListeners();
    try {
      final out = await api.ask({
        'role': _roleId,
        'subject': course.subject,
        'lessonTitle': lesson.title,
        'question': question,
        'history': history,
        'webSearch': web,
        ...course.materialJson(),
      });
      lesson.chat.add(ChatMessage(
        fromUser: false,
        blocks: Block.parseList(out['blocks']),
        web: ((out['web'] as List?) ?? []).whereType<Map>().map((e) => WebSource.fromJson(Map<String, dynamic>.from(e))).toList(),
        webMode: out['webMode'] ?? 'off',
      ));
    } catch (_) {
      lesson.chat.remove(userMsg);
      notifyListeners();
      rethrow;
    }
    notifyListeners();
    await _save();
  }

  Future<void> clearChat(Lesson lesson) async {
    lesson.chat.clear();
    notifyListeners();
    await _save();
  }

  /// Bo de luyen: sinh them cau hoi theo do kho, noi vao cuoi bai. Tra ve so cau them duoc.
  Future<int> addExercises(Course course, Lesson lesson, String difficulty, {int count = 5}) async {
    final existing = (lesson.blocks ?? []).where((b) => b.isGraded).map((b) => b.body ?? b.title ?? '').toList();
    final out = await api.exercises({
      'role': _roleId,
      'subject': course.subject,
      'lessonTitle': lesson.title,
      'objectives': lesson.objectives,
      'difficulty': difficulty,
      'count': count,
      'existing': existing,
      ...course.materialJson(),
    });
    final blocks = Block.parseList(out['blocks']);
    lesson.blocks = [...?lesson.blocks, ...blocks];
    notifyListeners();
    await _save();
    return blocks.length;
  }

  /// Chi ghi ket qua lan tra loi dau tien cua moi khoi.
  Future<void> recordResult(Lesson lesson, int blockIndex, bool correct) async {
    if (lesson.results.containsKey(blockIndex)) return;
    lesson.results[blockIndex] = correct;
    notifyListeners();
    await _save();
  }

  Future<Map<String, dynamic>> explain(Block b, String chosen, String correct) => api.explain({
        'role': _roleId,
        'question': b.body ?? b.title ?? '',
        'options': b.options,
        'chosen': chosen,
        'correct': correct,
        'sourceQuote': b.sourceQuote,
      });

  Future<List<WebSource>> searchSources(String topic) async {
    final out = await api.searchSources(topic, _roleId);
    return ((out['sources'] as List?) ?? []).map((e) => WebSource.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  // --- Sua lo trinh ---
  Future<void> reorderLesson(Course c, int oldIndex, int newIndex) async {
    final l = c.lessons.removeAt(oldIndex);
    c.lessons.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, l);
    notifyListeners();
    await _save();
  }

  Future<void> removeLesson(Course c, Lesson l) async {
    c.lessons.remove(l);
    notifyListeners();
    await _save();
  }

  Future<void> renameLesson(Lesson l, String title) async {
    l.title = title;
    notifyListeners();
    await _save();
  }

  /// Them khoa hoc mau (khong goi AI) de xem giao dien / du phong khi mang yeu.
  Future<Course> addSampleCourse() async {
    final existing = courseById('sample-ohm');
    if (existing != null) return existing;
    final c = buildSampleCourse();
    courses.add(c);
    notifyListeners();
    await _save();
    return c;
  }

  Future<void> deleteCourse(Course c) async {
    courses.remove(c);
    notifyListeners();
    await _save();
  }

  Future<void> clearAll() async {
    courses.clear();
    role = null;
    notifyListeners();
    await _save();
  }

  // --- Thong ke su dung (bang chung cho BGK) ---
  int get totalLessonsGenerated => courses.fold(0, (s, c) => s + c.lessons.where((l) => l.blocks != null).length);
  int get totalAnswered => courses.fold(0, (s, c) => s + c.lessons.fold(0, (t, l) => t + l.results.length));
  int get totalCorrect => courses.fold(0, (s, c) => s + c.lessons.fold(0, (t, l) => t + l.correctCount));
}

/// Nguon nguoi dung vua them (chua tai len): file (bytes), van ban, hoac trang web tim duoc.
class SourceDraft {
  SourceDraft.file({required this.title, required this.mimeType, required this.bytes})
      : kind = SourceKind.file,
        text = null,
        web = null;
  SourceDraft.text({this.title = 'Văn bản dán vào', required this.text})
      : kind = SourceKind.text,
        mimeType = null,
        bytes = null,
        web = null;
  SourceDraft.web(WebSource this.web)
      : kind = SourceKind.web,
        title = web.title,
        mimeType = null,
        bytes = null,
        text = null;

  final SourceKind kind;
  final String title;
  final String? mimeType, text;
  final List<int>? bytes;
  final WebSource? web;

  int get sizeBytes => bytes?.length ?? 0;
}
