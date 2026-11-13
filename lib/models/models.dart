// Mo hinh du lieu. JSON cua Block khop voi schema o server/lib/schemas.js (truong snake_case).

enum UserRole {
  student('student', 'Sinh viên', 'Ôn thi từ slide bài giảng'),
  pupil('pupil', 'Học sinh', 'Ôn bài theo sách giáo khoa, đề thi'),
  worker('worker', 'Người đi làm', 'Ôn chứng chỉ, học kỹ năng'),
  teacher('teacher', 'Giáo viên / gia sư', 'Soạn bài và bài tập cho học sinh');

  const UserRole(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;

  static UserRole? fromId(String? id) {
    for (final r in values) {
      if (r.id == id) return r;
    }
    return null;
  }
}

double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;
List<String> _strs(Object? v) => v is List ? v.map((e) => '$e').toList() : <String>[];
List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

class WebSource {
  WebSource({required this.title, required this.url, required this.domain, required this.snippet, required this.trusted,
    this.id, this.extract = '', this.category = '', this.publisher = '', this.retrievedAt});
  final String title;
  final String url;
  final String domain;
  final String snippet;
  final bool trusted;
  final String? id, retrievedAt;
  final String extract, category, publisher;

  factory WebSource.fromJson(Map<String, dynamic> j) => WebSource(
        title: j['title'] ?? '',
        url: j['url'] ?? '',
        domain: j['domain'] ?? '',
        snippet: j['snippet'] ?? '',
        trusted: j['trust'] == 'trusted' || j['trusted'] == true,
        id: j['id'],
        extract: j['extract'] ?? '',
        category: j['category'] ?? '',
        publisher: j['publisher'] ?? '',
        retrievedAt: j['retrieved_at'],
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'url': url, 'domain': domain, 'snippet': snippet, 'extract': extract,
        'category': category, 'publisher': publisher, 'retrieved_at': retrievedAt, 'trust': trusted ? 'trusted' : 'check'};
}

class LabVar {
  LabVar({required this.name, required this.label, required this.unit, required this.min, required this.max, required this.step, required this.defaultValue});
  final String name, label, unit;
  final double min, max, step, defaultValue;

  factory LabVar.fromJson(Map<String, dynamic> j) {
    final min = _d(j['min']), max = _d(j['max'], 1);
    return LabVar(
      name: j['name'] ?? 'x',
      label: j['label'] ?? j['name'] ?? '',
      unit: j['unit'] ?? '',
      min: min,
      max: max,
      step: _d(j['step'], 1),
      defaultValue: _d(j['default'], min).clamp(min, max).toDouble(),
    );
  }
  Map<String, dynamic> toJson() =>
      {'name': name, 'label': label, 'unit': unit, 'min': min, 'max': max, 'step': step, 'default': defaultValue};
}

class Lab {
  Lab({required this.formula, required this.resultLabel, required this.resultUnit, required this.variables});
  final String formula, resultLabel, resultUnit;
  final List<LabVar> variables;

  factory Lab.fromJson(Map<String, dynamic> j) => Lab(
        formula: j['formula'] ?? '',
        resultLabel: j['result_label'] ?? 'Kết quả',
        resultUnit: j['result_unit'] ?? '',
        variables: ((j['variables'] as List?) ?? []).map((e) => LabVar.fromJson(e)).toList(),
      );
  Map<String, dynamic> toJson() => {
        'formula': formula,
        'result_label': resultLabel,
        'result_unit': resultUnit,
        'variables': variables.map((v) => v.toJson()).toList(),
      };
}

class Graph {
  Graph({required this.expression, required this.xMin, required this.xMax, required this.params, this.extraExpressions = const [], this.tools = const []});
  final String expression;
  final double xMin, xMax;
  final List<LabVar> params;

  /// Ham phu de so sanh (toi da 2).
  final List<String> extraExpressions;

  /// Cong cu kham pha: tangent, area, roots, extrema.
  final List<String> tools;

  factory Graph.fromJson(Map<String, dynamic> j) => Graph(
        expression: j['expression'] ?? 'x',
        xMin: _d(j['x_min'], -10),
        xMax: _d(j['x_max'], 10),
        params: ((j['params'] as List?) ?? []).map((e) => LabVar.fromJson(e)).toList(),
        extraExpressions: _strs(j['extra_expressions']),
        tools: _strs(j['tools']),
      );
  Map<String, dynamic> toJson() => {
        'expression': expression,
        'x_min': xMin,
        'x_max': xMax,
        'params': params.map((v) => v.toJson()).toList(),
        'extra_expressions': extraExpressions,
        'tools': tools,
      };
}

enum BlockType {
  textSection, mcq, trueFalse, fillBlank, matching, ordering, formulaLab, functionGraph, flashcards,
  stepSolver, conceptMap, imageCard, reactionLab, chemFormula, motionSim, customSim, codeDemo, dsaSim,
}

const _blockTypeIds = {
  'dsa_sim': BlockType.dsaSim,
  'step_solver': BlockType.stepSolver,
  'concept_map': BlockType.conceptMap,
  'image_card': BlockType.imageCard,
  'reaction_lab': BlockType.reactionLab,
  'chem_formula': BlockType.chemFormula,
  'motion_sim': BlockType.motionSim,
  'custom_sim': BlockType.customSim,
  'code_demo': BlockType.codeDemo,
  'text_section': BlockType.textSection,
  'mcq': BlockType.mcq,
  'true_false': BlockType.trueFalse,
  'fill_blank': BlockType.fillBlank,
  'matching': BlockType.matching,
  'ordering': BlockType.ordering,
  'formula_lab': BlockType.formulaLab,
  'function_graph': BlockType.functionGraph,
  'flashcards': BlockType.flashcards,
};

class Block {
  Block({
    required this.type,
    required this.typeId,
    this.topic = '',
    this.title,
    this.body,
    this.options = const [],
    this.answerIndex,
    this.answerBool,
    this.answers = const [],
    this.pairs = const [],
    this.items = const [],
    this.cards = const [],
    this.lab,
    this.graph,
    this.explanation,
    this.sourceQuote,
    this.sourcePage,
    this.sourceUrl,
    this.raw = const {},
    this.sim,
  });

  /// JSON goc cua khoi (cac bo may moi doc truc tiep tu day; luu lai nguyen ven).
  final Map<String, dynamic> raw;

  /// custom_sim: HTML mo phong da sinh {title, instructions, html}, luu de mo lai khong goi AI.
  Map<String, dynamic>? sim;

  Map<String, dynamic>? rawMap(String key) => raw[key] is Map ? Map<String, dynamic>.from(raw[key]) : null;
  List<Map<String, dynamic>> rawList(String key) =>
      raw[key] is List ? (raw[key] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  final BlockType type;
  final String typeId;
  final String topic;
  final String? title, body, explanation, sourceQuote, sourceUrl;
  String? get sourceId => raw['source_id'] is String ? raw['source_id'] as String : null;
  String get questionId => raw['id']?.toString() ?? '';
  final List<String> options, answers, items;
  final int? answerIndex, sourcePage;
  final bool? answerBool;
  final List<(String, String)> pairs;
  final List<(String, String)> cards;
  final Lab? lab;
  final Graph? graph;

  /// Cac khoi co cham diem dung/sai.
  bool get isGraded => const {BlockType.mcq, BlockType.trueFalse, BlockType.fillBlank, BlockType.matching, BlockType.ordering}.contains(type);

  /// Khoi tuong tac/thuc nghiem (dung cho thong ke va nut "Kham pha them").
  bool get isInteractive => const {
        BlockType.formulaLab, BlockType.functionGraph, BlockType.reactionLab, BlockType.chemFormula,
        BlockType.motionSim, BlockType.stepSolver, BlockType.conceptMap, BlockType.customSim, BlockType.dsaSim,
      }.contains(type);

  /// Tra ve null neu loai khoi khong co trong danh muc (bo qua an toan).
  static Block? tryParse(Map<String, dynamic> j) {
    final type = _blockTypeIds[j['type']];
    if (type == null) return null;
    List<(String, String)> twoCols(Object? v, String a, String b) =>
        v is List ? v.whereType<Map>().map((e) => ('${e[a] ?? ''}', '${e[b] ?? ''}')).toList() : [];
    return Block(
      type: type,
      typeId: j['type'],
      topic: j['topic'] ?? '',
      title: j['title'],
      body: j['body'],
      options: _strs(j['options']),
      answerIndex: j['answer_index'] is int ? j['answer_index'] : null,
      answerBool: j['answer_bool'] is bool ? j['answer_bool'] : null,
      answers: _strs(j['answers']),
      pairs: twoCols(j['pairs'], 'left', 'right'),
      items: _strs(j['items']),
      cards: twoCols(j['cards'], 'front', 'back'),
      lab: j['lab'] is Map ? Lab.fromJson(Map<String, dynamic>.from(j['lab'])) : null,
      graph: j['graph'] is Map ? Graph.fromJson(Map<String, dynamic>.from(j['graph'])) : null,
      explanation: j['explanation'],
      sourceQuote: j['source_quote'],
      sourcePage: j['source_page'] is int ? j['source_page'] : null,
      sourceUrl: j['source_url'],
      raw: Map<String, dynamic>.from(j)..remove('sim'),
      sim: j['sim'] is Map ? Map<String, dynamic>.from(j['sim']) : null,
    );
  }

  static List<Block> parseList(Object? v) => v is List
      ? v.whereType<Map>().map((e) => tryParse(Map<String, dynamic>.from(e))).whereType<Block>().toList()
      : [];

  Map<String, dynamic> toJson() => {
        ...raw,
        'type': typeId,
        'topic': topic,
        'title': title,
        'body': body,
        'options': options,
        'answer_index': answerIndex,
        'answer_bool': answerBool,
        'answers': answers,
        'pairs': [for (final p in pairs) {'left': p.$1, 'right': p.$2}],
        'items': items,
        'cards': [for (final c in cards) {'front': c.$1, 'back': c.$2}],
        'lab': lab?.toJson(),
        'graph': graph?.toJson(),
        'explanation': explanation,
        'source_quote': sourceQuote,
        'source_page': sourcePage,
        'source_url': sourceUrl,
        if (sim != null) 'sim': sim,
      };
}

class Lesson {
  Lesson({required this.id, required this.title, this.objectives = const [], this.minutes = 15, this.interactionHint = '', this.blocks,
    Map<int, bool>? results, List<ChatMessage>? chat, this.phase = '', this.prerequisites = const [], this.sourceIds = const [],
    this.stepIndex = 0, this.completed = false, this.lastStudiedAt, this.scheduledAt, this.previousResults = const [],
    this.quizCorrect = 0, this.quizTotal = 0})
      : results = results ?? {},
        chat = chat ?? [];
  final String id;
  String title;
  final List<String> objectives;
  final int minutes;
  final String phase;
  final List<String> prerequisites, sourceIds;
  int stepIndex;
  bool completed;
  DateTime? lastStudiedAt, scheduledAt;
  List<Map<String, dynamic>> previousResults;

  /// Diem lan lam quiz gan nhat cua bai (tinh vao muc nam vung).
  int quizCorrect, quizTotal;

  /// Goi y kieu tuong tac AI de xuat khi len lo trinh.
  final String interactionHint;

  /// null = chua sinh noi dung.
  List<Block>? blocks;

  /// Ket qua theo chi so khoi: true = dung lan dau, false = sai.
  final Map<int, bool> results;

  /// Lich su hoi dap voi gia su AI trong bai nay.
  final List<ChatMessage> chat;

  int get gradedCount => blocks?.where((b) => b.isGraded).length ?? 0;
  int get correctCount => results.values.where((v) => v).length;
  bool get isDone => completed;

  factory Lesson.fromJson(Map<String, dynamic> j) {
    final lesson = Lesson(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        objectives: _strs(j['objectives']),
        minutes: j['minutes'] is int ? j['minutes'] : 15,
        interactionHint: j['interaction_hint'] ?? '',
        blocks: j['blocks'] == null ? null : Block.parseList(j['blocks']),
        results: {
          for (final e in ((j['results'] as Map?) ?? {}).entries)
            if (int.tryParse('${e.key}') case final int index) index: e.value == true,
        },
        chat: ((j['chat'] as List?) ?? []).whereType<Map>().map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e))).toList(),
        phase: j['phase'] ?? '',
        prerequisites: _strs(j['prerequisites']),
        sourceIds: _strs(j['source_ids']),
        stepIndex: j['step_index'] is int ? j['step_index'] : 0,
        lastStudiedAt: DateTime.tryParse(j['last_studied_at'] ?? ''),
        scheduledAt: DateTime.tryParse(j['scheduled_at'] ?? ''),
        previousResults: _maps(j['previous_results']),
        quizCorrect: j['quiz_correct'] is int ? j['quiz_correct'] : 0,
        quizTotal: j['quiz_total'] is int ? j['quiz_total'] : 0,
      );
    lesson.completed = j['completed'] as bool? ??
        (lesson.gradedCount > 0 && lesson.results.length >= lesson.gradedCount);
    return lesson;
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'objectives': objectives,
        'minutes': minutes,
        'interaction_hint': interactionHint,
        'blocks': blocks?.map((b) => b.toJson()).toList(),
        'results': {for (final e in results.entries) '${e.key}': e.value},
        'chat': chat.map((m) => m.toJson()).toList(),
        'phase': phase,
        'prerequisites': prerequisites,
        'source_ids': sourceIds,
        'step_index': stepIndex,
        'completed': completed,
        'last_studied_at': lastStudiedAt?.toIso8601String(),
        'scheduled_at': scheduledAt?.toIso8601String(),
        'previous_results': previousResults,
        'quiz_correct': quizCorrect,
        'quiz_total': quizTotal,
      };

  /// Dang gui len server (khong kem noi dung khoi).
  Map<String, dynamic> toOutlineJson() =>
      {'id': id, 'title': title, 'objectives': objectives, 'minutes': minutes, 'interaction_hint': interactionHint,
        'phase': phase, 'prerequisites': prerequisites, 'source_ids': sourceIds};
}

enum SourceKind { file, text, web }

class StudyBrief {
  const StudyBrief({required this.topic, this.goal = 'Học nền tảng', this.minutesPerDay = 30,
    this.level = 'Mới bắt đầu', this.scope = '', this.examDate, this.searchWeb = true});

  final String topic, goal, level, scope;
  final int minutesPerDay;
  final DateTime? examDate;
  final bool searchWeb;

  factory StudyBrief.fromJson(Map<String, dynamic> json) => StudyBrief(
    topic: json['topic'] ?? '',
    goal: json['goal'] ?? 'Học nền tảng',
    level: json['level'] ?? 'Mới bắt đầu',
    scope: json['scope'] ?? '',
    minutesPerDay: json['minutes_per_day'] ?? 30,
    examDate: DateTime.tryParse(json['exam_date'] ?? ''),
    searchWeb: json['search_web'] != false,
  );

  Map<String, dynamic> toJson() => {
    'topic': topic, 'goal': goal, 'level': level, 'scope': scope,
    'minutes_per_day': minutesPerDay, 'exam_date': examDate?.toIso8601String().split('T').first,
    'search_web': searchWeb,
  };
}

enum StudyArtifactKind {
  summary('summary', 'Tóm tắt'),
  quickQuiz('quick_quiz', 'Quiz nhanh'),
  interactiveQuiz('interactive_quiz', 'Quiz tương tác'),
  flashcards('flashcards', 'Thẻ ghi nhớ'),
  note('note', 'Ghi chú'),
  quiz('quiz', 'Quiz'),
  canvas('canvas', 'Canvas');

  const StudyArtifactKind(this.id, this.label);
  final String id, label;

  bool get isQuiz => this == quickQuiz || this == interactiveQuiz || this == quiz;
}

/// Cau hinh mot bai quiz: so cau theo loai, do kho, kieu giai thich, chu de trong tam.
class QuizSpec {
  const QuizSpec({required this.counts, this.difficulty = 'medium', this.explain = 'brief', this.focus = '', this.lessonId});

  static const types = ['mcq', 'true_false', 'fill_blank', 'matching', 'ordering', 'passage'];
  static const maxQuestions = 15;

  /// So cau theo loai; 'passage' la doan van 3 tang, moi doan tinh 3 cau.
  final Map<String, int> counts;
  final String difficulty, explain, focus;
  final String? lessonId;

  int get total => counts.entries.fold(0, (sum, e) => sum + e.value * (e.key == 'passage' ? 3 : 1));

  QuizSpec copyWith({Map<String, int>? counts, String? difficulty, String? explain, String? focus, String? lessonId, bool clearLesson = false}) =>
      QuizSpec(counts: counts ?? this.counts, difficulty: difficulty ?? this.difficulty, explain: explain ?? this.explain,
          focus: focus ?? this.focus, lessonId: clearLesson ? null : lessonId ?? this.lessonId);

  factory QuizSpec.fromJson(Map<String, dynamic> json) => QuizSpec(
    counts: {for (final e in (json['counts'] as Map? ?? {}).entries) if (e.value is int) '${e.key}': e.value as int},
    difficulty: json['difficulty'] ?? 'medium', explain: json['explain'] ?? 'brief', focus: json['focus'] ?? '',
    lessonId: json['lesson_id'] as String?,
  );
  Map<String, dynamic> toJson() => {'counts': counts, 'difficulty': difficulty, 'explain': explain, 'focus': focus,
    if (lessonId != null) 'lesson_id': lessonId};
}

class QuizAttempt {
  QuizAttempt({required this.id, required this.results, required this.total, DateTime? at})
      : at = at ?? DateTime.now();

  final String id;
  final Map<String, bool> results;
  final int total;
  final DateTime at;
  int get score => results.values.where((correct) => correct).length;

  factory QuizAttempt.fromJson(Map<String, dynamic> json) => QuizAttempt(
    id: json['id'] ?? '', total: json['total'] ?? 0,
    results: Map<String, bool>.from(json['results'] as Map? ?? {}),
    at: DateTime.tryParse(json['at'] ?? ''),
  );
  Map<String, dynamic> toJson() => {'id': id, 'total': total, 'results': results, 'at': at.toIso8601String()};
}

class StudyArtifact {
  StudyArtifact({required this.id, required this.kind, required this.title, required this.blocks,
    this.sourceIds = const [], this.sourceFingerprint = '', this.webOnly = false,
    this.version = 1, DateTime? createdAt, List<QuizAttempt>? attempts, this.lessonId, this.spec})
      : createdAt = createdAt ?? DateTime.now(), attempts = attempts ?? [];

  final String id, title, sourceFingerprint;
  final StudyArtifactKind kind;
  final List<Block> blocks;
  final List<String> sourceIds;
  final bool webOnly;
  final int version;
  final DateTime createdAt;
  final List<QuizAttempt> attempts;

  /// Quiz tao cho mot bai trong lo trinh (null = ca so).
  final String? lessonId;

  /// Yeu cau da dung de tao quiz, de tao lai cung cau hinh.
  final QuizSpec? spec;

  String questionKey(int index) {
    final key = blocks[index].questionId;
    return key.isEmpty ? '$id-$index' : key;
  }

  factory StudyArtifact.fromJson(Map<String, dynamic> json) => StudyArtifact(
    id: json['id'] ?? '', title: json['title'] ?? '',
    kind: StudyArtifactKind.values.firstWhere((k) => k.id == json['kind'], orElse: () => StudyArtifactKind.note),
    blocks: Block.parseList(json['blocks']), sourceIds: _strs(json['source_ids']),
    sourceFingerprint: json['source_fingerprint'] ?? '', webOnly: json['web_only'] == true,
    version: json['version'] ?? 1, createdAt: DateTime.tryParse(json['created_at'] ?? ''),
    attempts: _maps(json['attempts']).map(QuizAttempt.fromJson).toList(),
    lessonId: json['lesson_id'] as String?,
    spec: json['spec'] is Map ? QuizSpec.fromJson(Map<String, dynamic>.from(json['spec'])) : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'kind': kind.id, 'blocks': blocks.map((block) => block.toJson()).toList(),
    'source_ids': sourceIds, 'source_fingerprint': sourceFingerprint, 'web_only': webOnly,
    'version': version, 'created_at': createdAt.toIso8601String(),
    'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
    if (lessonId != null) 'lesson_id': lessonId,
    if (spec != null) 'spec': spec!.toJson(),
  };
}

/// Mot nguon cua khoa hoc (kieu NotebookLM): file PDF/anh, van ban dan vao, hoac trang web.
/// [enabled] = dang duoc chon: AI chi dung cac nguon dang bat.
class CourseSource {
  CourseSource({
    required this.id,
    required this.kind,
    required this.title,
    this.fileId,
    this.mimeType,
    this.text,
    this.url,
    this.domain = '',
    this.snippet = '',
    this.trusted = false,
    this.enabled = true,
    this.extract = '',
    this.category = '',
    this.publisher = '',
    this.retrievedAt,
    this.storagePath,
    this.removed = false,
    this.pages = const [],
  });

  final String id;
  final SourceKind kind;
  final String title;
  final String? fileId, mimeType, text, url;
  final String domain, snippet;
  final String extract, category, publisher;
  final String? retrievedAt, storagePath;
  final List<Map<String, dynamic>> pages;
  final bool trusted;
  bool enabled;
  bool removed;

  factory CourseSource.fromWeb(WebSource w) => CourseSource(
        id: w.id ?? 'web:${w.url}',
        kind: SourceKind.web,
        title: w.title,
        url: w.url,
        domain: w.domain,
        snippet: w.snippet,
        trusted: w.trusted,
        extract: w.extract,
        category: w.category,
        publisher: w.publisher,
        retrievedAt: w.retrievedAt,
      );

  WebSource toWeb() => WebSource(id: id, title: title, url: url ?? '', domain: domain, snippet: snippet,
    trusted: trusted, extract: extract, category: category, publisher: publisher, retrievedAt: retrievedAt);

  factory CourseSource.fromJson(Map<String, dynamic> j) => CourseSource(
        id: j['id'] ?? '${j['kind']}:${j['title']}',
        kind: SourceKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => SourceKind.text),
        title: j['title'] ?? '',
        fileId: j['fileId'],
        mimeType: j['mimeType'],
        text: j['text'],
        url: j['url'],
        domain: j['domain'] ?? '',
        snippet: j['snippet'] ?? '',
        trusted: j['trust'] == 'trusted' || j['trusted'] == true,
        enabled: j['enabled'] != false,
        extract: j['extract'] ?? '',
        category: j['category'] ?? '',
        publisher: j['publisher'] ?? '',
        retrievedAt: j['retrieved_at'],
        storagePath: j['storage_path'],
        removed: j['removed'] == true,
        pages: _maps(j['pages']),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'fileId': fileId,
        'mimeType': mimeType,
        'text': text,
        'url': url,
        'domain': domain,
        'snippet': snippet,
        'trust': trusted ? 'trusted' : 'check',
        'enabled': enabled,
        'extract': extract,
        'category': category,
        'publisher': publisher,
        'retrieved_at': retrievedAt,
        'storage_path': storagePath,
        'removed': removed,
        if (pages.isNotEmpty) 'pages': pages,
      };
}

class Course {
  Course({
    required this.id,
    required this.title,
    required this.goal,
    required this.createdAt,
    required this.lessons,
    this.language = '',
    this.subject = '',
    List<CourseSource>? sources,
    this.allowWeb = false,
    this.brief,
    this.researchDone = false,
    this.researchMode = '',
    this.missingCategories = const [],
    this.isSample = false,
    List<ChatMessage>? notebookChat,
    List<StudyArtifact>? artifacts,
  }) : sources = sources ?? [], notebookChat = notebookChat ?? [], artifacts = artifacts ?? [];

  final String id;
  String title;
  String goal, language;

  /// Mon hoc do AI nhan dien khi len lo trinh (dung de chon bo may tuong tac).
  String subject;
  final DateTime createdAt;
  final List<Lesson> lessons;

  /// Tat ca nguon cua khoa hoc (file, van ban, web), bat/tat duoc tung nguon.
  final List<CourseSource> sources;

  /// Mac dinh cho gia su: co duoc tra cuu them tren mang khong (mac dinh tat: chi dua vao nguon da nap).
  bool allowWeb;
  StudyBrief? brief;
  bool researchDone;
  String researchMode;
  List<String> missingCategories;
  final bool isSample;
  final List<ChatMessage> notebookChat;
  final List<StudyArtifact> artifacts;

  List<CourseSource> get activeSources => sources.where((s) => !s.removed).toList();
  List<CourseSource> get enabledSources => activeSources.where((s) => s.enabled).toList();

  int get doneLessons => lessons.where((l) => l.isDone).length;

  String get sourceLabel {
    if (id == 'sample-ohm') return 'Khóa mẫu';
    final on = enabledSources;
    if (on.length == 1) return on.first.title;
    final files = on.where((s) => s.kind == SourceKind.file).length;
    final web = on.where((s) => s.kind == SourceKind.web).length;
    final text = on.where((s) => s.kind == SourceKind.text).length;
    return [if (files > 0) '$files tài liệu', if (web > 0) '$web nguồn web', if (text > 0) '$text văn bản'].join(' · ');
  }

  /// Chu de yeu: chu de cua cac cau tra loi sai.
  Map<String, int> get weakTopics {
    final m = <String, int>{};
    for (final l in lessons) {
      final bs = l.blocks;
      if (bs == null) continue;
      l.results.forEach((i, ok) {
        if (!ok && i < bs.length && bs[i].topic.isNotEmpty) m[bs[i].topic] = (m[bs[i].topic] ?? 0) + 1;
      });
    }
    return m;
  }

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'],
        title: j['title'] ?? '',
        goal: j['goal'] ?? '',
        language: j['language'] ?? '',
        subject: j['subject'] ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
        lessons: ((j['lessons'] as List?) ?? []).map((e) => Lesson.fromJson(Map<String, dynamic>.from(e))).toList(),
        sources: _sourcesFromJson(j),
        allowWeb: j['allowWeb'] == true,
        brief: j['brief'] is Map ? StudyBrief.fromJson(Map<String, dynamic>.from(j['brief'])) : null,
        researchDone: j['research_done'] == true,
        researchMode: j['research_mode'] ?? '',
        missingCategories: _strs(j['missing_categories']),
        isSample: j['is_sample'] == true || j['id'] == 'sample-ohm',
        notebookChat: _maps(j['notebook_chat']).map(ChatMessage.fromJson).toList(),
        artifacts: _maps(j['artifacts']).map(StudyArtifact.fromJson).toList(),
      );

  /// Doc nguon; ho tro du lieu ban cu (fileId/fileName/text/sources web rieng le).
  static List<CourseSource> _sourcesFromJson(Map<String, dynamic> j) {
    final raw = (j['sources'] as List?) ?? [];
    if (raw.isNotEmpty && raw.first is Map && (raw.first as Map).containsKey('kind')) {
      return raw.whereType<Map>().map((e) => CourseSource.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    return [
      if (j['fileId'] != null)
        CourseSource(id: 'file:${j['fileId']}', kind: SourceKind.file, title: j['fileName'] ?? 'Tài liệu', fileId: j['fileId'], mimeType: j['mimeType']),
      if (j['text'] != null) CourseSource(id: 'text:0', kind: SourceKind.text, title: 'Văn bản dán vào', text: j['text']),
      ...raw.whereType<Map>().map((e) => CourseSource.fromWeb(WebSource.fromJson(Map<String, dynamic>.from(e)))),
    ];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'goal': goal,
        'language': language,
        'subject': subject,
        'createdAt': createdAt.toIso8601String(),
        'lessons': lessons.map((l) => l.toJson()).toList(),
        'sources': sources.map((s) => s.toJson()).toList(),
        'allowWeb': allowWeb,
        'brief': brief?.toJson(),
        'research_done': researchDone,
        'research_mode': researchMode,
        'missing_categories': missingCategories,
        'is_sample': isSample,
        'notebook_chat': notebookChat.map((m) => m.toJson()).toList(),
        'artifacts': artifacts.map((a) => a.toJson()).toList(),
      };

  /// Dau vao gui kem moi lan goi AI: chi cac nguon DANG BAT (kieu NotebookLM).
  Map<String, dynamic> materialJson({bool webOnly = false}) {
    final on = webOnly ? enabledSources.where((s) => s.kind == SourceKind.web) : enabledSources;
    final files = on.where((s) => s.kind == SourceKind.file && (s.fileId != null || s.storagePath != null)).toList();
    final texts = on.where((s) => s.kind == SourceKind.text && (s.text ?? '').isNotEmpty).toList();
    final web = on.where((s) => s.kind == SourceKind.web && s.url != null).toList();
    return {
      'notebook_id': id,
      if (files.isNotEmpty) 'files': [for (final f in files) {'id': f.id, 'fileId': f.fileId,
        'storage_path': f.storagePath, 'mimeType': f.mimeType, 'name': f.title,
        if (f.pages.isNotEmpty) 'pages': f.pages}],
      if (texts.isNotEmpty) 'text': texts.map((t) => texts.length > 1 ? '### ${t.title}\n${t.text}' : t.text).join('\n\n'),
      if (texts.isNotEmpty) 'texts': [for (final t in texts) {'id': t.id, 'title': t.title, 'text': t.text}],
      if (web.isNotEmpty) 'sources': [for (final w in web) w.toWeb().toJson()],
    };
  }
}

/// Mot tin nhan trong cuoc hoi dap voi gia su AI.
/// Tin cua nguoi hoc: chi co [text]. Tin cua gia su: chuoi khoi [blocks] (hien bang BlockRenderer).
class ChatMessage {
  ChatMessage({required this.fromUser, this.text = '', this.blocks = const [], this.web = const [], this.webMode = 'off', DateTime? at})
      : at = at ?? DateTime.now();
  final bool fromUser;
  final String text;
  final List<Block> blocks;
  final DateTime at;

  /// Nguon web da tra cuu cho cau tra loi nay (rong neu chi dung nguon da nap).
  final List<WebSource> web;

  /// 'off' (chi nguon da nap), 'search' (cong cu tim kiem cua AI), 'wikipedia' (du phong), 'requested' (tin nguoi hoc co bat web).
  final String webMode;

  /// Phan chu de gui lai lam ngu canh (tom tat cau tra loi cua gia su).
  String get plainText => fromUser
      ? text
      : blocks.map((b) => b.body ?? b.title ?? '').where((s) => s.isNotEmpty).join('\n').trim();

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        fromUser: j['from'] == 'user',
        text: j['text'] ?? '',
        blocks: Block.parseList(j['blocks']),
        web: ((j['web'] as List?) ?? []).whereType<Map>().map((e) => WebSource.fromJson(Map<String, dynamic>.from(e))).toList(),
        webMode: j['webMode'] ?? 'off',
        at: DateTime.tryParse(j['at'] ?? ''),
      );
  Map<String, dynamic> toJson() => {
        'from': fromUser ? 'user' : 'tutor',
        'text': text,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'web': web.map((w) => w.toJson()).toList(),
        'webMode': webMode,
        'at': at.toIso8601String(),
      };
}
