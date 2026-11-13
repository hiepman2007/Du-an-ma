import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import 'common.dart';

/// Tang du phong: mo phong tuy bien do AI viet (HTML), chi sinh khi hoc sinh bam,
/// chay trong WebView cach ly: CSP chan moi ket noi ngoai, chan dieu huong.
class CustomSimBlock extends StatefulWidget {
  const CustomSimBlock({super.key, required this.block, required this.lesson});
  final Block block;
  final Lesson lesson;
  @override
  State<CustomSimBlock> createState() => _CustomSimBlockState();
}

class _CustomSimBlockState extends State<CustomSimBlock> {
  bool _loading = false;
  String? _error;
  WebViewController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.block.sim != null) _load();
  }

  void _load() {
    if (kIsWeb) return;
    final html = '${widget.block.sim?['html'] ?? ''}';
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (r) => r.url.startsWith('about:') || r.url.startsWith('data:')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
      ))
      ..loadHtmlString(html);
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().generateSimulation(widget.lesson, widget.block);
      _load();
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.block.sim;
    return BlockCard(
      icon: Icons.auto_awesome_motion_outlined,
      label: 'Mô phỏng do AI tạo',
      title: sim?['title'] ?? widget.block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(sim?['instructions'] ?? '${widget.block.raw['sim_prompt'] ?? widget.block.body ?? ''}'),
        const SizedBox(height: 10),
        if (sim == null) ...[
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_circle_outline),
            label: Text(_loading ? 'AI đang dựng mô phỏng… (20–40 giây)' : 'Tạo mô phỏng'),
          ),
        ] else if (kIsWeb)
          const Text('Mô phỏng này chạy trong ứng dụng Android.', style: TextStyle(color: AppColors.muted))
        else if (_ctrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(height: 460, child: WebViewWidget(controller: _ctrl!)),
          ),
        const SizedBox(height: 6),
        const Text('Chạy cách ly: không truy cập mạng hay dữ liệu của ứng dụng.', style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}
