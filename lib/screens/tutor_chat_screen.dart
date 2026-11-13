import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/blocks/block_renderer.dart';
import '../widgets/motion.dart';
import '../widgets/study_citation.dart';

/// Gia su hoi dap kieu ChatGPT: moi cau tra loi la chuoi khoi (chu + LaTeX, anh that,
/// do thi/mo phong, giai tung buoc, code demo...) do AI tu chon, render bang BlockRenderer.
class TutorChatScreen extends StatefulWidget {
  const TutorChatScreen({super.key, required this.courseId, required this.lessonId, this.initialQuestion, this.draftQuestion});
  final String courseId, lessonId;
  final String? initialQuestion, draftQuestion;
  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  /// null = theo cai dat cua khoa hoc (allowWeb); nguoi hoc bat/tat ngay trong chat.
  bool? _web;
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
    _input.text = widget.draftQuestion ?? '';
    final q = widget.initialQuestion;
    if (q != null && q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(q);
      });
    }
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
      await s.ask(c, l, q, webSearch: _web ?? c.allowWeb);
    } catch (error) {
      if (mounted) {
        _error = error is ApiException ? error.message : 'Chưa gửi được câu hỏi.';
        _input.text = q;
      }
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
                    if (m.fromUser) return _UserBubble(text: m.text).enter(context, dy: 0.2);
                    return _TutorAnswer(message: m, course: c, lesson: l).enter(context);
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
                // Kieu NotebookLM: mac dinh chi dua vao nguon da nap; tich de cho phep tra cuu web.
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _web ?? c.allowWeb,
                    avatar: Icon(Icons.public, size: 18, color: (_web ?? c.allowWeb) ? AppColors.primary : AppColors.muted),
                    showCheckmark: false,
                    label: Text((_web ?? c.allowWeb) ? 'Tra cứu web: bật' : 'Chỉ nguồn của bạn'),
                    onSelected: (v) => setState(() => _web = v),
                  ),
                ),
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
  const _TutorAnswer({required this.message, required this.course, required this.lesson});
  final ChatMessage message;
  final Course course;
  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(radius: 12, backgroundColor: AppColors.primary, child: Icon(Icons.auto_awesome, size: 14, color: Colors.white)),
          const SizedBox(width: 6),
          const Eyebrow('Gia sư AI'),
          const SizedBox(width: 8),
          Flexible(child: _ScopeBadge(mode: message.webMode)),
        ]),
        for (final b in message.blocks) ...[
          // Cau hoi kiem tra trong chat khong tinh vao ket qua bai hoc.
          BlockRenderer(block: b, lesson: lesson, onAnswered: (_, _, _) {}),
          if (b.sourceId != null) StudyCitation(course: course, block: b),
        ],
        if (message.web.isNotEmpty) _WebSources(sources: message.web),
      ]),
    );
  }
}

/// Cho biet cau tra loi dua tren nguon nao (kieu NotebookLM).
class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.mode});
  final String mode;
  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (mode) {
      'search' => (Icons.public, 'Nguồn của bạn + tra cứu web'),
      'wikipedia' => (Icons.public, 'Nguồn của bạn + Wikipedia'),
      _ => (Icons.lock_outline, 'Chỉ từ nguồn của bạn'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.muted),
        const SizedBox(width: 4),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted))),
      ]),
    );
  }
}

/// Danh sach nguon web da tra cuu cho cau tra loi: [W1], [W2]... bam de mo link goc.
class _WebSources extends StatelessWidget {
  const _WebSources({required this.sources});
  final List<WebSource> sources;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(appRadius), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Nguồn tra cứu trên mạng'),
        const SizedBox(height: 6),
        for (var i = 0; i < sources.length; i++)
          InkWell(
            onTap: () => launchUrl(Uri.parse(sources[i].url), mode: LaunchMode.externalApplication),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(6)),
                  child: Text('W${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ),
                const SizedBox(width: 8),
                Icon(sources[i].trusted ? Icons.verified : Icons.help_outline, size: 14,
                    color: sources[i].trusted ? AppColors.success : const Color(0xFFB26A00)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${sources[i].title} · ${sources[i].domain}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                ),
                const Icon(Icons.open_in_new, size: 14, color: AppColors.muted),
              ]),
            ),
          ),
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
          TypingDots(),
          SizedBox(width: 12),
          Text('Gia sư đang soạn câu trả lời…', style: TextStyle(color: AppColors.muted)),
        ]),
      );
}
