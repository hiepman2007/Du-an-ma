/// Y dinh cua nguoi hoc khi go vao khung chat. Khop CHAT_INTENTS o server/lib/study.js.
enum ChatIntent {
  none('none'),
  plan('plan'),
  quiz('quiz'),
  flashcards('flashcards'),
  lab('lab'),
  summary('summary'),
  test('test');

  const ChatIntent(this.id);
  final String id;

  static ChatIntent fromId(Object? id) => values.firstWhere((v) => v.id == id, orElse: () => none);
}

final _rules = <(ChatIntent, RegExp)>[
  (ChatIntent.plan, RegExp(r'lộ trình|kế hoạch học|lập plan|study plan|lịch học|lịch ôn|tạo khóa học', caseSensitive: false)),
  (ChatIntent.test, RegExp(r'thi thử|đề thi thử|bấm giờ', caseSensitive: false)),
  (ChatIntent.flashcards, RegExp(r'thẻ ghi nhớ|flashcard|flash card', caseSensitive: false)),
  (ChatIntent.quiz, RegExp(r'\bquiz\b|trắc nghiệm|câu hỏi ôn|kiểm tra (?:tôi|mình|nhanh)|luyện đề', caseSensitive: false)),
  (ChatIntent.lab, RegExp(r'mô phỏng|thí nghiệm|phòng thí nghiệm|simulation', caseSensitive: false)),
  (ChatIntent.summary, RegExp(r'tóm tắt|tổng hợp ý chính|summary', caseSensitive: false)),
];

/// Nhan dien nhanh tren may bang tu khoa; khong chac thi tra none de server quyet dinh.
ChatIntent detectIntent(String text) {
  for (final (intent, re) in _rules) {
    if (re.hasMatch(text)) return intent;
  }
  return ChatIntent.none;
}

final _scenes = <(String, RegExp)>[
  ('refraction', RegExp(r'khúc xạ|phản xạ toàn phần|chiết suất|ống hút.*gãy|lăng kính', caseSensitive: false)),
  ('lens', RegExp(r'thấu kính|tiêu cự|kính lúp|tạo ảnh', caseSensitive: false)),
  ('circuit', RegExp(r'mạch điện|định luật ohm|điện trở|nối tiếp|song song|bóng đèn|dòng điện', caseSensitive: false)),
  ('spring', RegExp(r'lò xo|dao động điều hòa|con lắc lò xo', caseSensitive: false)),
  ('wave', RegExp(r'sóng|giao thoa|bước sóng', caseSensitive: false)),
  ('gas', RegExp(r'chất khí|áp suất|boyle|sác-lơ|charles|đẳng nhiệt|khí lí tưởng|khí lý tưởng', caseSensitive: false)),
  ('electric_field', RegExp(r'điện trường|đường sức|cu-lông|coulomb|điện tích', caseSensitive: false)),
  ('buoyancy', RegExp(r'ác-si-mét|archimedes|lực đẩy|nổi|chìm|khối lượng riêng', caseSensitive: false)),
  ('titration', RegExp(r'chuẩn độ|ph\b|axit|bazơ|trung hòa|chất chỉ thị|phenolphtalein|quỳ tím', caseSensitive: false)),
  ('states', RegExp(r'nóng chảy|bay hơi|sôi|đông đặc|chuyển thể|thể rắn|thể lỏng|thể khí', caseSensitive: false)),
];

/// Canh mo phong hop voi cau hoi (id trong simCatalog), null neu khong khop.
String? sceneFor(String text) {
  for (final (id, re) in _scenes) {
    if (re.hasMatch(text)) return id;
  }
  return null;
}
