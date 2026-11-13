import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../theme.dart';

/// Mot nguon web: tieu de, ten mien, nhan tin cay, mo link goc.
class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.source, required this.selected, required this.onChanged});
  final WebSource source;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = source.trusted ? AppColors.success : const Color(0xFFB26A00);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: CheckboxListTile(
          value: selected,
          onChanged: (v) => onChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(source.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 4),
            Row(children: [
              Icon(source.trusted ? Icons.verified : Icons.help_outline, size: 16, color: color),
              const SizedBox(width: 4),
              Text(source.trusted ? 'Đáng tin' : 'Cần kiểm tra', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(child: Text(source.domain, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
              InkWell(
                onTap: () => launchUrl(Uri.parse(source.url), mode: LaunchMode.externalApplication),
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.open_in_new, size: 18)),
              ),
            ]),
            if (source.snippet.isNotEmpty) Text(source.snippet, maxLines: 3, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
