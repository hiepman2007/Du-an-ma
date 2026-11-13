import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/study_samples.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/source_widgets.dart';
import 'review_screen.dart';
import 'study_account_screen.dart';
import 'study_actions.dart';
import 'study_pages.dart';
import 'tutor_chat_screen.dart';

/// Cac trang cua mot so hoc tap (thanh ben kieu StudyFetch).
enum StudyPage {
  dashboard('Tổng quan', Icons.space_dashboard_outlined),
  plan('Lộ trình', Icons.map_outlined),
  chat('Hỏi đáp', Icons.chat_bubble_outline),
  research('Nghiên cứu', Icons.travel_explore),
  quiz('Quiz', Icons.checklist_rtl),
  test('Thi thử', Icons.timer_outlined),
  flashcards('Thẻ ghi nhớ', Icons.style_outlined),
  arcade('Trò chơi', Icons.sports_esports_outlined),
  explainers('Tóm tắt & giải thích', Icons.lightbulb_outline),
  miniApps('Mini app', Icons.widgets_outlined),
  materials('Tài liệu', Icons.folder_outlined);

  const StudyPage(this.label, this.icon);
  final String label;
  final IconData icon;

  static const main = [dashboard, plan, chat, research];
  static const practice = [quiz, test, flashcards, arcade, explainers, miniApps];
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  StudyPage _page = StudyPage.dashboard;
  String? _courseId;

  void _go(StudyPage page) => setState(() => _page = page);

  /// Khi doi so: so moi mo tu chu de -> hoi muc tieu va lap lo trinh; so tao tu tai lieu -> trang Tai lieu.
  void _onCourse(AppState state, Course course) {
    if (_courseId == course.id) return;
    _courseId = course.id;
    _page = StudyPage.dashboard;
    if (state.openSourcesFirst) {
      state.openSourcesFirst = false;
      _page = StudyPage.materials;
    }
    final prompt = state.openingPrompt;
    if (prompt != null) {
      state.openingPrompt = null;
      _page = StudyPage.plan;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) StudyActions.plan(context, course, topic: StudyActions.topicFrom(prompt));
      });
    }
  }

  Future<bool> _intercept(Course course, String question) async {
    if (!StudyActions.wantsPlan(course, question)) return false;
    _go(StudyPage.plan);
    await StudyActions.plan(context, course, topic: StudyActions.topicFrom(question));
    return true;
  }

  void _assistant(Course course) {
    final state = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: TutorChat(
            courseId: course.id,
            onClose: () => Navigator.pop(sheet),
            onSaveNote: (m) => state.saveChatNote(course, m),
            onIntercept: (q) async {
              if (!StudyActions.wantsPlan(course, q)) return false;
              Navigator.pop(sheet);
              return _intercept(course, q);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _upload(Course course) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final drafts = await showModalBottomSheet<List<SourceDraft>>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionHeader(eyebrow: 'Tải lên', title: 'Thêm tài liệu vào sổ'),
            SourceAddBar(onAdd: (d) => Navigator.pop(sheet, d)),
          ]),
        ),
      ),
    );
    if (drafts == null || drafts.isEmpty || !mounted) return;
    _go(StudyPage.materials);
    try {
      await state.addSources(course, drafts);
      messenger.showSnackBar(SnackBar(content: Text('Đã thêm ${drafts.length} tài liệu.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Chưa tải lên được. Hãy kiểm tra kết nối rồi thử lại.')));
    }
  }

  void _library(AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(sheet).size.height * 0.8),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
            const ListTile(title: Text('Sổ học tập', style: TextStyle(fontWeight: FontWeight.w800))),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Tạo sổ mới'),
              onTap: () {
                Navigator.pop(sheet);
                state.createNotebook();
              },
            ),
            for (final course in state.courses)
              ListTile(
                leading: Icon(course.isSample ? Icons.auto_stories_outlined : Icons.book_outlined),
                selected: state.selectedCourseId == course.id,
                title: Text(course.title),
                onTap: () {
                  Navigator.pop(sheet);
                  state.selectCourse(course);
                },
              ),
            const Divider(),
            for (final entry in studySamples.entries)
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: Text(entry.value),
                subtitle: const Text('Sổ mẫu'),
                onTap: () {
                  Navigator.pop(sheet);
                  state.openStudySample(entry.key);
                },
              ),
          ]),
        ),
      ),
    );
  }

  Widget _content(AppState state, Course course) => switch (_page) {
        StudyPage.dashboard => DashboardPage(course: course, onNavigate: _go),
        StudyPage.plan => StudyPlanPage(course: course, onNavigate: _go),
        StudyPage.chat => TutorChat(
            key: ValueKey('chat-${course.id}'),
            courseId: course.id,
            onIntercept: (q) => _intercept(course, q),
            onSaveNote: (m) => state.saveChatNote(course, m),
            emptyActions: [
              if (course.lessons.isEmpty)
                ActionChip(
                    avatar: const Icon(Icons.route_outlined, size: 18),
                    label: const Text('Lập lộ trình'),
                    onPressed: () => _intercept(course, 'lập lộ trình')),
              if (course.enabledSources.isNotEmpty) ...[
                ActionChip(label: const Text('Tóm tắt'), onPressed: () => StudyActions.create(context, course, StudyArtifactKind.summary)),
                ActionChip(label: const Text('Tạo quiz'), onPressed: () => StudyActions.quizBuilder(context, course)),
              ],
            ],
          ),
        StudyPage.research => ResearchPage(course: course, onNavigate: _go),
        StudyPage.materials => MaterialsPage(course: course),
        _ => PracticePage(key: ValueKey(_page), course: course, page: _page, onNavigate: _go),
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = state.selectedCourse;
    if (course != null) _onCourse(state, course);
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      final sidebar = _Sidebar(
        course: course,
        page: _page,
        wide: wide,
        onPage: (p) {
          if (!wide) Navigator.maybePop(context);
          _go(p);
        },
        onLibrary: () => _library(state),
        onUpload: course == null ? null : () {
          if (!wide) Navigator.maybePop(context);
          _upload(course);
        },
        onReview: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewScreen())),
        onAccount: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyAccountScreen())),
      );
      final body = Column(children: [
        if (state.syncError != null) _SyncBanner(state: state),
        if (state.canImportGuest)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final count = await state.importGuestCourses();
                messenger.showSnackBar(SnackBar(content: Text('Đã nhập $count sổ từ máy này.')));
              },
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Nhập sổ đã lưu trên máy'),
            ),
          ),
        if (wide && course != null) _Breadcrumb(course: course, page: _page),
        Expanded(child: course == null ? const _Welcome() : _content(state, course)),
      ]);
      return Scaffold(
        drawer: wide ? null : Drawer(width: 300, child: sidebar),
        appBar: wide
            ? null
            : AppBar(
                titleSpacing: 0,
                title: course == null
                    ? const Text('Học Thông Minh')
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_page.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                actions: [
                  IconButton(
                    tooltip: 'Tài khoản',
                    icon: Icon(state.signedIn ? Icons.account_circle : Icons.person_outline),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyAccountScreen())),
                  ),
                ],
              ),
        body: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: 272, child: Material(color: Colors.white, child: sidebar)),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ])
            : body,
        floatingActionButton: course == null || _page == StudyPage.chat
            ? null
            : FloatingActionButton(
                tooltip: 'Trợ lý AI',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                onPressed: () => _assistant(course),
                child: const Icon(Icons.auto_awesome),
              ),
      );
    });
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.course,
    required this.page,
    required this.wide,
    required this.onPage,
    required this.onLibrary,
    required this.onUpload,
    required this.onReview,
    required this.onAccount,
  });
  final Course? course;
  final StudyPage page;
  final bool wide;
  final ValueChanged<StudyPage> onPage;
  final VoidCallback onLibrary, onReview, onAccount;
  final VoidCallback? onUpload;

  Widget _item(StudyPage p, {bool indent = false}) {
    final selected = p == page;
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 20 : 8, 1, 8, 1),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        selected: selected,
        selectedTileColor: AppColors.accent,
        selectedColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(p.icon, size: 20),
        title: Text(p.label, style: TextStyle(fontSize: 14.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        onTap: () => onPage(p),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = course;
    final sources = c?.activeSources ?? const <CourseSource>[];
    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onLibrary,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.auto_stories, color: Colors.white, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('SỔ HỌC TẬP', style: TextStyle(fontSize: 10.5, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.muted)),
                    Text(c?.title ?? 'Chọn hoặc tạo sổ', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
                ),
                const Icon(Icons.unfold_more, size: 20, color: AppColors.muted),
              ]),
            ),
          ),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.only(bottom: 8), children: [
            if (c != null) ...[
              for (final p in StudyPage.main) _item(p),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.fitness_center_outlined, size: 20),
                  title: const Text('Luyện tập & Hoạt động', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  children: [for (final p in StudyPage.practice) _item(p, indent: true)],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: FilledButton.icon(onPressed: onUpload, icon: const Icon(Icons.add), label: const Text('Tải lên')),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 12, 2),
                child: Row(children: [
                  const Expanded(child: Text('Tài liệu', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted))),
                  TextButton(onPressed: () => onPage(StudyPage.materials), child: const Text('Xem tất cả')),
                ]),
              ),
              if (sources.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 16, 8),
                  child: Text('Chưa có tài liệu nào.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ),
              for (final s in sources.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Icon(sourceIcon(s.kind, s.mimeType), size: 18, color: s.enabled ? AppColors.primary : AppColors.muted),
                    title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13.5, color: s.enabled ? null : AppColors.muted)),
                    onTap: () => onPage(StudyPage.materials),
                  ),
                ),
            ] else
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chọn một sổ học tập hoặc tạo sổ mới để bắt đầu.', style: TextStyle(color: AppColors.muted)),
              ),
          ]),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: TextButton.icon(onPressed: onReview, icon: const Icon(Icons.track_changes_outlined, size: 18), label: const Text('Ôn tập'))),
            if (wide)
              Expanded(child: TextButton.icon(onPressed: onAccount, icon: const Icon(Icons.person_outline, size: 18), label: const Text('Tài khoản'))),
          ]),
        ),
      ]),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.course, required this.page});
  final Course course;
  final StudyPage page;

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Row(children: [
          Flexible(child: Text(course.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.chevron_right, size: 18, color: AppColors.muted)),
          Icon(page.icon, size: 18),
          const SizedBox(width: 6),
          Text(page.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => MaterialBanner(content: Text(state.syncError!), actions: [
        TextButton(onPressed: state.retrySync, child: const Text('Thử lưu lại')),
        if (state.signedIn)
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                  title: const Text('Tải bản đồng bộ?'),
                  content: const Text('Thay đổi chưa đồng bộ trên máy này sẽ bị thay bằng bản trên tài khoản.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Hủy')),
                    FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Tải bản đồng bộ')),
                  ],
                ),
              );
              if (confirmed != true || !context.mounted) return;
              try {
                await state.useCloudCopy();
              } catch (_) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa thể tải bản đồng bộ.')));
              }
            },
            child: const Text('Tải bản đồng bộ'),
          ),
      ]);
}

class _Welcome extends StatefulWidget {
  const _Welcome();

  @override
  State<_Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<_Welcome> {
  final _input = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _start([String? value]) async {
    if (_creating) return;
    final state = context.read<AppState>();
    setState(() => _creating = true);
    final topic = (value ?? _input.text).trim();
    if (topic.isNotEmpty) FocusScope.of(context).unfocus();
    await state.createNotebook(prompt: topic.isEmpty ? null : topic, sourcesFirst: topic.isEmpty);
    if (mounted) setState(() => _creating = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 730),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
          Icon(Icons.auto_stories_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text('Hôm nay bạn muốn học gì?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          TextField(
            controller: _input,
            textInputAction: TextInputAction.go,
            onSubmitted: _start,
            decoration: InputDecoration(
              labelText: 'Chủ đề hoặc mục tiêu',
              hintText: 'Ví dụ: Tìm nguồn và lên lộ trình học xác suất',
              suffixIcon: IconButton(tooltip: 'Bắt đầu', onPressed: _creating ? null : () => _start(), icon: const Icon(Icons.arrow_forward)),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: _creating ? null : () => _start(), child: const Text('Bắt đầu')),
            OutlinedButton.icon(onPressed: _creating ? null : () => _start(''), icon: const Icon(Icons.add), label: const Text('Tạo sổ từ tài liệu')),
          ]),
          const SizedBox(height: 26),
          Text('Thử sổ mẫu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in studySamples.entries)
              ActionChip(
                  label: Text(entry.value), avatar: const Icon(Icons.science_outlined, size: 17), onPressed: () => state.openStudySample(entry.key)),
          ]),
          if (state.courses.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Sổ của bạn', style: Theme.of(context).textTheme.titleMedium),
            for (final course in state.courses)
              ListTile(title: Text(course.title), leading: const Icon(Icons.book_outlined), onTap: () => state.selectCourse(course)),
          ],
        ]),
      ),
    );
  }
}
