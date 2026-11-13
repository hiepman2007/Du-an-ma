import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/motion.dart';
import 'roadmap_screen.dart';

/// Bieu tuong theo mon hoc do AI nhan dien.
IconData subjectIcon(String subject) {
  final s = subject.toLowerCase();
  if (s.contains('hóa')) return Icons.science_outlined;
  if (s.contains('toán')) return Icons.functions;
  if (s.contains('lý')) return Icons.bolt_outlined;
  if (s.contains('sinh')) return Icons.eco_outlined;
  if (s.contains('sử') || s.contains('địa')) return Icons.public;
  if (s.contains('tin') || s.contains('lập trình')) return Icons.code;
  if (s.contains('anh') || s.contains('văn') || s.contains('ngữ')) return Icons.translate;
  if (s.contains('kinh tế') || s.contains('tài chính')) return Icons.trending_up;
  return Icons.auto_stories_outlined;
}

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final acc = s.totalAnswered == 0 ? null : s.totalCorrect / s.totalAnswered;
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverToBoxAdapter(
              child: HeroBackground(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(
                      child: Text('Học Thông Minh',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                      child: Text(s.role?.label ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  const Text('Hôm nay học gì nào? 👋', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    s.courses.isEmpty ? 'Thêm tài liệu, AI soạn khóa học tương tác cho bạn.' : 'Tiếp tục khóa học hoặc tạo khóa mới từ tài liệu.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _Stat(value: '${s.courses.length}', label: 'Khóa học'),
                    _Stat(value: '${s.totalAnswered}', label: 'Câu đã làm'),
                    _Stat(value: acc == null ? '—' : '${(acc * 100).round()}%', label: 'Tỉ lệ đúng'),
                  ]),
                  const SizedBox(height: 16),
                  PressScale(
                    onTap: onCreate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.add_circle, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Tạo khóa học mới', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ]),
              ).enter(context),
            ),
          ),
          if (s.courses.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _EmptyState(onCreate: onCreate))
          else ...[
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              sliver: SliverToBoxAdapter(child: SectionHeader(eyebrow: 'Tiếp tục học', title: 'Khóa học của tôi')),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: s.courses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _CourseCard(course: s.courses[i]).enter(context, index: i + 1),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ]),
      );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final total = c.lessons.length;
    final progress = total == 0 ? 0.0 : c.doneLessons / total;
    return PressScale(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoadmapScreen(courseId: c.id))),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
              child: Icon(subjectIcon(c.subject), color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Eyebrow(c.subject.isNotEmpty ? c.subject : c.sourceLabel),
                const SizedBox(height: 2),
                Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${c.doneLessons}/$total bài · ${c.enabledSources.length} nguồn',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            ProgressRing(value: progress, size: 48, stroke: 5),
          ]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
      child: const Icon(Icons.auto_stories, size: 48, color: AppColors.primary),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        reduceMotion(context)
            ? icon
            : icon.animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -4, end: 4, duration: 1600.ms, curve: Curves.easeInOut),
        const SizedBox(height: 16),
        const Text('Chưa có khóa học nào', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Thêm slide, PDF, ảnh chụp vở hoặc tìm nguồn trên mạng — AI soạn lộ trình, bài học và mô phỏng cho bạn.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Tạo khóa học')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final c = await context.read<AppState>().addSampleCourse();
            if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => RoadmapScreen(courseId: c.id)));
          },
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Xem khóa học mẫu'),
        ),
      ]).enter(context, index: 1),
    );
  }
}
