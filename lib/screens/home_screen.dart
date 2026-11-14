import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/study_samples.dart';
import '../models/models.dart';
import '../services/intent.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/mascot.dart';
import '../widgets/motion.dart';
import '../widgets/roadmap_map.dart';
import '../widgets/sims/sim_catalog.dart';
import 'home_shell.dart';
import 'lab_screen.dart';
import 'review_screen.dart';
import 'roadmap_screen.dart';
import 'study_account_screen.dart';

/// Trang chu (man dau tien): thong ke hoc tap, linh vat goi y, o giao viec cho AI, so hoc va thi nghiem.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _input = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _openNotebook(Course course, {NotebookTab tab = NotebookTab.chat, String? question}) async {
    final state = context.read<AppState>();
    if (state.selectedCourseId != course.id) await state.selectCourse(course);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NotebookScreen(initialTab: tab, initialQuestion: question)));
  }

  /// Dieu huong theo y dinh: lap lo trinh -> so moi + hoi muc tieu; thi nghiem -> Phong thi nghiem;
  /// con lai -> mo so dang hoc o tab Chat va gui cau hoi.
  Future<void> _submit([String? value]) async {
    final text = (value ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    final state = context.read<AppState>();
    final intent = detectIntent(text);
    setState(() => _busy = true);
    try {
      if (intent == ChatIntent.plan) {
        await state.createNotebook(prompt: text);
        if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotebookScreen(initialTab: NotebookTab.studio)));
      } else {
        final course = state.selectedCourse ?? await state.createNotebook(title: _titleFrom(text));
        if (mounted) await _openNotebook(course, question: text);
      }
      _input.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _titleFrom(String text) {
    final t = text.replaceAll(RegExp(r'\s+'), ' ');
    return t.length <= 40 ? t : '${t.substring(0, 40)}…';
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 11 ? 'Chào buổi sáng' : h < 18 ? 'Chào buổi chiều' : 'Chào buổi tối';
  }

  (String, MascotMood) _tip(AppState s, List<(Course, Lesson)> review) {
    if (s.courses.isEmpty) return ('Mình là Cú Đỏ. Tải slide hoặc gõ môn bạn muốn học, mình lập lộ trình giúp nhé!', MascotMood.happy);
    if (s.todayActivity >= AppState.dailyGoal) return ('Xong mục tiêu hôm nay rồi, giỏi quá! Thử một thí nghiệm cho vui nhé.', MascotMood.cheer);
    if (review.isNotEmpty) return ('Có ${review.length} bài bạn hay sai. Ôn lại 5 phút là nhớ lâu hơn đó!', MascotMood.thinking);
    if (s.streak > 0) return ('Chuỗi ${s.streak} ngày liên tiếp! Học thêm chút để giữ lửa nha.', MascotMood.happy);
    return ('Hôm nay học gì đây? Hỏi mình bất cứ điều gì, hoặc vào Phòng thí nghiệm.', MascotMood.idle);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final review = [
      for (final c in s.courses)
        for (final l in c.lessons.where(needsReview)) (c, l),
    ];
    final current = s.selectedCourse ?? s.courses.firstOrNull;
    final next = current == null ? null : RoadmapGraph(current.lessons).next();
    final done = s.courses.fold(0, (n, c) => n + c.doneLessons);
    final (tip, mood) = _tip(s, review);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Học Thông Minh', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Ôn tập',
            icon: const Icon(Icons.track_changes_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewScreen())),
          ),
          IconButton(
            tooltip: 'Tài khoản',
            icon: Icon(s.signedIn ? Icons.account_circle : Icons.person_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyAccountScreen())),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Mascot(size: 56, mood: mood),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_greeting(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
                    const SizedBox(height: 2),
                    Text(tip, style: const TextStyle(color: AppColors.muted, fontSize: 14.5)),
                  ]),
                ),
              ]).enter(context),
              const SizedBox(height: 18),
              _AskBox(controller: _input, busy: _busy, onSubmit: _submit).enter(context, index: 1),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _Stat(icon: Icons.local_fire_department, color: const Color(0xFFFF7A00), value: '${s.streak}', label: 'ngày liên tiếp')),
                const SizedBox(width: 8),
                Expanded(
                  child: _Stat(
                    icon: Icons.bolt,
                    color: AppColors.primary,
                    value: '${s.todayActivity}/${AppState.dailyGoal}',
                    label: 'điểm hôm nay',
                    progress: (s.todayActivity / AppState.dailyGoal).clamp(0, 1).toDouble(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _Stat(icon: Icons.check_circle, color: AppColors.success, value: '$done', label: 'bài đã học')),
              ]),
              if (s.canImportGuest)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final count = await s.importGuestCourses();
                      messenger.showSnackBar(SnackBar(content: Text('Đã nhập $count sổ từ máy này.')));
                    },
                    icon: const Icon(Icons.file_download_outlined),
                    label: const Text('Nhập sổ đã lưu trên máy'),
                  ),
                ),
              if (current != null && next != null) ...[
                const SizedBox(height: 18),
                const _Section('Tiếp tục học'),
                const SizedBox(height: 6),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
                    leading: const CircleAvatar(backgroundColor: AppColors.primary, child: Icon(Icons.play_arrow, color: Colors.white)),
                    title: Text(next.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(current.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.read<AppState>().selectCourse(current);
                      if (context.mounted) openLesson(context, current, next);
                    },
                  ),
                ),
              ],
              if (review.isNotEmpty) ...[
                const SizedBox(height: 18),
                const _Section('Cần ôn lại'),
                const SizedBox(height: 6),
                for (final (c, l) in review.take(3))
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: const Icon(Icons.refresh, color: AppColors.primary),
                      title: Text(l.title),
                      subtitle: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () async {
                        await context.read<AppState>().selectCourse(c);
                        if (context.mounted) openLesson(context, c, l);
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 18),
              Row(children: [
                const Expanded(child: _Section('Sổ học tập')),
                TextButton.icon(
                  onPressed: () async {
                    final c = await s.createNotebook(sourcesFirst: true);
                    if (mounted) await _openNotebook(c, tab: NotebookTab.sources);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tạo sổ mới'),
                ),
              ]),
              if (s.courses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Chưa có sổ nào. Tạo sổ từ tài liệu, hoặc mở thử một sổ mẫu bên dưới.', style: TextStyle(color: AppColors.muted)),
                ),
              for (final c in s.courses)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    key: ValueKey('notebook-${c.id}'),
                    leading: Icon(c.isSample ? Icons.auto_stories_outlined : Icons.book_outlined, color: AppColors.primary),
                    title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(c.lessons.isEmpty
                        ? '${c.sources.length} nguồn · chưa có lộ trình'
                        : '${c.doneLessons}/${c.lessons.length} bài · ${c.sources.length} nguồn'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openNotebook(c),
                  ),
                ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final e in studySamples.entries)
                  ActionChip(
                    avatar: const Icon(Icons.auto_stories_outlined, size: 17),
                    label: Text(e.value),
                    onPressed: () async {
                      await s.openStudySample(e.key);
                      final c = s.selectedCourse;
                      if (c != null && mounted) await _openNotebook(c, tab: NotebookTab.studio);
                    },
                  ),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(child: _Section('Phòng thí nghiệm ảo')),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LabScreen(courseId: current?.id))),
                  child: const Text('Xem tất cả'),
                ),
              ]),
              SizedBox(
                height: 150,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final id in ['refraction', 'circuit', 'titration', 'wave', 'lens'])
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        width: 150,
                        child: LabTile(
                          icon: simCatalog[id]!.icon,
                          title: simCatalog[id]!.title,
                          summary: simCatalog[id]!.summary,
                          onTap: () {
                            context.read<AppState>().logActivity();
                            openSim(context, simCatalog[id]!, courseId: current?.id);
                          },
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label, this.progress});
  final IconData icon;
  final Color color;
  final String value, label;
  final double? progress;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Flexible(child: Text(value, maxLines: 1, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 5, color: color, backgroundColor: AppColors.accent),
            ),
          ],
        ]),
      );
}

class _AskBox extends StatelessWidget {
  const _AskBox({required this.controller, required this.busy, required this.onSubmit});
  final TextEditingController controller;
  final bool busy;
  final Future<void> Function([String? value]) onSubmit;

  static const _ideas = ['Lập lộ trình ôn Vật lý 12 trong 2 tuần', 'Vì sao ống hút trong cốc nước trông bị gãy?', 'Tạo quiz về định luật Ohm'];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (v) => onSubmit(v),
            decoration: InputDecoration(
              hintText: 'Hỏi hoặc giao việc cho AI…',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              suffixIcon: busy
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton.filled(tooltip: 'Gửi', onPressed: () => onSubmit(), icon: const Icon(Icons.arrow_upward)),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final idea in _ideas)
              ActionChip(
                  backgroundColor: Colors.white,
                  label: Text(idea, style: const TextStyle(fontSize: 12.5)),
                  onPressed: busy ? null : () => onSubmit(idea)),
          ]),
        ]),
      );
}

/// Tieu de muc gon (chu thuong dam), thay cho nhan in hoa.
class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700));
}
