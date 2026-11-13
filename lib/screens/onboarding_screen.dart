import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';

const roleIcons = {
  UserRole.student: Icons.school_outlined,
  UserRole.pupil: Icons.backpack_outlined,
  UserRole.worker: Icons.work_outline,
  UserRole.teacher: Icons.co_present_outlined,
};

/// Chon vai tro lan dau (doi lai duoc o tab Ho so). AI dieu chinh giong van, do kho theo vai tro.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.isChange = false});
  final bool isChange;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: isChange ? AppBar(title: const Text('Đổi vai trò')) : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
            if (!isChange) ...[
              Icon(Icons.auto_awesome, size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text('Học Thông Minh', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('Biến tài liệu của bạn thành khóa học tương tác: lộ trình, bài giảng, bài tập và mô phỏng do AI tạo.'),
              const SizedBox(height: 24),
            ],
            Text('Bạn là ai?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final r in UserRole.values)
              Card(
                color: s.role == r ? Theme.of(context).colorScheme.primaryContainer : null,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Icon(roleIcons[r], size: 32, color: Theme.of(context).colorScheme.primary),
                  title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  subtitle: Text(r.description),
                  onTap: () async {
                    await context.read<AppState>().setRole(r);
                    if (isChange && context.mounted) Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
