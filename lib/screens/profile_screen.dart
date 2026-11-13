import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'onboarding_screen.dart';

/// Ho so: vai tro, thong ke su dung (bang chung cho BGK), xoa du lieu, ghi nguon.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final role = s.role;
    Widget stat(String value, String label) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(children: [
                Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: ListTile(
            leading: Icon(role == null ? Icons.person : roleIcons[role], color: AppColors.primary, size: 32),
            title: Text(role?.label ?? 'Chưa chọn', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('AI điều chỉnh giọng văn và độ khó theo vai trò'),
            trailing: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingScreen(isChange: true))),
              child: const Text('Đổi'),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Thống kê sử dụng', title: 'Bạn đã học được gì'),
        Row(children: [
          stat('${s.courses.length}', 'Khóa học'),
          const SizedBox(width: 8),
          stat('${s.totalLessonsGenerated}', 'Bài AI đã soạn'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          stat('${s.totalAnswered}', 'Câu đã làm'),
          const SizedBox(width: 8),
          stat(s.totalAnswered == 0 ? '—' : '${(s.totalCorrect * 100 / s.totalAnswered).round()}%', 'Tỉ lệ đúng'),
        ]),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Dữ liệu', title: 'Lưu trên máy của bạn'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text('Xóa toàn bộ dữ liệu'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Xóa toàn bộ dữ liệu?'),
                  content: const Text('Tất cả khóa học và tiến độ trên máy sẽ bị xóa, không khôi phục được.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Hủy')),
                    FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Xóa')),
                  ],
                ),
              );
              if (ok == true && context.mounted) await context.read<AppState>().clearAll();
            },
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(eyebrow: 'Ghi nguồn', title: 'Cảm hứng'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Ý tưởng sinh bài hai bước và chế độ tương tác tham khảo từ OpenMAIC (giấy phép MIT)'),
            onTap: () => launchUrl(Uri.parse('https://github.com/THU-MAIC/OpenMAIC'), mode: LaunchMode.externalApplication),
          ),
        ),
      ]),
    );
  }
}
