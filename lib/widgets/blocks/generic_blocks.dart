import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/net_image.dart';
import '../../theme.dart';
import '../rich_content.dart';
import 'common.dart';
import 'question_blocks.dart' show normalize;

/// Giai tung buoc: mo dan tung buoc; buoc co dap an thi hoc sinh tu thu truoc.
class StepSolverBlock extends StatefulWidget {
  const StepSolverBlock({super.key, required this.block});
  final Block block;
  @override
  State<StepSolverBlock> createState() => _StepSolverBlockState();
}

class _StepSolverBlockState extends State<StepSolverBlock> {
  late final List<Map<String, dynamic>> _steps = widget.block.rawList('steps');
  int _shown = 0;
  final _ctrl = TextEditingController();
  bool? _lastTry;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _reveal() => setState(() {
    _shown++;
    _ctrl.clear();
    _lastTry = null;
  });

  @override
  Widget build(BuildContext context) {
    final next = _shown < _steps.length ? _steps[_shown] : null;
    final nextAnswer = next?['answer'] is String && '${next!['answer']}'.trim().isNotEmpty ? '${next['answer']}' : null;
    return BlockCard(
      icon: Icons.format_list_numbered,
      label: 'Giải từng bước',
      title: widget.block.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
            child: RichContent(widget.block.body ?? ''),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < _shown; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NumberTile(i + 1, done: true),
                  const SizedBox(width: 10),
                  Expanded(child: RichContent('${_steps[i]['text']}')),
                ],
              ),
            ),
          if (next != null) ...[
            if (nextAnswer != null) ...[
              Text('Bước ${_shown + 1}: bạn thử tự làm trước nhé', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(hintText: 'Kết quả bước này'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => setState(() => _lastTry = normalize(_ctrl.text) == normalize(nextAnswer)),
                    child: const Text('Thử'),
                  ),
                ],
              ),
              if (_lastTry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _lastTry! ? 'Chính xác! Xem lời giải để đối chiếu.' : 'Chưa khớp, thử lại hoặc xem lời giải.',
                    style: TextStyle(color: _lastTry! ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 6),
            ],
            OutlinedButton.icon(
              onPressed: _reveal,
              icon: const Icon(Icons.visibility_outlined),
              label: Text('Xem bước ${_shown + 1}/${_steps.length}'),
            ),
          ] else
            const Text(
              '✅ Đã xem hết lời giải',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.success),
            ),
          SourceNote(block: widget.block),
        ],
      ),
    );
  }
}

/// So do tu duy: nut trung tam o giua, cac nut con xep vong tron; cham nut de xem giai thich.
class ConceptMapBlock extends StatefulWidget {
  const ConceptMapBlock({super.key, required this.block});
  final Block block;
  @override
  State<ConceptMapBlock> createState() => _ConceptMapBlockState();
}

class _ConceptMapBlockState extends State<ConceptMapBlock> {
  late final List<Map<String, dynamic>> _nodes = widget.block.rawList('nodes');
  late final List<Map<String, dynamic>> _edges = widget.block.rawList('edges');
  late String? _selected = _nodes.isEmpty ? null : '${_nodes.first['id']}';

  @override
  Widget build(BuildContext context) {
    final sel = _nodes.where((n) => n['id'] == _selected).firstOrNull;
    return BlockCard(
      icon: Icons.account_tree_outlined,
      label: 'Sơ đồ tư duy',
      title: widget.block.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.block.body?.isNotEmpty == true) RichContent(widget.block.body!),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth, h = max(300.0, w * 0.95);
              final center = Offset(w / 2, h / 2);
              final r = min(w, h) / 2 - 48;
              final pos = <String, Offset>{};
              for (var i = 0; i < _nodes.length; i++) {
                final id = '${_nodes[i]['id']}';
                if (i == 0) {
                  pos[id] = center;
                } else {
                  final ang = -pi / 2 + 2 * pi * (i - 1) / max(1, _nodes.length - 1);
                  pos[id] = center + Offset(r * cos(ang), r * sin(ang));
                }
              }
              return SizedBox(
                width: w,
                height: h,
                child: Stack(
                  children: [
                    CustomPaint(size: Size(w, h), painter: _EdgePainter(_edges, pos)),
                    for (var i = 0; i < _nodes.length; i++)
                      Positioned(
                        left: pos['${_nodes[i]['id']}']!.dx - 52,
                        top: pos['${_nodes[i]['id']}']!.dy - 22,
                        width: 104,
                        child: GestureDetector(
                          onTap: () => setState(() => _selected = '${_nodes[i]['id']}'),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            decoration: BoxDecoration(
                              color: i == 0 ? AppColors.primary : (_selected == '${_nodes[i]['id']}' ? AppColors.accent : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: i == 0 ? AppColors.primary : AppColors.border),
                            ),
                            child: Text(
                              '${_nodes[i]['label']}',
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: i == 0 ? Colors.white : AppColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          if (sel != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${sel['label']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  RichContent('${sel['detail']}'),
                  for (final e in _edges.where((e) => e['from'] == _selected || e['to'] == _selected))
                    Text(
                      '→ ${e['label']}: ${_nodes.firstWhere((n) => n['id'] == (e['from'] == _selected ? e['to'] : e['from']), orElse: () => {'label': ''})['label']}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          SourceNote(block: widget.block),
        ],
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  _EdgePainter(this.edges, this.pos);
  final List<Map<String, dynamic>> edges;
  final Map<String, Offset> pos;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.border
      ..strokeWidth = 2;
    for (final e in edges) {
      final a = pos['${e['from']}'], b = pos['${e['to']}'];
      if (a != null && b != null) canvas.drawLine(a, b, p);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter old) => false;
}

/// Anh minh hoa that tu Wikimedia Commons (server da tim va kiem tra giay phep).
class ImageCardBlock extends StatelessWidget {
  const ImageCardBlock({super.key, required this.block});
  final Block block;

  @override
  Widget build(BuildContext context) {
    final img = block.rawMap('image');
    if (img == null) return const SizedBox.shrink();
    if (BlockFlat.of(context)) {
      // Trong chat: anh bo goc tran ngang, chu thich nho ben duoi.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(borderRadius: BorderRadius.circular(20), child: _NetImage(url: '${img['url']}')),
          const SizedBox(height: 6),
          if (block.body?.isNotEmpty == true) RichContent(block.body!, style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
          InkWell(
            onTap: img['page_url'] == null ? null : () => launchUrl(Uri.parse('${img['page_url']}'), mode: LaunchMode.externalApplication),
            child: Text('Ảnh: ${img['author']} · ${img['license']} · Wikimedia Commons',
                style: const TextStyle(fontSize: 11, color: AppColors.muted, decoration: TextDecoration.underline)),
          ),
        ]),
      );
    }
    return BlockCard(
      icon: Icons.image_outlined,
      label: 'Hình ảnh minh họa',
      title: block.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _NetImage(url: '${img['url']}'),
          ),
          if (block.body?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 8), child: RichContent(block.body!)),
          const SizedBox(height: 6),
          InkWell(
            onTap: img['page_url'] == null ? null : () => launchUrl(Uri.parse('${img['page_url']}'), mode: LaunchMode.externalApplication),
            child: Text(
              'Ảnh: ${img['author']} · ${img['license']} · Wikimedia Commons',
              style: const TextStyle(fontSize: 11, color: AppColors.muted, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anh mang co User-Agent rieng, loi thi hien nut Thu lai.
class _NetImage extends StatefulWidget {
  const _NetImage({required this.url});
  final String url;
  @override
  State<_NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<_NetImage> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) => Image.network(
    widget.url,
    key: ValueKey(_attempt),
    headers: imageHeaders,
    fit: BoxFit.cover,
    width: double.infinity,
    loadingBuilder: (c, child, p) => p == null ? child : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
    errorBuilder: (_, _, _) => SizedBox(
      height: 96,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Chưa tải được ảnh'),
            TextButton.icon(
              onPressed: () {
                PaintingBinding.instance.imageCache.evict(NetworkImage(widget.url, headers: imageHeaders));
                setState(() => _attempt++);
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    ),
  );
}
