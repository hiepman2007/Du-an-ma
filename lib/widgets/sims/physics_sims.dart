import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../services/expr.dart';
import 'sim_core.dart';

const _wire = Color(0xFF3A3F45);
const _ink = Color(0xFF2B2525);
const _red = Color(0xFFD01628);
const _blue = Color(0xFF2F6FDB);

// ================= Mach dien =================
class CircuitModel extends SimModel {
  const CircuitModel();

  ({double r, double i, double i1, double i2, double u1, double u2}) _solve(SimInput s) {
    final u = s['U'], r1 = math.max(0.1, s['R1']), r2 = math.max(0.1, s['R2']);
    if (s.option == 'parallel') {
      final r = r1 * r2 / (r1 + r2);
      return (r: r, i: u / r, i1: u / r1, i2: u / r2, u1: u, u2: u);
    }
    final i = u / (r1 + r2);
    return (r: r1 + r2, i: i, i1: i, i2: i, u1: i * r1, u2: i * r2);
  }

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height;
    final c = _solve(s);
    final l = w * 0.12, r = w * 0.88, top = h * 0.2, bot = h * 0.82, mid = (top + bot) / 2;
    final parallel = s.option == 'parallel';
    final x1 = parallel ? w * 0.55 : r;
    Path loop(double x) => Path()
      ..moveTo(l, mid - 9)
      ..lineTo(l, top)
      ..lineTo(x, top)
      ..lineTo(x, bot)
      ..lineTo(l, bot)
      ..lineTo(l, mid + 9);
    final wire = Paint()
      ..color = _wire
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final pathA = loop(x1), pathB = loop(r);
    canvas.drawPath(pathA, wire);
    if (parallel) canvas.drawPath(pathB, wire);

    // nguon: ban cuc duong dai, am ngan
    canvas.drawLine(Offset(l - 16, mid - 9), Offset(l + 16, mid - 9), Paint()..color = _ink..strokeWidth = 3);
    canvas.drawLine(Offset(l - 9, mid + 9), Offset(l + 9, mid + 9), Paint()..color = _ink..strokeWidth = 6);
    drawText(canvas, '+', Offset(l + 20, mid - 20), color: _red, size: 13, bold: true);
    drawText(canvas, '${fmtNum(s['U'])} V', Offset(l + 20, mid - 2), bold: true);

    // dong dien: cham do chay theo chieu quy uoc, toc do ty le cuong do
    final flow = Paint()..color = const Color(0xFFFFB020);
    double speed(double i) => (i * 30).clamp(6, 260).toDouble();
    if (parallel) {
      drawFlow(canvas, pathA, s.t * speed(c.i1), flow);
      drawFlow(canvas, pathB, s.t * speed(c.i2) + 9, flow);
    } else {
      drawFlow(canvas, pathA, s.t * speed(c.i), flow);
    }

    void bulb(Offset at, double power, String label) {
      final glow = 1 - math.exp(-power / 4);
      canvas.drawCircle(at, 30, Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.45 * glow));
      canvas.drawCircle(at, 15, Paint()..color = mix(Colors.white, const Color(0xFFFFE082), glow));
      canvas.drawCircle(at, 15, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2);
      final fil = Paint()..color = mix(_ink, const Color(0xFFFF8F00), glow)..strokeWidth = 1.6..style = PaintingStyle.stroke;
      canvas.drawPath(Path()
        ..moveTo(at.dx - 7, at.dy + 5)
        ..lineTo(at.dx - 3, at.dy - 5)
        ..lineTo(at.dx + 1, at.dy + 5)
        ..lineTo(at.dx + 5, at.dy - 5), fil);
      drawText(canvas, label, at + const Offset(0, 26), center: true, size: 10, background: Colors.white);
    }

    final p1 = c.i1 * c.i1 * s['R1'], p2 = c.i2 * c.i2 * s['R2'];
    if (parallel) {
      bulb(Offset(x1, mid), p1, 'R₁ ${fmtNum(s['R1'])} Ω');
      bulb(Offset(r, mid), p2, 'R₂ ${fmtNum(s['R2'])} Ω');
    } else {
      bulb(Offset(w * 0.5, top), p1, 'R₁ ${fmtNum(s['R1'])} Ω');
      bulb(Offset(r, mid), p2, 'R₂ ${fmtNum(s['R2'])} Ω');
    }
    // ampe ke tren day chinh
    final am = Offset(w * 0.32, bot);
    canvas.drawCircle(am, 13, Paint()..color = Colors.white);
    canvas.drawCircle(am, 13, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2);
    drawText(canvas, 'A', am, center: true, bold: true, size: 12);
    drawText(canvas, 'I = ${fmtNum(c.i)} A', am + const Offset(0, 22), center: true, bold: true, background: Colors.white);
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final c = _solve(s);
    return [
      ('Điện trở tương đương', '${fmtNum(c.r)} Ω'),
      ('Cường độ mạch chính', '${fmtNum(c.i)} A'),
      if (s.option == 'parallel') ...[('I₁', '${fmtNum(c.i1)} A'), ('I₂', '${fmtNum(c.i2)} A')] else ...[
        ('U₁', '${fmtNum(c.u1)} V'),
        ('U₂', '${fmtNum(c.u2)} V'),
      ],
      ('Công suất R₁', '${fmtNum(c.i1 * c.i1 * s['R1'])} W'),
    ];
  }
}

// ================= Con lac lo xo =================
class SpringModel extends SimModel {
  const SpringModel();
  double _omega(SimInput s) => math.sqrt(math.max(0.1, s['k']) / math.max(0.01, s['m']));

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height;
    final om = _omega(s), a = s['A'];
    final x = a * math.cos(om * s.t);
    final scale = w * 0.3 / 10;
    final eq = w * 0.58, y = h * 0.3, bw = 40.0 + s['m'] * 4, bh = 34.0;
    final ground = y + bh / 2;
    canvas.drawLine(Offset(10, ground), Offset(w - 10, ground), Paint()..color = const Color(0xFF9AA4AE)..strokeWidth = 2);
    canvas.drawRect(Rect.fromLTWH(6, y - 34, 8, 34 + bh / 2), Paint()..color = const Color(0xFF9AA4AE));
    drawDashed(canvas, Offset(eq, y - 32), Offset(eq, ground), Paint()..color = const Color(0xFF8A9199)..strokeWidth = 1);
    drawText(canvas, 'O', Offset(eq - 4, ground + 3), size: 10);
    final left = eq + x * scale - bw / 2;
    // lo xo zic-zac
    final coils = 14;
    final path = Path()..moveTo(14, y);
    final len = left - 14;
    for (var i = 1; i < coils * 2; i++) {
      path.lineTo(14 + len * i / (coils * 2), y + (i.isOdd ? -9 : 9));
    }
    path.lineTo(left, y);
    canvas.drawPath(path, Paint()..color = _ink..strokeWidth = 1.8..style = PaintingStyle.stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, y - bh / 2, bw, bh), const Radius.circular(6)), Paint()..color = _red);
    drawText(canvas, '${fmtNum(s['m'])} kg', Offset(left + bw / 2, y), center: true, color: Colors.white, bold: true, size: 10);
    // van toc
    final v = -a * om * math.sin(om * s.t);
    if (v.abs() > 0.5) {
      drawArrow(canvas, Offset(left + bw / 2, y - bh / 2 - 8), Offset(left + bw / 2 + v * 0.6, y - bh / 2 - 8),
          Paint()..color = _blue..strokeWidth = 2);
    }

    // do thi x(t) trong 2 chu ky gan nhat
    final gTop = h * 0.58, gBot = h * 0.96, gMid = (gTop + gBot) / 2, amp = (gBot - gTop) / 2 - 4;
    final axis = Paint()..color = const Color(0xFFB8BEC4)..strokeWidth = 1;
    canvas.drawLine(Offset(10, gMid), Offset(w - 10, gMid), axis);
    drawText(canvas, 'x(t)', Offset(12, gTop - 4), size: 10, bold: true);
    final period = 2 * math.pi / om, span = 2 * period;
    final graph = Path();
    for (var i = 0; i <= 120; i++) {
      final tt = s.t - span + span * i / 120;
      final gx = 10 + (w - 20) * i / 120;
      final gy = gMid - amp * (tt < 0 && s.t > 0 ? 0 : math.cos(om * tt)) * (a / 10);
      i == 0 ? graph.moveTo(gx, gy) : graph.lineTo(gx, gy);
    }
    canvas.drawPath(graph, Paint()..color = _red..strokeWidth = 2..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset(w - 10, gMid - amp * math.cos(om * s.t) * (a / 10)), 4, Paint()..color = _red);
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final om = _omega(s), am = s['A'] / 100;
    return [
      ('ω = √(k/m)', '${fmtNum(om)} rad/s'),
      ('Chu kỳ T', '${fmtNum(2 * math.pi / om)} s'),
      ('Tần số f', '${fmtNum(om / (2 * math.pi))} Hz'),
      ('v cực đại', '${fmtNum(am * om)} m/s'),
      ('Cơ năng', '${fmtNum(0.5 * s['k'] * am * am)} J'),
    ];
  }
}

// ================= Chat khi =================
class GasModel extends SimModel {
  const GasModel();
  double _pressure(SimInput s) => (s['N'] / 40) * (s['T'] / 300) * (5 / math.max(0.5, s['V']));

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height;
    final maxW = w - 70;
    final bw = maxW * (s['V'] / 10).clamp(0.12, 1.0);
    final box = Rect.fromLTWH(12, 12, bw, h - 24);
    final hot = ((s['T'] - 100) / 500).clamp(0.0, 1.0);
    canvas.drawRect(box, Paint()..color = mix(const Color(0xFFEAF2FF), const Color(0xFFFFEDE6), hot));
    canvas.drawRect(box, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2.5);
    // pit-tong
    canvas.drawRect(Rect.fromLTWH(box.right - 2, 10, 9, h - 20), Paint()..color = const Color(0xFF6B7178));
    canvas.drawRect(Rect.fromLTWH(box.right + 7, h / 2 - 3, w - box.right - 14, 6), Paint()..color = const Color(0xFF9AA4AE));
    final rnd = math.Random(7);
    final n = s['N'].round();
    final speed = 70 * math.sqrt(s['T'] / 300);
    final dot = Paint()..color = mix(_blue, _red, hot);
    for (var i = 0; i < n; i++) {
      final x0 = rnd.nextDouble(), y0 = rnd.nextDouble(), ang = rnd.nextDouble() * 2 * math.pi, k = 0.6 + rnd.nextDouble() * 0.8;
      final innerW = box.width - 10, innerH = box.height - 10;
      final px = bounce(x0 * innerW + math.cos(ang) * speed * k * s.t, innerW);
      final py = bounce(y0 * innerH + math.sin(ang) * speed * k * s.t, innerH);
      canvas.drawCircle(Offset(box.left + 5 + px, box.top + 5 + py), 3.6, dot);
    }
    // ap ke
    final g = Offset(w - 30, 34);
    canvas.drawCircle(g, 20, Paint()..color = Colors.white);
    canvas.drawCircle(g, 20, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2);
    final ang = math.pi * 0.75 + (_pressure(s) / 6).clamp(0.0, 1.0) * math.pi * 1.5;
    canvas.drawLine(g, g + Offset(math.cos(ang), math.sin(ang)) * 15, Paint()..color = _red..strokeWidth = 2.5);
    drawText(canvas, 'p', g + const Offset(0, 28), center: true, size: 10, bold: true);
  }

  @override
  List<(String, String)> readouts(SimInput s) => [
        ('Áp suất', '${fmtNum(_pressure(s))} atm'),
        ('Nhiệt độ', '${fmtNum(s['T'])} K (${fmtNum(s['T'] - 273)} °C)'),
        ('Thể tích', '${fmtNum(s['V'])} lít'),
        ('pV/T', fmtNum(_pressure(s) * s['V'] / s['T'])),
      ];
}

// ================= Luc day Ac-si-met =================
class BuoyancyModel extends SimModel {
  const BuoyancyModel();
  static const _g = 9.8;

  double _fraction(SimInput s) => s['rho_object'] / math.max(1, s['rho_liquid']);

  @override
  double? duration(SimInput input) => 4;

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height;
    final tank = Rect.fromLTRB(w * 0.22, h * 0.22, w * 0.78, h - 8);
    final water = tank.top + tank.height * 0.3;
    final side = 26 + 34 * math.pow(s['V'] / 500, 1 / 3).toDouble();
    final f = _fraction(s);
    final double target; // day vat o vi tri can bang
    if (f < 0.98) {
      target = water + side * f;
    } else if (f <= 1.02) {
      target = (water + tank.bottom) / 2 + side / 2;
    } else {
      target = tank.bottom - 2;
    }
    final start = water - 30;
    final bottom = s.t <= 0 ? start : target + (start - target) * math.exp(-1.8 * s.t) * math.cos(4.5 * s.t);
    final liquidColor = mix(const Color(0xFFBFE0FF), const Color(0xFF7FB2E6), (s['rho_liquid'] - 700) / 800);
    canvas.drawRect(Rect.fromLTRB(tank.left, water, tank.right, tank.bottom), Paint()..color = liquidColor.withValues(alpha: 0.75));
    final block = Rect.fromLTWH(w / 2 - side / 2, bottom - side, side, side);
    final objColor = mix(const Color(0xFFE8B36B), const Color(0xFF6E7B86), (s['rho_object'] - 100) / 2900);
    canvas.drawRRect(RRect.fromRectAndRadius(block, const Radius.circular(4)), Paint()..color = objColor);
    canvas.drawRRect(RRect.fromRectAndRadius(block, const Radius.circular(4)), Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // mat nuoc ve lai phia truoc phan chim
    canvas.drawLine(Offset(tank.left, water), Offset(tank.right, water), Paint()..color = const Color(0xFF4A90D9)..strokeWidth = 2);
    final walls = Paint()..color = _ink..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawPath(Path()
      ..moveTo(tank.left, tank.top)
      ..lineTo(tank.left, tank.bottom)
      ..lineTo(tank.right, tank.bottom)
      ..lineTo(tank.right, tank.top), walls);
    // luc
    final submerged = ((bottom - water) / side).clamp(0.0, 1.0);
    final weight = s['rho_object'] * s['V'] * 1e-6 * _g;
    final fa = s['rho_liquid'] * s['V'] * 1e-6 * _g * submerged;
    final unit = 22 / math.max(0.01, s['rho_liquid'] * s['V'] * 1e-6 * _g);
    final c = block.center;
    drawArrow(canvas, c, c + Offset(-6, weight * unit + 8), Paint()..color = _red..strokeWidth = 2.5);
    drawText(canvas, 'P', c + Offset(-18, weight * unit + 2), color: _red, bold: true);
    if (fa > 0.0001) {
      drawArrow(canvas, c, c - Offset(-6, fa * unit + 8), Paint()..color = _blue..strokeWidth = 2.5);
      drawText(canvas, 'Fᴀ', c - Offset(-10, fa * unit + 14), color: _blue, bold: true);
    }
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final f = _fraction(s);
    final weight = s['rho_object'] * s['V'] * 1e-6 * _g;
    final state = f < 0.98 ? 'Nổi, chìm ${fmtNum(f * 100)}% thể tích' : f <= 1.02 ? 'Lơ lửng' : 'Chìm xuống đáy';
    return [
      ('Trạng thái', state),
      ('Trọng lượng P', '${fmtNum(weight)} N'),
      ('Fᴀ khi chìm hẳn', '${fmtNum(s['rho_liquid'] * s['V'] * 1e-6 * _g)} N'),
    ];
  }
}

// ================= Dien truong =================
class FieldModel extends SimModel {
  const FieldModel();

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height;
    final scale = w * 0.6 / 8;
    final charges = [
      (Offset(w / 2 - s['d'] * scale / 2, h / 2), s['q1']),
      (Offset(w / 2 + s['d'] * scale / 2, h / 2), s['q2']),
    ].where((c) => c.$2.abs() > 0.05).toList();
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF7F9FC));
    Offset field(Offset p) {
      var e = Offset.zero;
      for (final (at, q) in charges) {
        final d = p - at;
        final r = math.max(6, d.distance);
        e += d * (q / (r * r * r));
      }
      return e;
    }

    final line = Paint()..color = const Color(0xFF8A96A3)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    final dot = Paint()..color = const Color(0xFFFFB020);
    final positives = charges.where((c) => c.$2 > 0).toList();
    final seeds = positives.isNotEmpty ? positives : charges;
    final sign = positives.isNotEmpty ? 1.0 : -1.0;
    for (final (at, q) in seeds) {
      final n = (8 + 3 * q.abs()).round();
      for (var k = 0; k < n; k++) {
        final a = 2 * math.pi * k / n;
        var p = at + Offset(math.cos(a), math.sin(a)) * 11;
        final path = Path()..moveTo(p.dx, p.dy);
        for (var step = 0; step < 220; step++) {
          final e = field(p);
          if (e.distance < 1e-9) break;
          p += e / e.distance * 5 * sign;
          path.lineTo(p.dx, p.dy);
          if (p.dx < -5 || p.dy < -5 || p.dx > w + 5 || p.dy > h + 5) break;
          if (charges.any((c) => c.$1 != at && (c.$1 - p).distance < 10)) break;
        }
        canvas.drawPath(path, line);
        drawFlow(canvas, path, s.t * 40 * sign, dot, spacing: 34, radius: 2);
      }
    }
    for (final (at, q) in charges) {
      final col = q > 0 ? _red : _blue;
      final r = 10 + q.abs() * 1.6;
      canvas.drawCircle(at, r, Paint()..color = col);
      drawText(canvas, q > 0 ? '+' : '−', at, center: true, color: Colors.white, size: 16, bold: true);
    }
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final q1 = s['q1'], q2 = s['q2'], r = math.max(0.1, s['d']) / 100;
    final f = 9e9 * (q1 * q2).abs() * 1e-12 / (r * r);
    final kind = q1 == 0 || q2 == 0 ? 'Không tương tác' : (q1 * q2 > 0 ? 'Đẩy nhau' : 'Hút nhau');
    return [('Lực Cu-lông', '${fmtNum(f)} N'), ('Tương tác', kind), ('Khoảng cách', '${fmtNum(s['d'])} cm')];
  }
}

// ================= Song co =================
class WaveModel extends SimModel {
  const WaveModel();

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height;
    final omega = 2 * math.pi * s['f'];
    if (s.option == 'interference') {
      final scale = w / 24; // khung rong 24 cm
      final k = 2 * math.pi / math.max(0.2, s['wavelength'] * scale);
      final s1 = Offset(w / 2 - s['d'] * scale / 2, 10), s2 = Offset(w / 2 + s['d'] * scale / 2, 10);
      const cell = 6.0;
      final paint = Paint();
      for (double y = 0; y < h; y += cell) {
        for (double x = 0; x < w; x += cell) {
          final p = Offset(x + cell / 2, y + cell / 2);
          final amp = math.cos(k * (p - s1).distance - omega * s.t) + math.cos(k * (p - s2).distance - omega * s.t);
          paint.color = mix(const Color(0xFF0E2A55), const Color(0xFFE6F2FF), (amp + 2) / 4);
          canvas.drawRect(Rect.fromLTWH(x, y, cell + 0.5, cell + 0.5), paint);
        }
      }
      for (final src in [s1, s2]) {
        canvas.drawCircle(src, 6, Paint()..color = _red);
      }
      drawText(canvas, 'S₁', s1 + const Offset(-8, 8), color: Colors.white, bold: true);
      drawText(canvas, 'S₂', s2 + const Offset(-8, 8), color: Colors.white, bold: true);
      return;
    }
    final scale = (w - 32) / 12;
    final k = 2 * math.pi / math.max(0.2, s['wavelength'] * scale);
    final mid = h / 2, amp = h * 0.2;
    canvas.drawLine(Offset(16, mid), Offset(w - 16, mid), Paint()..color = const Color(0xFFD6DADF)..strokeWidth = 1);
    final rope = Path();
    for (double x = 16; x <= w - 16; x += 3) {
      final y = mid - amp * math.sin(k * (x - 16) - omega * s.t);
      x == 16 ? rope.moveTo(x, y) : rope.lineTo(x, y);
    }
    canvas.drawPath(rope, Paint()..color = _blue..strokeWidth = 2.5..style = PaintingStyle.stroke);
    for (double x = 16; x <= w - 16; x += 14) {
      final y = mid - amp * math.sin(k * (x - 16) - omega * s.t);
      final marked = (x - (w / 2)).abs() < 7;
      canvas.drawCircle(Offset(x, y), marked ? 6 : 3, Paint()..color = marked ? _red : _blue);
    }
    // thuoc do buoc song
    final lam = s['wavelength'] * scale;
    if (lam < w - 40) {
      final y = h - 14.0;
      drawArrow(canvas, Offset(20, y), Offset(20 + lam, y), Paint()..color = _ink..strokeWidth = 1.2, head: 5);
      drawArrow(canvas, Offset(20 + lam, y), Offset(20, y), Paint()..color = _ink..strokeWidth = 1.2, head: 5);
      drawText(canvas, 'λ', Offset(20 + lam / 2, y - 10), center: true, bold: true);
    }
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final v = s['wavelength'] * s['f'];
    return [
      ('Tốc độ v = λf', '${fmtNum(v)} cm/s'),
      ('Chu kỳ T', '${fmtNum(1 / math.max(0.01, s['f']))} s'),
      if (s.option == 'interference')
        ('Số cực đại giữa S₁S₂', '${2 * (s['d'] / math.max(0.1, s['wavelength'])).floor() + 1}')
      else
        ('Bước sóng', '${fmtNum(s['wavelength'])} cm'),
    ];
  }
}
