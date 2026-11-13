import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/app_state.dart';

class StudyCitation extends StatelessWidget {
  const StudyCitation({super.key, required this.course, required this.block});

  final Course course;
  final Block block;

  @override
  Widget build(BuildContext context) {
    final source = course.sources.where((s) =>
      s.id == block.sourceId || (block.sourceUrl != null && s.url == block.sourceUrl)).firstOrNull;
    if (source == null && block.sourceQuote == null && block.sourcePage == null) return const SizedBox.shrink();
    final page = block.sourcePage;
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(Icons.format_quote_outlined, size: 16),
        label: Text([
          source?.title ?? 'Xem trích dẫn',
          if (page != null) 'trang $page',
        ].join(' · '), overflow: TextOverflow.ellipsis),
        onPressed: () => showDialog<void>(context: context, builder: (_) => AlertDialog(
          title: Text(source?.title ?? 'Trích dẫn'),
          content: SingleChildScrollView(child: SelectableText([
            if (page != null) 'Trang $page',
            if (block.sourceQuote?.isNotEmpty ?? false) block.sourceQuote!
            else if (page != null && source != null)
              source.pages.where((p) => p['page'] == page).firstOrNull?['text'] as String? ?? ''
            else if (source?.extract.isNotEmpty ?? false) source!.extract
            else if (source?.text?.isNotEmpty ?? false) source!.text!,
          ].join('\n\n'))),
          actions: [
            if (source?.url != null || source?.storagePath != null)
              TextButton(onPressed: () async {
                try {
                  final url = source?.url ?? await context.read<AppState>().account?.sourceReadUrl(source!.storagePath!);
                  final uri = Uri.tryParse(url ?? '');
                  if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                    await launchUrl(page == null ? uri : uri.replace(fragment: 'page=$page'), mode: LaunchMode.externalApplication);
                  }
                } catch (_) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa thể mở nguồn.')));
                }
              }, child: const Text('Mở nguồn gốc')),
          ],
        )),
      ),
    );
  }
}
