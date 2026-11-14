import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/study_samples.dart';
import '../models/models.dart';
import '../services/intent.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'lab_screen.dart';
import 'study_account_screen.dart';
import 'study_actions.dart';
import 'study_pages.dart';
import 'tutor_chat_screen.dart';

/// Cac trang chuc nang cua mot so hoc tap (mo tu o Studio hoac tu the trong chat).
enum StudyPage {
  dashboard('Tổng quan', Icons.space_dashboard_outlined),
  plan('Lộ trình', Icons.route_outlined),
  chat('Hỏi đáp', Icons.chat_bubble_outline),
  research('Nghiên cứu', Icons.travel_explore),
  lab('Phòng thí nghiệm', Icons.science_outlined),
  quiz('Quiz', Icons.quiz_outlined),
  test('Thi thử', Icons.timer_outlined),
  flashcards('Thẻ ghi nhớ', Icons.style_outlined),
  arcade('Ghép nhanh', Icons.sports_esports_outlined),
  explainers('Tóm tắt & giải thích', Icons.lightbulb_outline),
  miniApps('Canvas AI', Icons.widgets_outlined),
  materials('Tài liệu', Icons.folder_outlined);

  const StudyPage(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Mo mot trang chuc nang thanh man rieng (co nut quay lai).
Future<void> openStudyPage(
  BuildContext context,
  Course course,
  StudyPage page,
) {
  if (page == StudyPage.chat) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TutorChatScreen(courseId: course.id)),
    );
  }
  if (page == StudyPage.lab) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LabScreen(courseId: course.id)),
    );
  }
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (ctx) {
        void go(StudyPage p) => openStudyPage(ctx, course, p);
        final body = switch (page) {
          StudyPage.dashboard => DashboardPage(course: course, onNavigate: go),
          StudyPage.plan => StudyPlanPage(course: course, onNavigate: go),
          StudyPage.research => ResearchPage(course: course, onNavigate: go),
          StudyPage.materials => MaterialsPage(course: course),
          _ => PracticePage(
            key: ValueKey(page),
            course: course,
            page: page,
            onNavigate: go,
          ),
        };
        return Scaffold(
          appBar: AppBar(title: Text(page.label)),
          body: SafeArea(top: false, child: body),
        );
      },
    ),
  );
}

enum NotebookTab {
  sources('Nguồn', Icons.folder_outlined),
  chat('Chat', Icons.chat_bubble_outline),
  studio('Studio', Icons.auto_awesome_mosaic_outlined);

  const NotebookTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// So hoc tap kieu NotebookLM: Nguon | Chat | Studio. Dien thoai: tab duoi day; man rong: 3 cot.
class NotebookScreen extends StatefulWidget {
  const NotebookScreen({
    super.key,
    this.initialTab = NotebookTab.chat,
    this.initialQuestion,
  });
  final NotebookTab initialTab;
  final String? initialQuestion;

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  late NotebookTab _tab = widget.initialTab;
  String? _courseId;

  /// So moi mo tu chu de -> hoi muc tieu va lap lo trinh; so tao tu tai lieu -> tab Nguon.
  void _onCourse(AppState state, Course course) {
    if (_courseId == course.id) return;
    _courseId = course.id;
    if (state.openSourcesFirst) {
      state.openSourcesFirst = false;
      _tab = NotebookTab.sources;
    }
    final prompt = state.openingPrompt;
    if (prompt != null) {
      state.openingPrompt = null;
      _tab = NotebookTab.studio;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _plan(course, prompt),
      );
    }
  }

  Future<void> _plan(Course course, String prompt) async {
    if (!mounted) return;
    final ok = await StudyActions.plan(
      context,
      course,
      topic: StudyActions.topicFrom(prompt),
    );
    if (ok && mounted) openStudyPage(context, course, StudyPage.plan);
  }

  Future<bool> _intercept(Course course, String question) async {
    if (detectIntent(question) != ChatIntent.plan || course.lessons.isNotEmpty) {
      return false;
    }
    await _plan(course, question);
    return true;
  }

  void _library(AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheet).size.height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const ListTile(
                title: Text(
                  'Sổ học tập',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Tạo sổ mới'),
                onTap: () {
                  Navigator.pop(sheet);
                  state.createNotebook(sourcesFirst: true);
                },
              ),
              for (final course in state.courses)
                ListTile(
                  leading: Icon(
                    course.isSample
                        ? Icons.auto_stories_outlined
                        : Icons.book_outlined,
                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _chat(AppState state, Course course) => TutorChat(
    key: ValueKey('chat-${course.id}'),
    courseId: course.id,
    initialQuestion: widget.initialQuestion,
    onIntercept: (q) => _intercept(course, q),
    onSaveNote: (m) => state.saveChatNote(course, m),
    emptyActions: [
      ActionChip(
        avatar: const Icon(Icons.route_outlined, size: 18),
        label: Text(course.lessons.isEmpty ? 'Lập lộ trình' : 'Xem lộ trình'),
        onPressed: () => course.lessons.isEmpty
            ? _plan(course, 'lập lộ trình')
            : openStudyPage(context, course, StudyPage.plan),
      ),
      ActionChip(
        avatar: const Icon(Icons.science_outlined, size: 18),
        label: const Text('Thí nghiệm ảo'),
        onPressed: () => openStudyPage(context, course, StudyPage.lab),
      ),
      if (course.enabledSources.isNotEmpty || course.isSample)
        ActionChip(
          avatar: const Icon(Icons.quiz_outlined, size: 18),
          label: const Text('Tạo quiz'),
          onPressed: () => StudyActions.quizBuilder(context, course),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = state.selectedCourse;
    if (course == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Chưa chọn sổ học tập.')),
      );
    }
    _onCourse(state, course);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final banner = [if (state.syncError != null) _SyncBanner(state: state)];
        final Widget body;
        if (wide) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 320,
                child: _Panel(
                  title: 'Nguồn',
                  child: MaterialsPage(course: course),
                ),
              ),
              Expanded(
                child: _Panel(title: 'Chat', child: _chat(state, course)),
              ),
              SizedBox(
                width: 360,
                child: _Panel(
                  title: 'Studio',
                  child: StudioPanel(course: course),
                ),
              ),
            ],
          );
        } else {
          body = IndexedStack(
            index: _tab.index,
            children: [
              MaterialsPage(course: course),
              _chat(state, course),
              StudioPanel(course: course),
            ],
          );
        }
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: InkWell(
              onTap: () => _library(state),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      course.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Tài khoản',
                icon: Icon(
                  state.signedIn ? Icons.account_circle : Icons.person_outline,
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudyAccountScreen()),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              ...banner,
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab.index,
                  onDestinationSelected: (i) =>
                      setState(() => _tab = NotebookTab.values[i]),
                  destinations: [
                    for (final t in NotebookTab.values)
                      NavigationDestination(icon: Icon(t.icon), label: t.label),
                  ],
                ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
    child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

/// O Studio kieu NotebookLM: luoi cong cu tao noi dung + danh sach da tao.
class StudioPanel extends StatelessWidget {
  const StudioPanel({super.key, required this.course});
  final Course course;

  static const tools = <(StudyPage, Color)>[
    (StudyPage.plan, Color(0xFFD01628)),
    (StudyPage.lab, Color(0xFF00897B)),
    (StudyPage.quiz, Color(0xFF2F6FDB)),
    (StudyPage.flashcards, Color(0xFFF2A100)),
    (StudyPage.test, Color(0xFF8E44AD)),
    (StudyPage.arcade, Color(0xFF1E8E3E)),
    (StudyPage.explainers, Color(0xFFEF6C00)),
    (StudyPage.research, Color(0xFF3949AB)),
    (StudyPage.miniApps, Color(0xFFD81B60)),
    (StudyPage.dashboard, Color(0xFF546E7A)),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final made = course.artifacts.reversed.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.9,
          children: [
            for (final (page, color) in tools)
              Material(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => openStudyPage(context, course, page),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        Icon(page.icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            page.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Đã tạo',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        if (made.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nội dung bạn tạo (quiz, thẻ ghi nhớ, tóm tắt, ghi chú…) sẽ nằm ở đây.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        for (final a in made)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(switch (a.kind) {
              StudyArtifactKind.flashcards => Icons.style_outlined,
              StudyArtifactKind.summary ||
              StudyArtifactKind.note => Icons.notes,
              StudyArtifactKind.canvas => Icons.widgets_outlined,
              _ => Icons.quiz_outlined,
            }, color: AppColors.primary),
            title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${a.kind.label} · ${a.sourceIds.length} nguồn',
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => StudyActions.open(context, course, a),
          ),
      ],
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => MaterialBanner(
    content: Text(state.syncError!),
    actions: [
      TextButton(onPressed: state.retrySync, child: const Text('Thử lưu lại')),
      if (state.signedIn)
        TextButton(
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialog) => AlertDialog(
                title: const Text('Tải bản đồng bộ?'),
                content: const Text(
                  'Thay đổi chưa đồng bộ trên máy này sẽ bị thay bằng bản trên tài khoản.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialog, false),
                    child: const Text('Hủy'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialog, true),
                    child: const Text('Tải bản đồng bộ'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
            try {
              await state.useCloudCopy();
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chưa thể tải bản đồng bộ.')),
                );
              }
            }
          },
          child: const Text('Tải bản đồng bộ'),
        ),
    ],
  );
}
