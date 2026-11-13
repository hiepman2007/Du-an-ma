import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/motion.dart';

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
              const Align(alignment: Alignment.centerLeft, child: AiOrb(size: 72)),
              const SizedBox(height: 18),
              Text('Học Thông Minh', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800))
                  .enter(context, index: 1),
              const SizedBox(height: 6),
              const Text('Biến tài liệu của bạn thành khóa học tương tác: lộ trình, bài giảng, bài tập và mô phỏng do AI tạo.')
                  .enter(context, index: 2),
              const SizedBox(height: 24),
            ],
            Text('Bạn là ai?', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)).enter(context, index: 3),
            const SizedBox(height: 12),
            for (final (i, r) in UserRole.values.indexed)
              PressScale(
                onTap: () async {
                  await context.read<AppState>().setRole(r);
                  if (isChange && context.mounted) Navigator.pop(context);
                },
                child: Card(
                  color: s.role == r ? Theme.of(context).colorScheme.primaryContainer : null,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(14)),
                        child: Icon(roleIcons[r], size: 26, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          Text(r.description, style: const TextStyle(color: AppColors.muted)),
                        ]),
                      ),
                      const Icon(Icons.arrow_forward, color: AppColors.primary),
                    ]),
                  ),
                ),
              ).enter(context, index: 4 + i),
          ],
        ),
      ),
    );
  }
}
