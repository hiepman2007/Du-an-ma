import 'dart:math';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../services/expr.dart';
import '../../theme.dart';
import 'common.dart';

/// Mo phong chuyen dong (nem xien, roi tu do, con lac): chinh tham so, bam Chay de xem hoat hinh. Tinh tren may.
class MotionSimBlock extends StatefulWidget {
  const MotionSimBlock({super.key, required this.block});
  final Block block;
  @override
  State<MotionSimBlock> createState() => _MotionSimBlockState();
}

class _MotionSimBlockState extends State<MotionSimBlock> with SingleTickerProviderStateMixin {
  late final Map<String, dynamic> _cfg = widget.block.rawMap('motion') ?? {};
  late final String _kind = '${_cfg['kind'] ?? 'projectile'}';
  late final List<LabVar> _vars =
      ((_cfg['variables'] as List?) ?? []).whereType<Map>().map((e) => LabVar.fromJson(Map<String, dynamic>.from(e))).toList();
  late final Map<String, double> _v = {for (final x in _vars) x.name: x.defaultValue};
  late final Ticker _ticker = createTicker(_tick);
  double _t = 0; // thoi gian mo phong (giay)
  bool _running = false;

  double _get(String n, double fallback) => _v[n] ?? fallback;
  double get _g => max(0.1, _get('g', 9.8));

  /// Thoi gian ket thuc mo phong.
  double get _duration {
    switch (_kind) {
      case 'free_fall':
        return sqrt(2 * _get('h', 20) / _g);
      case 'pendulum':
        return 3 * 2 * pi * sqrt(_get('L', 1) / _g); // 3 chu ky
      default:
        final v0 = _get('v0', 20), a = _get('angle', 45) * pi / 180;
        return max(0.01, 2 * v0 * sin(a) / _g);
    }
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    setState(() => _t = min(t, _duration));
    if (t >= _duration) {
      _ticker.stop();
      setState(() => _running = false);
    }
  }

  void _run() {
    _ticker.stop();
    setState(() {
      _t = 0;
      _running = true;
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  List<String> _stats() {
    switch (_kind) {
      case 'free_fall':
        final h = _get('h', 20);
        return ['Thời gian rơi: ${fmtNum(sqrt(2 * h / _g))} s', 'Vận tốc chạm đất: ${fmtNum(sqrt(2 * _g * h))} m/s', 't = ${fmtNum(_t)} s'];
      case 'pendulum':
        final period = 2 * pi * sqrt(_get('L', 1) / _g);
        return ['Chu kỳ T = 2π√(L/g) ≈ ${fmtNum(period)} s', 't = ${fmtNum(_t)} s'];
      default:
        final v0 = _get('v0', 20), a = _get('angle', 45) * pi / 180;
        return [
          'Tầm xa: ${fmtNum(v0 * v0 * sin(2 * a) / _g)} m',
          'Độ cao cực đại: ${fmtNum(pow(v0 * sin(a), 2) / (2 * _g))} m',
          'Thời gian bay: ${fmtNum(2 * v0 * sin(a) / _g)} s',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_kind) { 'free_fall' => 'Rơi tự do', 'pendulum' => 'Con lắc đơn', _ => 'Ném xiên' };
    return BlockCard(
      icon: Icons.sports_baseball_outlined,
      label: 'Mô phỏng chuyển động · $label',
      title: widget.block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.block.body?.isNotEmpty == true) Text(widget.block.body!),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.5,
          child: Container(
            decoration: BoxDecoration(color: const Color(0xFFF4F8FC), borderRadius: BorderRadius.circular(12)),
            child: CustomPaint(painter: _MotionPainter(kind: _kind, v: _v, t: _t, g: _g)),
          ),
        ),
        const SizedBox(height: 8),
        for (final s in _stats()) Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final x in _vars.where((x) => x.name != 'g' || _vars.length <= 3))
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(x.label, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text('${fmtNum(_v[x.name]!)} ${x.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            Slider(
              value: _v[x.name]!.clamp(x.min, x.max),
              min: x.min,
              max: x.max,
              onChanged: _running ? null : (val) => setState(() {
                _v[x.name] = val;
                _t = 0;
              }),
            ),
          ]),
        FilledButton.icon(
          onPressed: _running ? null : _run,
          icon: const Icon(Icons.play_arrow),
          label: Text(_t > 0 ? 'Chạy lại' : 'Chạy mô phỏng'),
        ),
        SourceNote(block: widget.block),
      ]),
    );
  }
}

class _MotionPainter extends CustomPainter {
  _MotionPainter({required this.kind, required this.v, required this.t, required this.g});
  final String kind;
  final Map<String, double> v;
  final double t, g;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ground = h - 18;
    final groundPaint = Paint()..color = const Color(0xFF9AA4AE)..strokeWidth = 2;
    final ball = Paint()..color = AppColors.primary;
    final trail = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (kind == 'pendulum') {
      final L = v['L'] ?? 1, th0 = (v['theta0'] ?? 20) * pi / 180;
      final theta = th0 * cos(sqrt(g / L) * t);
      final pivot = Offset(w / 2, 14);
      final len = min(h - 40, 40 + L * 40);
      final bob = pivot + Offset(len * sin(theta), len * cos(theta));
      canvas.drawLine(Offset(w * 0.3, 14), Offset(w * 0.7, 14), groundPaint);
      canvas.drawLine(pivot, bob, Paint()..color = const Color(0xFF2B2525)..strokeWidth = 2);
      canvas.drawCircle(bob, 12, ball);
      return;
    }

    canvas.drawLine(Offset(0, ground), Offset(w, ground), groundPaint);
    if (kind == 'free_fall') {
      final hgt = v['h'] ?? 20;
      final scale = (ground - 20) / hgt;
      final y = 0.5 * g * t * t;
      final pos = Offset(w / 2, ground - (hgt - min(y, hgt)) * scale);
      canvas.drawLine(Offset(w / 2, ground - hgt * scale), Offset(w / 2, pos.dy), trail);
      canvas.drawCircle(pos, 10, ball);
      return;
    }

    // nem xien
    final v0 = v['v0'] ?? 20, a = (v['angle'] ?? 45) * pi / 180;
    final range = max(1.0, v0 * v0 * sin(2 * a) / g);
    final hmax = max(1.0, pow(v0 * sin(a), 2) / (2 * g)).toDouble();
    final scale = min((w - 30) / range, (ground - 20) / hmax);
    Offset at(double tt) => Offset(15 + v0 * cos(a) * tt * scale, ground - (v0 * sin(a) * tt - 0.5 * g * tt * tt) * scale);
    final total = 2 * v0 * sin(a) / g;
    final path = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i <= 60; i++) {
      final tt = total * i / 60;
      if (tt > t) break;
      path.lineTo(at(tt).dx, at(tt).dy);
    }
    canvas.drawPath(path, trail);
    canvas.drawCircle(at(min(t, total)), 9, ball);
  }

  @override
  bool shouldRepaint(covariant _MotionPainter old) => true;
}
