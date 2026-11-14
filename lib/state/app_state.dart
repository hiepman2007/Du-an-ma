import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/sample_course.dart';
import '../data/study_samples.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/intent.dart';
import '../services/storage.dart';
import '../services/study_account.dart';
import '../services/topic_images.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? api, Storage? storage, this.account, TopicImages? images})
      : api = api ?? ApiClient(token: () => account?.accessToken),
        images = images ?? TopicImages(),
        _guestStorage = storage ?? Storage(),
        _storage = storage ?? Storage();

  final ApiClient api;
  final TopicImages images;
  final StudyAccount? account;

  /// Anh xem truoc cua bai: anh da luu, anh trong noi dung bai, hoac tim tren Wikipedia theo ten bai.
  Future<String?> lessonImage(Course course, Lesson lesson) async {
    final known = lesson.imageUrl ?? lesson.blockImage;
    if (known != null) return known;
    final found = await images.lookup(lesson.title, subject: course.subject);
    if (found != null && lesson.imageUrl == null) {
      lesson.imageUrl = found;
      await _save();
    }
    return found;
  }
  final Storage _guestStorage;
  Storage _storage;
  final _uuid = const Uuid();
  StreamSubscription<Object?>? _authChanges;
  String? _accountId;
  int? _cloudRevision;
  Future<void> _cloudWrites = Future.value();
  String? syncError;
  String? selectedCourseId;
  bool _cloudDirty = false;
  int _localVersion = 0;
  bool get signedIn => _accountId != null;
  bool get canImportGuest => signedIn && _guestCourses.any((row) => courses.every((c) => c.id != row['id']));
  List<Map<String, dynamic>> _guestCourses = [];
  final Set<String> _busy = {};
  String? openingPrompt;

  /// So hoat dong hoc moi ngay (yyyy-mm-dd -> diem): tra loi cau hoi, hoi gia su, lam quiz, chay thi nghiem.
  final Map<String, int> activity = {};
  static const dailyGoal = 10;

  static String dayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get todayActivity => activity[dayKey(DateTime.now())] ?? 0;

  /// So ngay hoc lien tiep, tinh den hom nay (hoac hom qua neu hom nay chua hoc).
  int get streak {
    var day = DateTime.now();
    if ((activity[dayKey(day)] ?? 0) == 0) day = day.subtract(const Duration(days: 1));
    var n = 0;
    while ((activity[dayKey(day)] ?? 0) > 0) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }

  void _bumpActivity([int points = 1]) {
    final key = dayKey(DateTime.now());
    activity[key] = (activity[key] ?? 0) + points;
  }

  /// Ghi nhan hoat dong ngoai luong AI (vd chay mo phong) va luu lai.
  Future<void> logActivity([int points = 1]) async {
    _bumpActivity(points);
    notifyListeners();
    await _save();
  }
  bool openSourcesFirst = false;

  bool loaded = false;
  UserRole? role;
  final List<Course> courses = [];

  Future<void> load() async {
    await _loadWorkspace(account?.userId);
    _authChanges ??= account?.authChanges.listen((_) {
      final id = account?.userId;
      if (id != _accountId) unawaited(_loadWorkspace(id));
    }, onError: (Object _) {});
    if (account?.userId != _accountId) await _loadWorkspace(account?.userId);
  }

  Future<void> _loadWorkspace(String? id) async {
    _accountId = id;
    _cloudRevision = null;
    _cloudDirty = false;
    _localVersion = 0;
    syncError = null;
    loaded = false;
    notifyListeners();
    final store = id == null ? _guestStorage : Storage(accountId: id);
    _storage = store;
    var data = <String, dynamic>{};
    try {
      data = await store.load();
      if (id != null) {
        final guest = await _guestStorage.load();
        if (_storage != store) return;
        _guestCourses = _mapsFrom(guest['courses']);
        final cloud = await account!.loadWorkspace();
        if (_storage != store) return;
        _cloudRevision = data['_pending_cloud'] == true ? data['_cloud_base_revision'] as int? : cloud.revision;
        if (cloud.revision > 0 && data['_pending_cloud'] != true) data = cloud.snapshot;
        _cloudDirty = data['_pending_cloud'] == true;
        if (_cloudDirty) syncError = 'Có thay đổi chưa đồng bộ. Hãy thử lưu lại.';
      }
    } catch (_) {
      if (_storage != store) return;
      syncError = 'Chưa thể tải dữ liệu đồng bộ. Hãy thử lại khi có mạng.';
      _cloudDirty = data['_pending_cloud'] == true;
    }
    if (_storage != store) return;
    _restore(data);
    loaded = true;
    notifyListeners();
  }

  static List<Map<String, dynamic>> _mapsFrom(Object? value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  void _restore(Map<String, dynamic> data) {
    role = UserRole.fromId(data['role']);
    selectedCourseId = data['selected_course_id'] as String?;
    activity
      ..clear()
      ..addAll({
        for (final e in ((data['activity'] as Map?) ?? {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      });
    courses
      ..clear()
      ..addAll(_mapsFrom(data['courses']).map((e) {
        try {
          return Course.fromJson(e);
        } catch (_) {
          return null;
        }
      }).whereType<Course>());
  }

  Map<String, dynamic> _snapshot() => {
    'role': role?.id, 'selected_course_id': selectedCourseId, 'activity': activity,
    'courses': courses.map((c) => c.toJson()).toList(),
  };

  Future<void> _save() async {
    final store = _storage;
    final id = _accountId;
    final version = ++_localVersion;
    final snapshot = jsonDecode(jsonEncode(_snapshot())) as Map<String, dynamic>;
    if (id != null) _cloudDirty = true;
    await store.save({...snapshot, if (id != null) ...{
      '_pending_cloud': true, '_cloud_base_revision': _cloudRevision,
    }});
    if (id == null) return;
    final write = _cloudWrites.then((_) async {
      if (_storage != store || account?.userId != id) return;
      try {
        if (_cloudRevision == null) {
          final cloud = await account!.loadWorkspace();
          if (_storage != store) return;
          if (cloud.revision != 0) throw StateError('Cloud workspace must be refreshed first');
          _cloudRevision = cloud.revision;
        }
        final revision = await account!.saveWorkspace(snapshot, expectedRevision: _cloudRevision!);
        if (_storage != store) return;
        _cloudRevision = revision;
        if (version == _localVersion) {
          await store.save(snapshot);
          _cloudDirty = false;
        }
        syncError = null;
      } on StudySyncConflict {
        if (_storage == store) syncError = 'Sổ đã thay đổi trên thiết bị khác. Hãy tải bản đồng bộ.';
      } catch (_) {
        if (_storage == store) syncError = 'Thay đổi đã lưu trên máy. Chưa thể đồng bộ.';
      }
      if (_storage == store) notifyListeners();
    });
    _cloudWrites = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    await write;
  }

  Future<void> refreshWorkspace() async {
    if (!signedIn || !loaded || _cloudDirty || _busy.isNotEmpty) return;
    final store = _storage;
    final version = _localVersion;
    try {
      final cloud = await account!.loadWorkspace();
      if (_storage != store || version != _localVersion || cloud.revision == _cloudRevision || cloud.revision == 0) return;
      _cloudRevision = cloud.revision;
      _restore(cloud.snapshot);
      await store.save(cloud.snapshot);
      if (_storage == store) notifyListeners();
    } catch (_) {
      // Keep the last local copy when the connection is unavailable.
    }
  }

  Future<void> retrySync() => _save();

  Future<void> useCloudCopy() async {
    if (!signedIn) return;
    final store = _storage;
    final cloud = await account!.loadWorkspace();
    if (_storage != store) return;
    await store.save(cloud.snapshot);
    if (_storage == store) await _loadWorkspace(_accountId);
  }

  Future<int> importGuestCourses() async {
    if (!signedIn) return 0;
    final ids = courses.map((c) => c.id).toSet();
    final imported = _guestCourses.map(Course.fromJson).where((c) => ids.add(c.id)).toList();
    courses.addAll(imported);
    notifyListeners();
    await _save();
    return imported.length;
  }

  Course? get selectedCourse => selectedCourseId == null ? null : courseById(selectedCourseId!);

  Future<void> selectCourse(Course course) async {
    selectedCourseId = course.id;
    notifyListeners();
    await _save();
  }

  Future<Course> createNotebook({String title = 'Sổ học tập mới', String? prompt, bool sourcesFirst = false}) async {
    final notebook = Course(id: _uuid.v4(), title: title, goal: '', createdAt: DateTime.now(), lessons: []);
    courses.insert(0, notebook);
    openingPrompt = prompt;
    openSourcesFirst = sourcesFirst;
    await selectCourse(notebook);
    return notebook;
  }

  Future<void> renameNotebook(Course course, String title) async {
    course.title = title.trim();
    notifyListeners();
    await _save();
  }

  Future<Course> openStudySample(String id) async {
    final course = courseById(id) ?? buildStudySample(id);
    if (!courses.contains(course)) courses.insert(0, course);
    await selectCourse(course);
    return course;
  }

  bool isBusy(Course course, String action) => _busy.contains('${course.id}/$action');

  Future<T?> _run<T>(Course course, String action, Future<T> Function() operation) async {
    final key = '${course.id}/$action';
    if (!_busy.add(key)) return null;
    notifyListeners();
    try {
      if (signedIn && (_cloudDirty || _cloudRevision == null)) {
        await _save();
        if (syncError != null) throw ApiException(syncError!);
      }
      if (!courses.contains(course)) return null;
      return await operation();
    } finally {
      _busy.remove(key);
      notifyListeners();
    }
  }

  void _addSource(Course course, CourseSource source) {
    final matches = course.sources.where((s) => s.id == source.id || (source.url != null && s.url == source.url));
    if (matches.isEmpty) {
      course.sources.add(source);
    } else if (matches.first.removed) {
      matches.first
        ..removed = false
        ..enabled = true;
    } else if (matches.first.extract.isEmpty && source.extract.isNotEmpty) {
      course.sources[course.sources.indexOf(matches.first)] = source;
    }
  }

  Future<void> addWebUrl(Course course, String url) async {
    await _run(course, 'url', () async {
      final out = await api.importWebSource(url);
      if (!courses.contains(course)) return;
      final source = out['source'];
      if (source is! Map) throw ApiException('Máy chủ chưa đọc được liên kết này.');
      _addSource(course, CourseSource.fromWeb(WebSource.fromJson(Map<String, dynamic>.from(source))));
      notifyListeners();
      await _save();
    });
  }

  Future<void> planCourse(Course course, StudyBrief brief) async {
    await _run(course, 'plan', () async {
      final previous = course.brief;
      if (previous?.topic != brief.topic || previous?.scope != brief.scope || previous?.searchWeb != brief.searchWeb) {
        course.researchDone = false;
        course.researchMode = '';
        course.missingCategories = [];
      }
      course.brief = brief;
      course.goal = brief.goal;
      if (course.title == 'Sổ học tập mới') course.title = brief.topic;
      _schedule(course);
      notifyListeners();
      await _save();
      if (!courses.contains(course)) return;
      if (brief.searchWeb && !course.researchDone) {
        final research = await api.research(brief.topic, brief.scope);
        if (!courses.contains(course)) return;
        for (final row in _mapsFrom(research['sources'])) {
          _addSource(course, CourseSource.fromWeb(WebSource.fromJson(row)));
        }
        course.researchMode = research['mode'] ?? '';
        course.missingCategories = (research['missing'] as List? ?? []).whereType<String>().toList();
        course.researchDone = true;
        notifyListeners();
        await _save();
      }
      if (course.lessons.isEmpty && courses.contains(course)) {
        final out = await api.studyOutline({'role': _roleId, 'brief': brief.toJson(), ...course.materialJson()});
        if (!courses.contains(course)) return;
        final lessons = _mapsFrom(out['lessons']).map(Lesson.fromJson).toList();
        if (lessons.isEmpty) throw ApiException('Chưa có lộ trình. Hãy thử lại với phạm vi môn học cụ thể hơn.');
        course
          ..title = out['title'] ?? course.title
          ..subject = out['subject'] ?? brief.topic
          ..language = out['language'] ?? ''
          ..lessons.addAll(lessons);
        _schedule(course);
        notifyListeners();
        await _save();
      }
      if (!courses.contains(course) || course.lessons.isEmpty) return;
      final first = course.lessons.first;
      if (first.blocks == null) await generateLesson(course, first);
      if (!courses.contains(course) || course.artifacts.any((a) => a.id == '${course.id}-starter')) return;
      final quiz = first.blocks?.where((b) => b.isGraded).toList() ?? [];
      if (quiz.isNotEmpty) {
        course.artifacts.add(StudyArtifact(id: '${course.id}-starter', kind: StudyArtifactKind.quickQuiz,
          title: 'Kiểm tra mở đầu · ${first.title}', blocks: quiz,
          sourceIds: quiz.map((b) => b.sourceId).whereType<String>().toSet().toList()));
        notifyListeners();
        await _save();
      }
    });
  }

  Future<void> updateSchedule(Course course, StudyBrief brief) async {
    course.brief = brief;
    course.goal = brief.goal;
    _schedule(course);
    notifyListeners();
    await _save();
  }

  void _schedule(Course course) {
    final brief = course.brief;
    if (brief == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var day = 0;
    var plannedMinutes = 0;
    final availableDays = brief.examDate?.difference(today).inDays;
    for (final lesson in course.lessons.where((lesson) => !lesson.completed)) {
      if (plannedMinutes > 0 && plannedMinutes + lesson.minutes > brief.minutesPerDay) {
        day++;
        plannedMinutes = 0;
      }
      lesson.scheduledAt = today.add(Duration(days: day));
      plannedMinutes += lesson.minutes;
    }
    if (availableDays != null && availableDays <= day) {
      final overflow = course.lessons.where((lesson) =>
        !lesson.completed && lesson.scheduledAt?.isBefore(brief.examDate!) == false);
      for (final lesson in overflow) {
        lesson.scheduledAt = null;
      }
    }
  }

  Future<void> setLessonStep(Lesson lesson, int index) async {
    lesson.stepIndex = index;
    lesson.lastStudiedAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<void> setLessonCompleted(Lesson lesson, bool completed) async {
    lesson.completed = completed;
    lesson.lastStudiedAt = DateTime.now();
    notifyListeners();
    await _save();
  }

  Future<StudyArtifact?> createArtifact(Course course, StudyArtifactKind kind, {bool webOnly = false, bool regenerate = false}) {
    return _run(course, 'artifact', () async {
      final material = course.materialJson(webOnly: webOnly);
      final sources = webOnly ? course.enabledSources.where((s) => s.kind == SourceKind.web) : course.enabledSources;
      final fingerprint = jsonEncode(sources.map((s) => '${s.id}:${s.retrievedAt ?? ''}:${s.extract.length}').toList()..sort());
      final previous = course.artifacts.where((a) => a.kind == kind && a.webOnly == webOnly).toList();
      for (final existing in previous.reversed) {
        if (!regenerate && existing.sourceFingerprint == fingerprint) return existing;
      }
      final out = await api.studyArtifact({'role': _roleId, 'kind': kind.id,
        if (regenerate) 'request_id': _uuid.v4(),
        'topic': course.brief?.topic ?? course.title, ...material});
      if (!courses.contains(course)) throw ApiException('Sổ học tập đã thay đổi.');
      final blocks = Block.parseList(out['blocks']);
      if (blocks.isEmpty) throw ApiException('Chưa có nội dung phù hợp từ các nguồn đã chọn.');
      final artifact = StudyArtifact(id: _uuid.v4(), kind: kind, title: out['title'] ?? kind.label,
        blocks: blocks, sourceIds: (out['source_ids'] as List? ?? []).whereType<String>().toList(),
        sourceFingerprint: fingerprint, webOnly: webOnly,
        version: previous.fold(0, (v, a) => a.version > v ? a.version : v) + 1);
      course.artifacts.add(artifact);
      notifyListeners();
      await _save();
      return artifact;
    });
  }

  /// Tao quiz theo cau hinh nguoi hoc chon (so cau theo loai, do kho, bai trong lo trinh).
  Future<StudyArtifact?> createQuiz(Course course, QuizSpec spec) {
    return _run(course, 'quiz', () async {
      final lesson = spec.lessonId == null ? null : course.lessons.where((l) => l.id == spec.lessonId).firstOrNull;
      final focus = [
        if (spec.focus.trim().isNotEmpty) spec.focus.trim(),
        if (lesson != null && lesson.objectives.isNotEmpty) 'Mục tiêu bài: ${lesson.objectives.take(4).join('; ')}',
      ].join('. ');
      final out = await api.studyQuiz({'role': _roleId, 'request_id': _uuid.v4(),
        'topic': lesson?.title ?? course.brief?.topic ?? course.title,
        'counts': spec.counts, 'difficulty': spec.difficulty, 'explain': spec.explain, 'focus': focus,
        ...course.materialJson()});
      if (!courses.contains(course)) throw ApiException('Sổ học tập đã thay đổi.');
      final blocks = Block.parseList(out['blocks']);
      if (!blocks.any((b) => b.isGraded)) throw ApiException('Chưa tạo được câu hỏi từ các nguồn đã chọn.');
      final previous = course.artifacts.where((a) => a.kind == StudyArtifactKind.quiz);
      final artifact = StudyArtifact(id: _uuid.v4(), kind: StudyArtifactKind.quiz,
        title: out['title'] ?? 'Quiz · ${lesson?.title ?? course.title}', blocks: blocks,
        sourceIds: (out['source_ids'] as List? ?? []).whereType<String>().toList(),
        version: previous.fold(0, (v, a) => a.version > v ? a.version : v) + 1,
        lessonId: lesson?.id, spec: spec);
      course.artifacts.add(artifact);
      notifyListeners();
      await _save();
      return artifact;
    });
  }

  /// Canvas: AI viet mot ung dung/mo phong HTML nho tu mo ta. Moi lan sua them mot phien ban (khoi custom_sim).
  Future<StudyArtifact?> createCanvas(Course course, String prompt, {String? lessonId}) {
    return _run(course, 'canvas', () async {
      final lesson = lessonId == null ? null : course.lessons.where((l) => l.id == lessonId).firstOrNull;
      final request = _clip(prompt.trim(), 600);
      final out = await api.simulation({'role': _roleId, 'lessonTitle': lesson?.title ?? course.title,
        'topic': course.subject.isNotEmpty ? course.subject : course.title, 'simPrompt': request});
      if (!courses.contains(course)) throw ApiException('Sổ học tập đã thay đổi.');
      final artifact = StudyArtifact(id: _uuid.v4(), kind: StudyArtifactKind.canvas,
        title: '${out['title'] ?? ''}'.trim().isEmpty ? 'Canvas' : '${out['title']}'.trim(),
        blocks: [_canvasVersion(out, request)], lessonId: lesson?.id);
      course.artifacts.add(artifact);
      notifyListeners();
      await _save();
      return artifact;
    });
  }

  /// Sua canvas tu phien ban [from] theo [instruction]; them phien ban moi o cuoi.
  Future<bool?> reviseCanvas(Course course, StudyArtifact artifact, int from, String instruction) {
    return _run(course, 'canvas', () async {
      final base = artifact.blocks[from];
      final lesson = artifact.lessonId == null ? null : course.lessons.where((l) => l.id == artifact.lessonId).firstOrNull;
      final request = _clip(instruction.trim(), 600);
      final out = await api.simulation({'role': _roleId, 'lessonTitle': lesson?.title ?? course.title,
        'topic': course.subject.isNotEmpty ? course.subject : course.title,
        'simPrompt': request, 'previousHtml': base.sim?['html'] ?? ''});
      artifact.blocks.add(_canvasVersion(out, request));
      notifyListeners();
      await _save();
      return true;
    });
  }

  Block _canvasVersion(Map<String, dynamic> out, String prompt) => Block.tryParse({
    'type': 'custom_sim', 'title': out['title'], 'sim_prompt': prompt,
    'sim': {'title': out['title'], 'instructions': out['instructions'] ?? '', 'html': out['html'] ?? ''},
  })!;

  static String _clip(String text, int max) => text.length <= max ? text : text.substring(0, max);

  Future<void> saveChatNote(Course course, ChatMessage message) async {
    final id = 'note-${message.at.microsecondsSinceEpoch}';
    if (course.artifacts.any((artifact) => artifact.id == id)) return;
    course.artifacts.add(StudyArtifact(id: id, kind: StudyArtifactKind.note, title: 'Ghi chú từ hỏi đáp',
      blocks: message.blocks, sourceIds: message.blocks.map((b) => b.sourceId).whereType<String>().toSet().toList()));
    notifyListeners();
    await _save();
  }

  Future<void> recordAttempt(Course course, StudyArtifact artifact, QuizAttempt attempt) async {
    if (!courses.contains(course) || !course.artifacts.contains(artifact)) return;
    if (artifact.attempts.any((a) => a.id == attempt.id)) return;
    artifact.attempts.add(attempt);
    _bumpActivity(3);
    final lesson = artifact.lessonId == null ? null : course.lessons.where((l) => l.id == artifact.lessonId).firstOrNull;
    if (lesson != null) {
      lesson.quizCorrect = attempt.score;
      lesson.quizTotal = attempt.total;
    }
    notifyListeners();
    await _save();
  }

  @override
  void dispose() {
    _authChanges?.cancel();
    super.dispose();
  }

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
  Future<CourseSource> _materialize(SourceDraft d, {Course? course}) async {
    switch (d.kind) {
      case SourceKind.file:
        if (signedIn && course != null) {
          final id = _uuid.v4();
          final path = await account!.uploadSource(notebookId: course.id, sourceId: id,
            bytes: Uint8List.fromList(d.bytes!), mimeType: d.mimeType!);
          return CourseSource(id: id, kind: SourceKind.file, title: d.title, storagePath: path, mimeType: d.mimeType);
        }
        if (d.sizeBytes > 3 * 1024 * 1024) throw ApiException('Bản demo nhận PDF và ảnh tối đa 3 MB.');
        final up = await api.upload(filename: d.title, mimeType: d.mimeType!, bytes: d.bytes!);
        return CourseSource(id: 'file:${up['fileId']}', kind: SourceKind.file, title: d.title,
          fileId: up['fileId'], mimeType: d.mimeType, pages: _mapsFrom(up['pages']));
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
    if (signedIn && (_cloudDirty || _cloudRevision == null)) {
      await _save();
      if (syncError != null) throw ApiException(syncError!);
    }
    for (final d in drafts) {
      final s = await _materialize(d, course: c);
      if (!courses.contains(c)) return;
      _addSource(c, s);
      notifyListeners();
      await _save();
    }
  }

  Future<void> setSourceEnabled(Course c, CourseSource s, bool on) async {
    s.enabled = on;
    notifyListeners();
    await _save();
  }

  Future<void> removeSource(Course c, CourseSource s) async {
    s.removed = true;
    s.enabled = false;
    notifyListeners();
    await _save();
  }

  Future<void> setAllowWeb(Course c, bool on) async {
    c.allowWeb = on;
    notifyListeners();
    await _save();
  }

  Future<void> generateLesson(Course course, Lesson lesson) async {
    final out = await api.studyLesson({
      'role': _roleId,
      'course': {'title': course.title, 'subject': course.subject, 'lessons': course.lessons.map((l) => l.toOutlineJson()).toList()},
      'lessonId': lesson.id,
      ...course.materialJson(),
    });
    if (!courses.contains(course) || !course.lessons.contains(lesson)) return;
    final blocks = Block.parseList(out['blocks']);
    if (blocks.isEmpty) throw ApiException('Bài giảng chưa có nội dung dùng được.');
    if (lesson.results.isNotEmpty) {
      lesson.previousResults = [...lesson.previousResults, {
        'at': DateTime.now().toIso8601String(),
        'questions': [
          for (final entry in lesson.results.entries)
            if (entry.key >= 0 && entry.key < (lesson.blocks?.length ?? 0))
              {'block': lesson.blocks![entry.key].toJson(), 'correct': entry.value},
        ],
      }];
    }
    lesson.blocks = blocks;
    lesson.stepIndex = lesson.stepIndex.clamp(0, blocks.length - 1);
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

  // --- Gia su hoi dap (mot man chat chung, nhieu cuoc tro chuyen) ---
  final Set<String> _pendingThreads = {};
  final Map<String, int> _threadRuns = {};

  bool isThreadBusy(ChatThread thread) => _pendingThreads.contains(thread.id);

  /// Cuoc tro chuyen moi voi ngu canh [lessonId] (null = ca khoa). Dung lai cuoc dang trong neu co.
  ChatThread newThread(Course course, {String? lessonId}) {
    final empty = course.threads.where((t) => t.messages.isEmpty && !isThreadBusy(t)).firstOrNull;
    if (empty != null) {
      empty.lessonId = lessonId;
      return empty;
    }
    final thread = ChatThread(id: _uuid.v4(), lessonId: lessonId);
    course.threads.add(thread);
    return thread;
  }

  /// Cuoc tro chuyen gan nhat cua ngu canh nay, khong co thi tao moi.
  ChatThread latestThread(Course course, {String? lessonId}) =>
      course.threads.where((t) => t.lessonId == lessonId && t.messages.isNotEmpty).lastOrNull ?? newThread(course, lessonId: lessonId);

  /// Gui cau hoi: them tin nguoi hoc, goi AI, them cau tra loi (chuoi khoi). Loi thi bo tin nguoi hoc va nem loi.
  /// [web]: cho tra cuu them tren mang (mac dinh theo cai dat cua khoa). [socratic]: che do Goi mo.
  Future<void> sendChat(Course course, ChatThread thread, String question, {bool? web, bool socratic = false}) async {
    if (isThreadBusy(thread)) return;
    final useWeb = web ?? course.allowWeb;
    final lesson = course.lessonById(thread.lessonId);
    final history = thread.messages.takeLast(8).map((m) => {'from': m.fromUser ? 'user' : 'tutor', 'text': m.plainText}).toList();
    final userMsg = ChatMessage(fromUser: true, text: question, webMode: useWeb ? 'requested' : 'off');
    thread.messages.add(userMsg);
    if (thread.title.isEmpty) thread.title = ChatThread.titleFor(question);
    thread.updatedAt = DateTime.now();
    if (!course.threads.contains(thread)) course.threads.add(thread);
    final run = (_threadRuns[thread.id] ?? 0) + 1;
    _threadRuns[thread.id] = run;
    _pendingThreads.add(thread.id);
    notifyListeners();
    try {
      final blocks = lesson?.blocks;
      final out = await (useWeb ? api.ask : api.studyAsk)({
        'role': _roleId,
        'subject': course.subject,
        if (lesson != null) 'lessonTitle': lesson.title,
        if (blocks != null && blocks.isNotEmpty) 'step': blocks[lesson!.stepIndex.clamp(0, blocks.length - 1)].title ?? '',
        'question': question,
        'history': history,
        'webSearch': useWeb,
        'socratic': socratic,
        ...course.materialJson(),
      });
      if (_threadRuns[thread.id] != run) return; // nguoi hoc da bam dung
      final answer = Block.parseList(out['blocks']);
      if (answer.isEmpty) throw ApiException('Chưa nhận được câu trả lời.');
      thread.messages.add(ChatMessage(
        fromUser: false,
        blocks: answer,
        web: ((out['web'] as List?) ?? []).whereType<Map>().map((e) => WebSource.fromJson(Map<String, dynamic>.from(e))).toList(),
        webMode: out['webMode'] ?? 'off',
        intent: (() {
          final local = detectIntent(question);
          return local != ChatIntent.none ? local.id : ChatIntent.fromId(out['intent']).id;
        })(),
      ));
      thread.updatedAt = DateTime.now();
      _bumpActivity();
    } catch (_) {
      if (_threadRuns[thread.id] != run) return;
      thread.messages.remove(userMsg);
      rethrow;
    } finally {
      if (_threadRuns[thread.id] == run) _pendingThreads.remove(thread.id);
      notifyListeners();
    }
    if (courses.contains(course)) await _save();
  }

  /// Dung cau tra loi dang sinh: giu cau hoi, bo qua ket qua khi ve.
  Future<void> stopChat(ChatThread thread) async {
    if (!isThreadBusy(thread)) return;
    _threadRuns[thread.id] = (_threadRuns[thread.id] ?? 0) + 1;
    _pendingThreads.remove(thread.id);
    notifyListeners();
    await _save();
  }

  /// Tao lai cau tra loi cuoi. Loi thi tra lai cau tra loi cu.
  Future<void> regenerateChat(Course course, ChatThread thread, {bool? web, bool socratic = false}) async {
    final index = thread.messages.lastIndexWhere((m) => m.fromUser);
    if (index < 0 || isThreadBusy(thread)) return;
    final removed = thread.messages.sublist(index);
    thread.messages.removeRange(index, thread.messages.length);
    try {
      await sendChat(course, thread, removed.first.text, web: web, socratic: socratic);
    } catch (_) {
      thread.messages.addAll(removed);
      notifyListeners();
      rethrow;
    }
  }

  /// Sua cau hoi: bo tin nhan tu [index] tro di, tra ve noi dung de dien lai vao o nhap.
  Future<String> editChatFrom(ChatThread thread, int index) async {
    if (index < 0 || index >= thread.messages.length || isThreadBusy(thread)) return '';
    final text = thread.messages[index].text;
    thread.messages.removeRange(index, thread.messages.length);
    notifyListeners();
    await _save();
    return text;
  }

  /// Ghi ket qua tro choi Ghep nhanh. Tra ve true neu la ky luc moi.
  Future<bool> recordMatchTime(Course course, int ms) async {
    final best = course.bestMatchMs;
    if (best != null && best <= ms) return false;
    course.bestMatchMs = ms;
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> deleteThread(Course course, ChatThread thread) async {
    _threadRuns[thread.id] = (_threadRuns[thread.id] ?? 0) + 1;
    _pendingThreads.remove(thread.id);
    course.threads.remove(thread);
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
    _bumpActivity();
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
    final out = await api.research(topic, '');
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
    if (selectedCourseId == c.id) selectedCourseId = courses.firstOrNull?.id;
    notifyListeners();
    await _save();
  }

  Future<void> clearAll() async {
    courses.clear();
    selectedCourseId = null;
    role = null;
    notifyListeners();
    await _save();
  }

  // --- Thong ke su dung (bang chung cho BGK) ---
  int get totalLessonsGenerated => courses.fold(0, (s, c) => s + c.lessons.where((l) => l.blocks != null).length);
  int get totalAnswered => courses.fold(0, (s, c) => s + c.lessons.fold(0, (t, l) => t + l.results.length));
  int get totalCorrect => courses.fold(0, (s, c) => s + c.lessons.fold(0, (t, l) => t + l.correctCount));
}

extension on List<ChatMessage> {
  Iterable<ChatMessage> takeLast(int count) => skip(length > count ? length - count : 0);
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
