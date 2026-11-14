/// Y dinh cua nguoi hoc khi go vao khung chat. Khop CHAT_INTENTS o server/lib/study.js.
enum ChatIntent {
  none('none'),
  plan('plan'),
  quiz('quiz'),
  flashcards('flashcards'),
  lab('lab'),
  summary('summary'),
  test('test'),
  research('research');

  const ChatIntent(this.id);
  final String id;

  static ChatIntent fromId(Object? id) => values.firstWhere((v) => v.id == id, orElse: () => none);
}

final _rules = <(ChatIntent, RegExp)>[
  (ChatIntent.plan, RegExp(r'lộ trình|kế hoạch học|lập plan|study plan|lịch học|lịch ôn|tạo khóa học', caseSensitive: false)),
  (ChatIntent.research, RegExp(r'tìm (thêm )?(tài liệu|nguồn|giáo trình|sách)|^\s*tài liệu\b|giáo trình|nguồn tham khảo', caseSensitive: false)),
  (ChatIntent.test, RegExp(r'thi thử|đề thi thử|bấm giờ', caseSensitive: false)),
  (ChatIntent.flashcards, RegExp(r'thẻ ghi nhớ|flashcard|flash card', caseSensitive: false)),
  (ChatIntent.quiz, RegExp(r'\bquiz\b|trắc nghiệm|câu hỏi ôn|kiểm tra (?:tôi|mình|nhanh)|luyện đề', caseSensitive: false)),
  (ChatIntent.lab, RegExp(r'mô phỏng|thí nghiệm|phòng thí nghiệm|simulation', caseSensitive: false)),
  (ChatIntent.summary, RegExp(r'tóm tắt|tổng hợp ý chính|summary', caseSensitive: false)),
];

/// Nguoi hoc muon tra cuu tren mang cho cau nay (bat tra web du cong tac dang tat).
bool wantsWeb(String text) => RegExp(
        r'tra (cứu )?(mạng|web|google|internet)|tìm (kiếm )?(trên |qua )?(mạng|web|google|internet)|search|mới nhất|tin tức|hiện nay|năm 20\d\d',
        caseSensitive: false)
    .hasMatch(text);

/// Nhan dien nhanh tren may bang tu khoa; khong chac thi tra none de server quyet dinh.
ChatIntent detectIntent(String text) {
  for (final (intent, re) in _rules) {
    if (re.hasMatch(text)) return intent;
  }
  return ChatIntent.none;
}
