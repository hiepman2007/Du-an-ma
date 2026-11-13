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

class WebSource {
  WebSource({required this.title, required this.url, required this.domain, required this.snippet, required this.trusted});
  final String title;
  final String url;
  final String domain;
  final String snippet;
  final bool trusted;

  factory WebSource.fromJson(Map<String, dynamic> j) => WebSource(
        title: j['title'] ?? '',
        url: j['url'] ?? '',
        domain: j['domain'] ?? '',
        snippet: j['snippet'] ?? '',
        trusted: j['trust'] == 'trusted' || j['trusted'] == true,
      );
  Map<String, dynamic> toJson() =>
      {'title': title, 'url': url, 'domain': domain, 'snippet': snippet, 'trust': trusted ? 'trusted' : 'check'};
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
  stepSolver, conceptMap, imageCard, reactionLab, chemFormula, motionSim, customSim,
}

const _blockTypeIds = {
  'step_solver': BlockType.stepSolver,
  'concept_map': BlockType.conceptMap,
  'image_card': BlockType.imageCard,
  'reaction_lab': BlockType.reactionLab,
  'chem_formula': BlockType.chemFormula,
  'motion_sim': BlockType.motionSim,
  'custom_sim': BlockType.customSim,
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
        BlockType.motionSim, BlockType.stepSolver, BlockType.conceptMap, BlockType.customSim,
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
  Lesson({required this.id, required this.title, this.objectives = const [], this.minutes = 15, this.interactionHint = '', this.blocks, Map<int, bool>? results})
      : results = results ?? {};
  final String id;
  String title;
  final List<String> objectives;
  final int minutes;

  /// Goi y kieu tuong tac AI de xuat khi len lo trinh.
  final String interactionHint;

  /// null = chua sinh noi dung.
  List<Block>? blocks;

  /// Ket qua theo chi so khoi: true = dung lan dau, false = sai.
  final Map<int, bool> results;

  int get gradedCount => blocks?.where((b) => b.isGraded).length ?? 0;
  int get correctCount => results.values.where((v) => v).length;
  bool get isDone => blocks != null && gradedCount > 0 && results.length >= gradedCount;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        objectives: _strs(j['objectives']),
        minutes: j['minutes'] is int ? j['minutes'] : 15,
        interactionHint: j['interaction_hint'] ?? '',
        blocks: j['blocks'] == null ? null : Block.parseList(j['blocks']),
        results: {
          for (final e in ((j['results'] as Map?) ?? {}).entries) int.parse('${e.key}'): e.value == true,
        },
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'objectives': objectives,
        'minutes': minutes,
        'interaction_hint': interactionHint,
        'blocks': blocks?.map((b) => b.toJson()).toList(),
        'results': {for (final e in results.entries) '${e.key}': e.value},
      };

  /// Dang gui len server (khong kem noi dung khoi).
  Map<String, dynamic> toOutlineJson() =>
      {'id': id, 'title': title, 'objectives': objectives, 'minutes': minutes, 'interaction_hint': interactionHint};
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
    this.fileId,
    this.mimeType,
    this.fileName,
    this.text,
    this.sources = const [],
  });

  final String id;
  String title;
  final String goal, language;

  /// Mon hoc do AI nhan dien khi len lo trinh (dung de chon bo may tuong tac).
  final String subject;
  final DateTime createdAt;
  final List<Lesson> lessons;
  final String? fileId, mimeType, fileName, text;
  final List<WebSource> sources;

  int get doneLessons => lessons.where((l) => l.isDone).length;

  String get sourceLabel {
    if (id == 'sample-ohm') return 'Khóa mẫu';
    if (fileName != null) return fileName!;
    if (sources.isNotEmpty) return '${sources.length} nguồn trên mạng';
    return 'Văn bản dán vào';
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
        fileId: j['fileId'],
        mimeType: j['mimeType'],
        fileName: j['fileName'],
        text: j['text'],
        sources: ((j['sources'] as List?) ?? []).map((e) => WebSource.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'goal': goal,
        'language': language,
        'subject': subject,
        'createdAt': createdAt.toIso8601String(),
        'lessons': lessons.map((l) => l.toJson()).toList(),
        'fileId': fileId,
        'mimeType': mimeType,
        'fileName': fileName,
        'text': text,
        'sources': sources.map((s) => s.toJson()).toList(),
      };

  /// Phan dau vao tai lieu gui kem moi lan goi AI.
  Map<String, dynamic> materialJson() => {
        if (fileId != null) 'fileId': fileId,
        if (mimeType != null) 'mimeType': mimeType,
        if (text != null) 'text': text,
        if (sources.isNotEmpty) 'sources': sources.map((s) => s.toJson()).toList(),
      };
}
