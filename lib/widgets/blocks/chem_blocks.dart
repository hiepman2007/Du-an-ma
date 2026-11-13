import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../rich_content.dart';
import '../../services/chem.dart';
import '../../services/expr.dart';
import '../../theme.dart';
import 'common.dart';

Color hexColor(Object? v, [Color fallback = const Color(0xFFE8F1FF)]) {
  final s = '$v';
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)) return fallback;
  return Color(int.parse('FF${s.substring(1)}', radix: 16));
}

/// Phong thi nghiem hoa ao: chon chat cho vao coc, chinh nhiet do, xem hien tuong.
/// AI chi chuan bi bang ket qua cho tung to hop chat; hieu ung ve tren may.
class ReactionLabBlock extends StatefulWidget {
  const ReactionLabBlock({super.key, required this.block});
  final Block block;
  @override
  State<ReactionLabBlock> createState() => _ReactionLabBlockState();
}

class _ReactionLabBlockState extends State<ReactionLabBlock> with SingleTickerProviderStateMixin {
  late final Map<String, dynamic> _cfg = widget.block.rawMap('reaction') ?? {};
  late final List<Map<String, dynamic>> _reagents =
      (_cfg['reagents'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  late final List<Map<String, dynamic>> _reactions =
      (_cfg['reactions'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  late final bool _needsHeat = _reactions.any((r) => r['min_temp'] is num);

  final List<String> _inBeaker = [];
  double _temp = 25;
  Map<String, dynamic>? _result; // phan ung dang xay ra
  bool _mixed = false;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  final List<String> _log = [];

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _reagent(String id) => _reagents.firstWhere((r) => r['id'] == id, orElse: () => {});

  Color get _beforeColor {
    if (_inBeaker.isEmpty) return const Color(0x00FFFFFF);
    final liquids = _inBeaker.map((id) => hexColor(_reagent(id)?['color'])).toList();
    return liquids.reduce((a, b) => Color.lerp(a, b, 0.5)!);
  }

  void _add(String id) {
    if (_inBeaker.contains(id) || _inBeaker.length >= 3) return;
    setState(() {
      _inBeaker.add(id);
      _mixed = false;
      _result = null;
    });
  }

  void _mix() {
    final set = _inBeaker.toSet();
    Map<String, dynamic>? hit;
    for (final r in _reactions) {
      final ids = (r['reagents'] as List).map((e) => '$e').toSet();
      if (ids.length == set.length && ids.containsAll(set)) {
        final minT = r['min_temp'];
        if (minT is num && _temp < minT) continue;
        hit = r;
        break;
      }
    }
    setState(() {
      _mixed = true;
      _result = hit;
      final names = _inBeaker.map((id) => prettyFormula('${_reagent(id)?['formula'] ?? id}')).join(' + ');
      _log.insert(0, hit == null ? '$names: không phản ứng' : '$names: ${hit['observation']}');
    });
    _anim.forward(from: 0);
  }

  void _reset() {
    setState(() {
      _inBeaker.clear();
      _mixed = false;
      _result = null;
    });
    _anim.reset();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    final after = r == null ? _beforeColor : hexColor(r['color']);
    final minNeeded = _reactions
        .where((x) => x['min_temp'] is num)
        .map((x) => (x['min_temp'] as num).toDouble())
        .fold<double>(0, max);
    return BlockCard(
      icon: Icons.science,
      label: 'Phòng thí nghiệm ảo',
      title: widget.block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if ('${_cfg['setup'] ?? ''}'.isNotEmpty) Text('${_cfg['setup']}', style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 10),
        const Text('Chạm hóa chất để cho vào cốc (tối đa 3):', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in _reagents)
            ActionChip(
              avatar: CircleAvatar(backgroundColor: hexColor(g['color']), radius: 9),
              label: Text('${prettyFormula('${g['formula']}')} · ${g['name']}'),
              onPressed: _inBeaker.contains(g['id']) ? null : () => _add('${g['id']}'),
            ),
        ]),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 180,
            height: 200,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, _) => CustomPaint(
                painter: _BeakerPainter(
                  fill: _inBeaker.isEmpty ? 0 : 0.35 + 0.15 * _inBeaker.length,
                  color: _mixed ? Color.lerp(_beforeColor, after, Curves.easeInOut.transform(_anim.value))! : _beforeColor,
                  t: _anim.value,
                  gas: _mixed && r?['gas'] == true,
                  precipitate: _mixed && r?['precipitate'] == true,
                  precipitateColor: hexColor(r?['precipitate_color'], Colors.white),
                  heat: _needsHeat ? (_temp - 20) / 80 : 0,
                ),
              ),
            ),
          ),
        ),
        if (_inBeaker.isNotEmpty)
          Center(
            child: Text(_inBeaker.map((id) => prettyFormula('${_reagent(id)?['formula'] ?? id}')).join(' + '),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        if (_needsHeat) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.local_fire_department, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('Nhiệt độ: ${_temp.round()}°C'),
            Expanded(
              child: Slider(value: _temp, min: 20, max: max(100, minNeeded + 20), onChanged: (v) => setState(() => _temp = v)),
            ),
          ]),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _inBeaker.isEmpty || _mixed ? null : _mix,
              icon: const Icon(Icons.blender_outlined),
              label: const Text('Trộn / quan sát'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: _reset, child: const Text('Làm lại')),
        ]),
        if (_mixed)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: r == null ? const Color(0xFFF5F5F5) : AppColors.accent, borderRadius: BorderRadius.circular(12)),
            child: r == null
                ? Text('${_cfg['no_reaction_text'] ?? 'Không có hiện tượng gì xảy ra.'}')
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Eyebrow('Phương trình'),
                    Text(prettyFormula('${r['equation']}'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Eyebrow('Hiện tượng'),
                    RichContent('${r['observation']}'),
                    if (r['heat'] == 'exo') const Text('🔥 Phản ứng tỏa nhiệt'),
                    if (r['heat'] == 'endo') const Text('❄️ Phản ứng thu nhiệt'),
                    const SizedBox(height: 6),
                    const Eyebrow('Giải thích'),
                    RichContent('${r['explanation']}'),
                  ]),
          ),
        if (_log.length > 1) ...[
          const SizedBox(height: 10),
          const Eyebrow('Nhật ký thí nghiệm', color: AppColors.muted),
          for (final l in _log.take(5)) Text('• $l', style: const TextStyle(fontSize: 13)),
        ],
        if ('${_cfg['safety'] ?? ''}'.isNotEmpty && _cfg['safety'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.health_and_safety_outlined, size: 18, color: Color(0xFFB26A00)),
              const SizedBox(width: 6),
              Expanded(child: Text('${_cfg['safety']}', style: const TextStyle(fontSize: 13))),
            ]),
          ),
        SourceNote(block: widget.block),
      ]),
    );
  }
}

class _BeakerPainter extends CustomPainter {
  _BeakerPainter({required this.fill, required this.color, required this.t, required this.gas, required this.precipitate, required this.precipitateColor, required this.heat});
  final double fill, t, heat;
  final Color color, precipitateColor;
  final bool gas, precipitate;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final left = w * 0.18, right = w * 0.82, top = h * 0.08, bottom = h * 0.88;
    final inner = Rect.fromLTRB(left, top, right, bottom);
    // chat long
    if (fill > 0) {
      final level = bottom - (bottom - top) * fill.clamp(0, 0.95);
      final liquid = RRect.fromRectAndCorners(Rect.fromLTRB(left + 3, level, right - 3, bottom - 3),
          bottomLeft: const Radius.circular(14), bottomRight: const Radius.circular(14));
      canvas.drawRRect(liquid, Paint()..color = color.withValues(alpha: 0.85));
      // bot khi
      if (gas) {
        final rnd = Random(3);
        final p = Paint()..color = Colors.white.withValues(alpha: 0.85);
        for (var i = 0; i < 18; i++) {
          final x = left + 10 + rnd.nextDouble() * (right - left - 20);
          final phase = (t * 3 + rnd.nextDouble()) % 1;
          final y = bottom - 8 - phase * (bottom - level - 10);
          canvas.drawCircle(Offset(x, y), 2 + rnd.nextDouble() * 3, p);
        }
      }
      // ket tua lang xuong
      if (precipitate) {
        final rnd = Random(7);
        final p = Paint()..color = precipitateColor;
        for (var i = 0; i < 60; i++) {
          final x = left + 8 + rnd.nextDouble() * (right - left - 16);
          final startY = level + rnd.nextDouble() * (bottom - level);
          final y = startY + (bottom - 8 - startY) * Curves.easeIn.transform(t);
          canvas.drawCircle(Offset(x, y), 1.6 + rnd.nextDouble() * 1.8, p);
        }
      }
    }
    // thanh coc
    final glass = Paint()
      ..color = const Color(0xFF9AA4AE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(left - 8, top)
      ..lineTo(left, top + 6)
      ..lineTo(left, bottom - 14)
      ..quadraticBezierTo(left, bottom, left + 14, bottom)
      ..lineTo(right - 14, bottom)
      ..quadraticBezierTo(right, bottom, right, bottom - 14)
      ..lineTo(right, top + 6)
      ..lineTo(right + 8, top);
    canvas.drawPath(path, glass);
    // vach chia
    final tick = Paint()..color = const Color(0xFFB8C0C8)..strokeWidth = 1.5;
    for (var i = 1; i <= 4; i++) {
      final y = bottom - (bottom - top) * i / 5;
      canvas.drawLine(Offset(left, y), Offset(left + 12, y), tick);
    }
    // ngon lua khi dun nong
    if (heat > 0.05) {
      final flame = Paint()..color = Color.lerp(const Color(0xFFFFC107), AppColors.primary, heat.clamp(0, 1))!;
      final cx = w / 2, fy = h * 0.97;
      final fp = Path()
        ..moveTo(cx - 14, fy)
        ..quadraticBezierTo(cx, fy - 22 * heat.clamp(0.3, 1), cx + 14, fy)
        ..close();
      canvas.drawPath(fp, flame);
    }
    canvas.clipRect(inner.inflate(20));
  }

  @override
  bool shouldRepaint(covariant _BeakerPainter old) =>
      old.t != t || old.color != color || old.fill != fill || old.heat != heat || old.gas != gas || old.precipitate != precipitate;
}

/// Cong thuc hoa hoc: go cong thuc, tu tinh khoi luong mol va thanh phan nguyen to.
class ChemFormulaBlock extends StatefulWidget {
  const ChemFormulaBlock({super.key, required this.block});
  final Block block;
  @override
  State<ChemFormulaBlock> createState() => _ChemFormulaBlockState();
}

class _ChemFormulaBlockState extends State<ChemFormulaBlock> {
  late final Map<String, dynamic> _chem = widget.block.rawMap('chem') ?? {};
  late final TextEditingController _ctrl = TextEditingController(text: plainFormula('${_chem['formula'] ?? ''}'));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _ctrl.text;
    final counts = parseFormula(f);
    final mass = molarMass(f);
    return BlockCard(
      icon: Icons.hub_outlined,
      label: 'Công thức hóa học',
      title: widget.block.title ?? '${_chem['name'] ?? ''}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.block.body?.isNotEmpty == true) RichContent(widget.block.body!),
        const SizedBox(height: 10),
        TextField(
          controller: _ctrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Thử gõ công thức khác (ví dụ CuSO4·5H2O)'),
        ),
        const SizedBox(height: 12),
        Center(child: Text(prettyFormula(f), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primary))),
        const SizedBox(height: 8),
        if (counts == null)
          const Center(child: Text('Chưa đọc được công thức này', style: TextStyle(color: AppColors.muted)))
        else ...[
          Center(child: Text('M = ${fmtNum(mass!)} g/mol', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          const SizedBox(height: 10),
          for (final e in counts.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                SizedBox(width: 36, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('× ${e.value}'),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (atomicMass[e.key]! * e.value) / mass,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 52, child: Text('${fmtNum(atomicMass[e.key]! * e.value * 100 / mass)}%', textAlign: TextAlign.right)),
              ]),
            ),
        ],
        SourceNote(block: widget.block),
      ]),
    );
  }
}
