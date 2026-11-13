import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../data/study_samples.dart';
import '../state/app_state.dart';
import 'notebook_screen.dart';
import 'review_screen.dart';
import 'study_account_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  void _library(BuildContext context, AppState state) {
    showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheet) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
        const ListTile(title: Text('Sổ học tập', style: TextStyle(fontWeight: FontWeight.w800))),
        ListTile(leading: const Icon(Icons.add), title: const Text('Tạo sổ mới'), onTap: () {
          Navigator.pop(sheet);
          state.createNotebook();
        }),
        for (final course in state.courses)
          ListTile(leading: Icon(course.isSample ? Icons.auto_stories_outlined : Icons.book_outlined),
            selected: state.selectedCourseId == course.id, title: Text(course.title), onTap: () {
              Navigator.pop(sheet);
              state.selectCourse(course);
            }),
        const Divider(),
        for (final entry in studySamples.entries)
          ListTile(leading: const Icon(Icons.science_outlined), title: Text(entry.value), subtitle: const Text('Sổ mẫu'),
            onTap: () {
              Navigator.pop(sheet);
              state.openStudySample(entry.key);
            }),
      ]),
    ));
  }

  void _account(BuildContext context, AppState state) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StudyAccountScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = state.selectedCourse;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Sổ học tập', icon: const Icon(Icons.menu_book_outlined), onPressed: () => _library(context, state)),
        title: Text(course?.title ?? 'Học Thông Minh', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(tooltip: 'Ôn tập', icon: const Icon(Icons.track_changes_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewScreen()))),
          IconButton(tooltip: 'Tài khoản', icon: Icon(state.signedIn ? Icons.account_circle : Icons.person_outline),
            onPressed: () => _account(context, state)),
        ],
      ),
      body: Column(children: [
        if (state.syncError != null)
          MaterialBanner(content: Text(state.syncError!), actions: [
            TextButton(onPressed: state.retrySync, child: const Text('Thử lưu lại')),
            if (state.signedIn) TextButton(onPressed: () async {
              final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
                title: const Text('Tải bản đồng bộ?'),
                content: const Text('Thay đổi chưa đồng bộ trên máy này sẽ bị thay bằng bản trên tài khoản.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Hủy')),
                  FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('Tải bản đồng bộ')),
                ],
              ));
              if (confirmed != true || !context.mounted) return;
              try {
                await state.useCloudCopy();
              } catch (_) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa thể tải bản đồng bộ.')));
              }
            }, child: const Text('Tải bản đồng bộ')),
          ]),
        if (state.canImportGuest)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(alignment: Alignment.centerLeft, child: TextButton.icon(
              onPressed: () async {
                final count = await state.importGuestCourses();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã nhập $count sổ từ máy này.')));
              },
              icon: const Icon(Icons.file_download_outlined), label: const Text('Nhập sổ đã lưu trên máy'),
            )),
          ),
        Expanded(child: course == null ? const _Welcome() : NotebookScreen(key: ValueKey(course.id), course: course)),
      ]),
    );
  }
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
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 730),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
        Icon(Icons.auto_stories_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text('Hôm nay bạn muốn học gì?', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        TextField(controller: _input, textInputAction: TextInputAction.go, onSubmitted: _start,
          decoration: InputDecoration(labelText: 'Chủ đề hoặc mục tiêu', hintText: 'Ví dụ: Tìm nguồn và lên lộ trình học xác suất',
            suffixIcon: IconButton(tooltip: 'Bắt đầu', onPressed: _creating ? null : () => _start(), icon: const Icon(Icons.arrow_forward)))),
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
            ActionChip(label: Text(entry.value), avatar: const Icon(Icons.science_outlined, size: 17),
              onPressed: () => state.openStudySample(entry.key)),
        ]),
        if (state.courses.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Sổ của bạn', style: Theme.of(context).textTheme.titleMedium),
          for (final course in state.courses)
            ListTile(title: Text(course.title), leading: const Icon(Icons.book_outlined), onTap: () => state.selectCourse(course)),
        ],
      ]),
    ));
  }
}
