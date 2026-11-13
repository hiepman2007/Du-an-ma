import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/blocks/block_renderer.dart';

/// Gia su hoi dap kieu ChatGPT: moi cau tra loi la chuoi khoi (chu + LaTeX, anh that,
/// do thi/mo phong, giai tung buoc, code demo...) do AI tu chon, render bang BlockRenderer.
class TutorChatScreen extends StatefulWidget {
  const TutorChatScreen({super.key, required this.courseId, required this.lessonId, this.initialQuestion});
  final String courseId, lessonId;
  final String? initialQuestion;
  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  String? _error;

  static const _suggestions = [
    'Giải thích bằng hình ảnh',
    'Cho ví dụ có số cụ thể',
    'Mô phỏng giúp mình',
    'Kiểm tra mình 1 câu',
    'Tóm tắt ý chính',
  ];

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuestion;
    if (q != null && q.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _send(q));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  (Course?, Lesson?) _find(AppState s) {
    final c = s.courseById(widget.courseId);
    for (final l in c?.lessons ?? <Lesson>[]) {
      if (l.id == widget.lessonId) return (c, l);
    }
    return (c, null);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  Future<void> _send(String text) async {
    final q = text.trim();
    if (q.isEmpty || _sending) return;
    final s = context.read<AppState>();
    final (c, l) = _find(s);
    if (c == null || l == null) return;
    _input.clear();
    setState(() {
      _sending = true;
      _error = null;
    });
    _toBottom();
    try {
      await s.ask(c, l, q);
    } on ApiException catch (e) {
      _error = e.message;
      _input.text = q; // giu lai cau hoi de gui lai
    }
    if (mounted) setState(() => _sending = false);
    _toBottom();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final (c, l) = _find(s);
    if (c == null || l == null) return const Scaffold(body: Center(child: Text('Bài học không còn tồn tại')));
    final msgs = l.chat;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Gia sư AI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        actions: [
          if (msgs.isNotEmpty)
            IconButton(tooltip: 'Xóa hội thoại', icon: const Icon(Icons.delete_sweep_outlined), onPressed: () => s.clearChat(l)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: msgs.isEmpty && !_sending
              ? _Empty(lessonTitle: l.title, onPick: _send)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  itemCount: msgs.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == msgs.length) return const _Typing();
                    final m = msgs[i];
                    if (m.fromUser) return _UserBubble(text: m.text);
                    return _TutorAnswer(message: m, lesson: l);
                  },
                ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            color: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.primaryDark)),
          ),
        if (!_sending)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final t in _suggestions)
                  Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(t), onPressed: () => _send(t))),
              ],
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _send,
                  decoration: const InputDecoration(hintText: 'Hỏi bất cứ điều gì về bài này…', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: _sending ? null : () => _send(_input.text),
                icon: const Icon(Icons.arrow_upward),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.lessonTitle, required this.onPick});
  final String lessonTitle;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final starters = [
      'Giải thích lại "$lessonTitle" thật dễ hiểu',
      'Cho mình một bài tập mẫu có lời giải',
      'Phần nào trong bài này hay bị nhầm nhất?',
    ];
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.psychology_alt_outlined, size: 56, color: AppColors.primary),
      const SizedBox(height: 12),
      const Center(child: Eyebrow('Gia sư AI')),
      const SizedBox(height: 4),
      const Text('Hỏi gì cũng được', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Gia sư trả lời bằng chữ, công thức, hình ảnh thật, đồ thị, mô phỏng hoặc lời giải từng bước, tùy câu hỏi.',
          textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 20),
      for (final q in starters)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
              title: Text(q),
              trailing: const Icon(Icons.arrow_forward, color: AppColors.primary),
              onTap: () => onPick(q),
            ),
          ),
        ),
    ]);
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomLeft: Radius.circular(16), bottomRight: Radius.circular(4)),
          ),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ),
      );
}

class _TutorAnswer extends StatelessWidget {
  const _TutorAnswer({required this.message, required this.lesson});
  final ChatMessage message;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          CircleAvatar(radius: 12, backgroundColor: AppColors.primary, child: Icon(Icons.auto_awesome, size: 14, color: Colors.white)),
          SizedBox(width: 6),
          Eyebrow('Gia sư AI'),
        ]),
        for (final b in message.blocks)
          // Cau hoi kiem tra trong chat khong tinh vao ket qua bai hoc.
          BlockRenderer(block: b, lesson: lesson, onAnswered: (_, _, _) {}),
      ]),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Gia sư đang soạn câu trả lời…', style: TextStyle(color: AppColors.muted)),
        ]),
      );
}
