import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'roadmap_screen.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Khóa học của tôi', style: TextStyle(fontWeight: FontWeight.w700))),
      body: s.courses.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.auto_stories_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text('Chưa có khóa học nào', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('Tải lên slide, tài liệu PDF, ảnh chụp, hoặc tìm nguồn trên mạng để AI tạo khóa học.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
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
                ]),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: s.courses.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = s.courses[i];
                final total = c.lessons.length;
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoadmapScreen(courseId: c.id))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Eyebrow(c.sourceLabel),
                        const SizedBox(height: 4),
                        Text(c.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('$total bài · ${c.goal}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: total == 0 ? 0 : c.doneLessons / total, borderRadius: BorderRadius.circular(4)),
                        const SizedBox(height: 4),
                        Text('Hoàn thành ${c.doneLessons}/$total bài', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
