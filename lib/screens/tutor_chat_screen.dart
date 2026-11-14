import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/chat_cards.dart';
import '../widgets/blocks/block_renderer.dart';
import '../widgets/blocks/common.dart' show BlockFlat;
import '../widgets/motion.dart';
import '../widgets/source_widgets.dart';
import '../widgets/study_citation.dart';

/// Man gia su mo rieng (tu bai hoc, lo trinh, quiz). Cung giao dien voi khung Hoi dap cua so hoc tap.
class TutorChatScreen extends StatelessWidget {
  const TutorChatScreen({super.key, required this.courseId, this.lessonId, this.initialQuestion, this.draftQuestion});
  final String courseId;
  final String? lessonId, initialQuestion, draftQuestion;

  @override
  Widget build(BuildContext context) => TutorChat(
        courseId: courseId,
        lessonId: lessonId,
        initialQuestion: initialQuestion,
        draftQuestion: draftQuestion,
        standalone: true,
      );
}

/// Gia su hoi dap kieu ChatGPT: danh sach hoi thoai o ngan keo trai, ngu canh ca khoa hoac mot bai,
/// cau tra loi la chuoi khoi (chu + LaTeX, anh, do thi/mo phong, giai tung buoc, code...) do AI chon.
class TutorChat extends StatefulWidget {
  const TutorChat({
    super.key,
    required this.courseId,
    this.lessonId,
    this.initialQuestion,
    this.draftQuestion,
    this.standalone = false,
    this.onIntercept,
    this.emptyActions = const [],
    this.onSaveNote,
    this.onClose,
    this.controller,
    this.tools = const [],
  });

  final String courseId;

  /// So hoc dieu khien tu thanh tieu de cua no (mo lich su, cuoc tro chuyen moi); co thi chat khong ve thanh tieu de rieng.
  final TutorChatController? controller;

  /// Hang chip cong cu (Lo trinh, Quiz...) hien ngay tren o nhap, kieu StudyFetch.
  final List<Widget> tools;

  /// Khung tro ly noi (bottom sheet): hien nut dong.
  final VoidCallback? onClose;

  /// Ngu canh ban dau: null = ca khoa hoc.
  final String? lessonId;
  final String? initialQuestion, draftQuestion;

  /// true = man rieng (co nut quay lai), false = nhung trong so hoc tap.
  final bool standalone;

  /// So hoc tap chan mot so cau (vd "lap lo trinh") de tu xu ly. Tra ve true neu da xu ly.
  final Future<bool> Function(String question)? onIntercept;
  final List<Widget> emptyActions;
  final Future<void> Function(ChatMessage message)? onSaveNote;

  @override
  State<TutorChat> createState() => _TutorChatState();
}

/// Cau noi giua thanh tieu de cua so hoc va khung chat ben trong.
class TutorChatController {
  VoidCallback? _history, _newChat;
  void openHistory() => _history?.call();
  void newChat() => _newChat?.call();
}

class _TutorChatState extends State<TutorChat> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _scaffold = GlobalKey<ScaffoldState>();
  late ChatThread _thread;

  /// null = theo cai dat cua khoa hoc (allowWeb).
  bool? _web;
  bool _socratic = false;
  bool _attaching = false;
  String? _error;

  /// Cau tra loi vua ve: hien dan (chu chay) mot lan.
  ChatMessage? _fresh;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    final course = s.courseById(widget.courseId);
    final fresh = widget.initialQuestion != null || widget.draftQuestion != null;
    _thread = course == null
        ? ChatThread(id: 'none')
        : fresh
            ? s.newThread(course, lessonId: widget.lessonId)
            : s.latestThread(course, lessonId: widget.lessonId);
    _input.text = widget.draftQuestion ?? '';
    widget.controller?._history = () => _scaffold.currentState?.openDrawer();
    widget.controller?._newChat = () {
      final c = context.read<AppState>().courseById(widget.courseId);
      if (c != null && _thread.messages.isNotEmpty) _newChat(c, lessonId: _thread.lessonId);
    };
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
    _focus.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  String _message(Object error) => error is ApiException ? error.message : 'Chưa gửi được câu hỏi. Hãy kiểm tra kết nối rồi thử lại.';

  Future<void> _send(String text) async {
    final q = text.trim();
    final s = context.read<AppState>();
    final course = s.courseById(widget.courseId);
    if (q.isEmpty || course == null || s.isThreadBusy(_thread)) return;
    if (widget.onIntercept != null && await widget.onIntercept!(q)) return;
    if (!mounted) return;
    _input.clear();
    setState(() => _error = null);
    _toBottom();
    final before = _thread.messages.length;
    try {
      await s.sendChat(course, _thread, q, web: _web ?? course.allowWeb, socratic: _socratic);
      if (mounted && _thread.messages.length > before && !_thread.messages.last.fromUser) _fresh = _thread.messages.last;
    } catch (error) {
      if (mounted) {
        _error = _message(error);
        if (_input.text.isEmpty) _input.text = q;
      }
    }
    if (mounted) setState(() {});
    _toBottom();
  }

  Future<void> _regenerate(Course course) async {
    final s = context.read<AppState>();
    setState(() => _error = null);
    try {
      await s.regenerateChat(course, _thread, web: _web ?? course.allowWeb, socratic: _socratic);
      if (mounted && _thread.messages.isNotEmpty && !_thread.messages.last.fromUser) _fresh = _thread.messages.last;
    } catch (error) {
      if (mounted) _error = _message(error);
    }
    if (mounted) setState(() {});
    _toBottom();
  }

  Future<void> _edit(int index) async {
    final text = await context.read<AppState>().editChatFrom(_thread, index);
    if (!mounted || text.isEmpty) return;
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
    setState(() => _error = null);
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã sao chép'), duration: Duration(seconds: 1)));
  }

  void _openThread(ChatThread thread) {
    Navigator.maybePop(context);
    setState(() {
      _thread = thread;
      _error = null;
      _fresh = null;
    });
    _toBottom();
  }

  void _newChat(Course course, {String? lessonId}) {
    final s = context.read<AppState>();
    setState(() {
      _thread = s.newThread(course, lessonId: lessonId);
      _error = null;
      _fresh = null;
    });
  }

  Future<void> _pickContext(Course course) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: SectionHeader(eyebrow: 'Ngữ cảnh', title: 'Gia sư dựa vào đâu?')),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Cả khóa học'),
              subtitle: Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              selected: _thread.lessonId == null,
              onTap: () => Navigator.pop(c, ''),
            ),
            for (final l in course.lessons)
              ListTile(
                leading: Icon(l.isDone ? Icons.check_circle : Icons.article_outlined),
                title: Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                selected: _thread.lessonId == l.id,
                onTap: () => Navigator.pop(c, l.id),
              ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final lessonId = picked.isEmpty ? null : picked;
    if (lessonId == _thread.lessonId) return;
    if (_thread.messages.isEmpty) {
      setState(() => _thread.lessonId = lessonId);
    } else {
      _newChat(course, lessonId: lessonId);
    }
  }

  Future<void> _attach(Course course, Future<List<SourceDraft>> Function() pick) async {
    final s = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    List<SourceDraft> drafts;
    try {
      drafts = await pick();
    } catch (_) {
      return;
    }
    if (drafts.isEmpty || !mounted) return;
    setState(() => _attaching = true);
    try {
      await s.addSources(course, drafts);
      messenger.showSnackBar(SnackBar(content: Text('Đã thêm ${drafts.length == 1 ? drafts.first.title : '${drafts.length} tệp'} vào nguồn.')));
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException ? error.message : 'Chưa tải được tệp lên.');
    }
    if (mounted) setState(() => _attaching = false);
  }

  Future<void> _plusMenu(Course course) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('Tải PDF / slide'), onTap: () => Navigator.pop(c, 'pdf')),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Chụp ảnh đề bài'), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Ảnh có sẵn'), onTap: () => Navigator.pop(c, 'gallery')),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Chọn nguồn cho câu hỏi'),
            subtitle: Text('${course.enabledSources.length}/${course.activeSources.length} nguồn đang dùng'),
            enabled: course.activeSources.isNotEmpty,
            onTap: () => Navigator.pop(c, 'sources'),
          ),
          StatefulBuilder(builder: (c2, set) => SwitchListTile(
                secondary: const Icon(Icons.lightbulb_outline),
                title: const Text('Chế độ Gợi mở'),
                subtitle: const Text('Gợi ý từng bước để bạn tự tìm ra đáp án'),
                value: _socratic,
                onChanged: (v) {
                  set(() {});
                  setState(() => _socratic = v);
                },
              )),
          StatefulBuilder(builder: (c2, set) => SwitchListTile(
                secondary: const Icon(Icons.public),
                title: const Text('Tra cứu web'),
                subtitle: const Text('Tắt: chỉ trả lời từ nguồn của bạn'),
                value: _web ?? course.allowWeb,
                onChanged: (v) {
                  set(() {});
                  setState(() => _web = v);
                },
              )),
        ])),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'pdf':
        await _attach(course, SourceAddBar.pickPdfs);
      case 'camera':
        await _attach(course, () => SourceAddBar.pickImage(ImageSource.camera));
      case 'gallery':
        await _attach(course, () => SourceAddBar.pickImage(ImageSource.gallery));
      case 'sources':
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (c) => SafeArea(child: Consumer<AppState>(builder: (c, s, _) => ListView(shrinkWrap: true, children: [
                const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: SectionHeader(eyebrow: 'Nguồn', title: 'Gia sư dùng nguồn nào?')),
                for (final src in course.activeSources)
                  CheckboxListTile(
                    value: src.enabled,
                    title: Text(src.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onChanged: (v) => s.setSourceEnabled(course, src, v ?? false),
                  ),
              ]))),
        );
    }
  }

  /// Cau goi y khi chat trong, doi theo ngu canh: bai dang hoc, cau vua sai, chu de yeu.
  List<String> _suggestions(Course course, Lesson? lesson) {
    if (lesson != null) {
      final blocks = lesson.blocks ?? const <Block>[];
      final wrong = lesson.results.entries.where((e) => !e.value && e.key < blocks.length).map((e) => blocks[e.key]).lastOrNull;
      final step = blocks.isEmpty ? null : blocks[lesson.stepIndex.clamp(0, blocks.length - 1)].title;
      return [
        if (wrong != null) 'Vì sao mình sai câu: "${_clip(wrong.body ?? wrong.title ?? '', 70)}"?',
        if (step != null && step.isNotEmpty) 'Giải thích lại phần "${_clip(step, 50)}" dễ hiểu hơn',
        'Giải thích "${_clip(lesson.title, 50)}" bằng ví dụ có số cụ thể',
        'Cho mình một bài tập mẫu có lời giải',
        'Kiểm tra mình 1 câu về bài này',
      ].take(4).toList();
    }
    final weak = course.weakTopics.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final next = course.lessons.where((l) => !l.isDone).firstOrNull;
    return [
      if (weak.isNotEmpty) 'Mình hay sai phần "${_clip(weak.first.key, 50)}", giảng lại giúp mình',
      if (next != null) 'Tóm tắt ý chính của bài "${_clip(next.title, 50)}"',
      if (course.enabledSources.isNotEmpty) 'Những ý chính trong các nguồn này là gì?',
      if (course.enabledSources.isNotEmpty) 'Phần nào trong tài liệu hay bị nhầm nhất?',
      'Lập cho mình kế hoạch ôn trong 3 ngày',
    ].take(4).toList();
  }

  static String _clip(String s, int max) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length <= max ? t : '${t.substring(0, max - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final course = s.courseById(widget.courseId);
    if (course == null) return const Scaffold(body: Center(child: Text('Khóa học không còn tồn tại')));
    if (!course.threads.contains(_thread)) _thread = s.newThread(course, lessonId: _thread.lessonId);
    final lesson = course.lessonById(_thread.lessonId);
    final busy = s.isThreadBusy(_thread);
    final msgs = _thread.messages;
    final contextLesson = lesson ?? Lesson(id: course.id, title: course.title);
    final lastAnswer = msgs.lastIndexWhere((m) => !m.fromUser);
    final lastQuestion = msgs.lastIndexWhere((m) => m.fromUser);
    final web = _web ?? course.allowWeb;

    final embedded = widget.controller != null;
    return Scaffold(
      key: _scaffold,
      backgroundColor: Colors.white,
      drawer: _ThreadDrawer(
        course: course,
        current: _thread,
        onOpen: _openThread,
        onNew: () {
          Navigator.maybePop(context);
          _newChat(course, lessonId: _thread.lessonId);
        },
        onDelete: (t) => s.deleteThread(course, t),
      ),
      appBar: embedded ? null : AppBar(
        primary: widget.standalone,
        toolbarHeight: widget.standalone ? null : 52,
        automaticallyImplyLeading: false,
        leading: widget.standalone ? const BackButton() : Builder(builder: (c) => IconButton(
              tooltip: 'Các cuộc trò chuyện', icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(c).openDrawer())),
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _pickContext(course),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Gia sư AI', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Row(children: [
                Icon(lesson == null ? Icons.menu_book_outlined : Icons.article_outlined, size: 13, color: AppColors.muted),
                const SizedBox(width: 4),
                Flexible(child: Text(lesson?.title ?? 'Cả khóa: ${course.title}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
                const Icon(Icons.expand_more, size: 16, color: AppColors.muted),
              ]),
            ]),
          ),
        ),
        actions: [
          if (widget.standalone)
            Builder(builder: (c) => IconButton(
                tooltip: 'Các cuộc trò chuyện', icon: const Icon(Icons.history), onPressed: () => Scaffold.of(c).openDrawer())),
          IconButton(
            tooltip: 'Cuộc trò chuyện mới',
            icon: const Icon(Icons.edit_square),
            onPressed: msgs.isEmpty ? null : () => _newChat(course, lessonId: _thread.lessonId),
          ),
          if (widget.onClose != null) IconButton(tooltip: 'Đóng trợ lý', icon: const Icon(Icons.close), onPressed: widget.onClose),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: msgs.isEmpty && !busy
              ? _Empty(
                  title: lesson == null ? 'Hôm nay mình giúp gì cho bạn?' : 'Hỏi về bài "${lesson.title}"',
                  subtitle: course.enabledSources.isEmpty && !web
                      ? 'Chưa có nguồn nào đang bật. Bấm + để thêm tài liệu hoặc bật tra cứu web.'
                      : web ? 'Gia sư dùng nguồn của bạn và tra cứu thêm trên mạng.' : 'Gia sư chỉ trả lời từ những nguồn bạn đang chọn.',
                  suggestions: _suggestions(course, lesson),
                  actions: widget.emptyActions,
                  onPick: _send,
                )
              : SelectionArea(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                    itemCount: msgs.length + (busy ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == msgs.length) return const _Typing();
                      final m = msgs[i];
                      if (m.fromUser) {
                        return _UserBubble(
                          text: m.text,
                          onCopy: () => _copy(m.text),
                          onEdit: busy ? null : () => _edit(i),
                          showActions: i == lastQuestion && !busy,
                        );
                      }
                      return _TutorAnswer(
                        key: ObjectKey(m),
                        message: m,
                        question: i > 0 && msgs[i - 1].fromUser ? msgs[i - 1].text : '',
                        onAsk: busy ? null : _send,
                        course: course,
                        lesson: contextLesson,
                        animate: identical(m, _fresh) && !reduceMotion(context),
                        onCopy: () => _copy(m.plainText),
                        onRegenerate: i == lastAnswer && !busy ? () => _regenerate(course) : null,
                        onSaveNote: widget.onSaveNote == null ? null : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await widget.onSaveNote!(m);
                          messenger.showSnackBar(const SnackBar(content: Text('Đã lưu trong Studio.')));
                        },
                      );
                    },
                  ),
                ),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            color: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.error_outline, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.primaryDark))),
            ]),
          ),
        if (_attaching) const LinearProgressIndicator(minHeight: 2),
        if (widget.tools.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.tools.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Center(child: widget.tools[i]),
            ),
          ),
        _Composer(
          controller: _input,
          focus: _focus,
          busy: busy,
          socratic: _socratic,
          web: web,
          contextLabel: embedded && course.lessons.isNotEmpty ? (lesson?.title ?? 'Cả khóa') : null,
          onContext: () => _pickContext(course),
          hint: lesson == null ? 'Hỏi gia sư bất cứ điều gì…' : 'Hỏi về bài này…',
          onPlus: () => _plusMenu(course),
          onSend: () => _send(_input.text),
          onStop: () => s.stopChat(_thread),
          onSocratic: (v) => setState(() => _socratic = v),
          onWebOff: () => setState(() => _web = false),
        ),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focus,
    required this.busy,
    required this.socratic,
    required this.web,
    required this.hint,
    required this.onPlus,
    required this.onSend,
    required this.onStop,
    required this.onSocratic,
    required this.onWebOff,
    this.contextLabel,
    this.onContext,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy, socratic, web;
  final String hint;
  final String? contextLabel;
  final VoidCallback? onContext;
  final VoidCallback onPlus, onSend, onStop, onWebOff;
  final ValueChanged<bool> onSocratic;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              focusNode: focus,
              minLines: 1,
              maxLines: 5,
              maxLength: 1000,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: hint,
                counterText: '',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            Row(children: [
              IconButton(tooltip: 'Thêm', onPressed: onPlus, icon: const Icon(Icons.add)),
              if (contextLabel != null)
                Flexible(
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white,
                    avatar: const Icon(Icons.menu_book_outlined, size: 16),
                    label: Text(contextLabel!, overflow: TextOverflow.ellipsis),
                    tooltip: 'Gia sư dựa vào cả khóa hay một bài',
                    onPressed: onContext,
                  ),
                ),
              if (socratic) ...[
                const SizedBox(width: 6),
                InputChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white,
                  avatar: const Icon(Icons.lightbulb, size: 16, color: AppColors.primary),
                  label: const Text('Gợi mở'),
                  onDeleted: () => onSocratic(false),
                  deleteButtonTooltipMessage: 'Tắt Gợi mở',
                ),
              ],
              if (web) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: InputChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.public, size: 16, color: AppColors.primary),
                    label: const Text('Web', overflow: TextOverflow.ellipsis),
                    onDeleted: onWebOff,
                    deleteButtonTooltipMessage: 'Tắt tra cứu web',
                  ),
                ),
              ],
              const Spacer(),
              ValueListenableBuilder(
                valueListenable: controller,
                builder: (_, value, _) => busy
                    ? IconButton.filled(
                        tooltip: 'Dừng',
                        onPressed: onStop,
                        icon: const Icon(Icons.stop_rounded),
                        style: IconButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white, minimumSize: const Size(44, 44)),
                      )
                    : IconButton.filled(
                        tooltip: 'Gửi',
                        onPressed: value.text.trim().isEmpty ? null : onSend,
                        icon: const Icon(Icons.arrow_upward),
                        style: IconButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size(44, 44)),
                      ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ThreadDrawer extends StatefulWidget {
  const _ThreadDrawer({required this.course, required this.current, required this.onOpen, required this.onNew, required this.onDelete});
  final Course course;
  final ChatThread current;
  final ValueChanged<ChatThread> onOpen, onDelete;
  final VoidCallback onNew;

  @override
  State<_ThreadDrawer> createState() => _ThreadDrawerState();
}

class _ThreadDrawerState extends State<_ThreadDrawer> {
  String _query = '';

  static String _when(DateTime t) {
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (days <= 0) return 'Hôm nay';
    if (days == 1) return 'Hôm qua';
    if (days < 7) return '$days ngày trước';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final threads = widget.course.threads.where((t) => t.messages.isNotEmpty).where((t) => q.isEmpty ||
        t.title.toLowerCase().contains(q) || t.messages.any((m) => m.plainText.toLowerCase().contains(q))).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Drawer(
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: const InputDecoration(
                hintText: 'Tìm cuộc trò chuyện',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          ListTile(leading: const Icon(Icons.edit_square), title: const Text('Cuộc trò chuyện mới'), onTap: widget.onNew),
          const Divider(height: 1),
          Expanded(
            child: threads.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(q.isEmpty ? 'Chưa có cuộc trò chuyện nào.' : 'Không tìm thấy cuộc trò chuyện phù hợp.',
                        textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                  )
                : ListView(children: [
                    for (final t in threads)
                      ListTile(
                        selected: identical(t, widget.current),
                        title: Text(t.title.isEmpty ? 'Cuộc trò chuyện' : t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${widget.course.lessonById(t.lessonId)?.title ?? 'Cả khóa'} · ${_when(t.updatedAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => widget.onOpen(t),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Tùy chọn',
                          onSelected: (_) => widget.onDelete(t),
                          itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Xóa cuộc trò chuyện'))],
                        ),
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.subtitle, required this.suggestions, required this.actions, required this.onPick});
  final String title, subtitle;
  final List<String> suggestions;
  final List<Widget> actions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 28, 20, 20), children: [
      const Center(child: CircleAvatar(radius: 26, backgroundColor: AppColors.accent, child: Icon(Icons.auto_awesome, color: AppColors.primary))),
      const SizedBox(height: 14),
      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 20),
      for (final (i, q) in suggestions.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              title: Text(q, style: const TextStyle(fontSize: 14.5)),
              trailing: const Icon(Icons.north_east, size: 18, color: AppColors.primary),
              onTap: () => onPick(q),
            ),
          ),
        ).enter(context, index: i),
      if (actions.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: actions),
      ],
    ]);
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, required this.onCopy, required this.onEdit, required this.showActions});
  final String text;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final bool showActions;

  Future<void> _menu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.copy), title: const Text('Sao chép'), onTap: () => Navigator.pop(c, 'copy')),
          if (onEdit != null)
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Sửa và gửi lại'), onTap: () => Navigator.pop(c, 'edit')),
        ]),
      ),
    );
    if (action == 'copy') onCopy();
    if (action == 'edit') onEdit?.call();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        GestureDetector(
          onLongPress: () => _menu(context),
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            margin: const EdgeInsets.only(top: 12, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(22)),
            child: Text(text, style: const TextStyle(fontSize: 15, color: AppColors.ink)),
          ),
        ),
        if (showActions)
          Row(mainAxisSize: MainAxisSize.min, children: [
            _MiniAction(icon: Icons.copy, tooltip: 'Sao chép', onTap: onCopy),
            if (onEdit != null) _MiniAction(icon: Icons.edit_outlined, tooltip: 'Sửa câu hỏi', onTap: onEdit!),
          ]),
      ]).enter(context, dy: 0.2);
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        visualDensity: VisualDensity.compact,
        iconSize: 18,
        color: AppColors.muted,
        icon: Icon(icon),
      );
}

class _TutorAnswer extends StatefulWidget {
  const _TutorAnswer({
    super.key,
    required this.message,
    this.question = '',
    this.onAsk,
    required this.course,
    required this.lesson,
    required this.animate,
    required this.onCopy,
    this.onRegenerate,
    this.onSaveNote,
  });
  final ChatMessage message;
  final String question;
  final ValueChanged<String>? onAsk;
  final Course course;
  final Lesson lesson;
  final bool animate;
  final VoidCallback onCopy;
  final VoidCallback? onRegenerate, onSaveNote;

  @override
  State<_TutorAnswer> createState() => _TutorAnswerState();
}

/// Hien dan cau tra loi: khoi chu dau tien "go" tung tu, cac khoi sau hien ra khi go xong.
class _TutorAnswerState extends State<_TutorAnswer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final String _body;
  late final List<int> _cuts;

  @override
  void initState() {
    super.initState();
    final first = widget.message.blocks.firstOrNull;
    _body = first?.type == BlockType.textSection ? (first?.body ?? '') : '';
    _cuts = _safeCuts(_body);
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_cuts.length * 35).clamp(300, 2600)),
    );
    if (widget.animate && _cuts.length > 1) {
      _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Vi tri cat sau moi tu, khong cat giua cong thuc $...$.
  static List<int> _safeCuts(String s) {
    final cuts = <int>[];
    var dollars = 0;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch == r'$' && (i == 0 || s[i - 1] != r'\')) dollars++;
      if ((ch == ' ' || ch == '\n') && dollars.isEven) cuts.add(i);
    }
    cuts.add(s.length);
    return cuts;
  }

  Block _partial(Block b, double t) {
    final n = _cuts[((_cuts.length - 1) * t).floor().clamp(0, _cuts.length - 1)];
    return Block.tryParse({...b.toJson(), 'body': _body.substring(0, n)}) ?? b;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final done = _c.isCompleted;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: done ? null : () => _c.value = 1,
            child: BlockFlat(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (m.webMode != 'off') Padding(padding: const EdgeInsets.only(bottom: 4), child: _ScopeBadge(mode: m.webMode)),
              for (final (i, b) in m.blocks.indexed)
                if (i == 0 || done) ...[
                  // Cau hoi kiem tra trong chat khong tinh vao ket qua bai hoc.
                  BlockRenderer(
                      block: i == 0 && !done && _body.isNotEmpty ? _partial(b, _c.value) : b,
                      lesson: widget.lesson,
                      onAnswered: (_, _, _) {},
                      autoSim: true,
                      question: widget.question),
                  if (b.sourceId != null && done) StudyCitation(course: widget.course, block: b),
                ],
              if (done && m.web.isNotEmpty) _WebSources(sources: m.web),
              if (done) IntentCard(course: widget.course, message: m, question: widget.question, onAsk: widget.onAsk),
              // Nut nho chi o cau tra loi moi nhat, nhu ChatGPT.
              if (done && widget.onRegenerate != null)
                Row(children: [
                  _MiniAction(icon: Icons.copy, tooltip: 'Sao chép', onTap: widget.onCopy),
                  _MiniAction(icon: Icons.refresh, tooltip: 'Tạo lại câu trả lời', onTap: widget.onRegenerate!),
                  if (widget.onSaveNote != null) _MiniAction(icon: Icons.bookmark_add_outlined, tooltip: 'Lưu ghi chú', onTap: widget.onSaveNote!),
                ]),
            ])),
          ).enter(context, dy: 0.04);
        },
      ),
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

/// Dang soan: cham nhay + khung xuong (skeleton) cho cau tra loi.
class _Typing extends StatelessWidget {
  const _Typing();
  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(
          height: 12,
          width: w,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(color: const Color(0xFFEDEDED), borderRadius: BorderRadius.circular(6)),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          TypingDots(),
          SizedBox(width: 12),
          Flexible(child: Text('Gia sư đang soạn câu trả lời…', style: TextStyle(color: AppColors.muted))),
        ]),
        LayoutBuilder(builder: (_, c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              bar(c.maxWidth * 0.92),
              bar(c.maxWidth * 0.8),
              bar(c.maxWidth * 0.55),
            ])),
      ]),
    );
  }
}
