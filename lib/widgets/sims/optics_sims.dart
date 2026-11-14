import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../services/expr.dart';
import 'sim_core.dart';

const _ink = Color(0xFF2B2525);
const _beam = Color(0xFFE5392B);

String _medium(double n) {
  const known = [(1.0, 'không khí'), (1.33, 'nước'), (1.5, 'thủy tinh'), (2.42, 'kim cương')];
  for (final (value, name) in known) {
    if ((n - value).abs() < 0.05) return name;
  }
  return 'môi trường';
}

// ================= Khuc xa anh sang =================
class RefractionModel extends SimModel {
  const RefractionModel();

  double? _refracted(SimInput s) {
    final x = s['n1'] * math.sin(s['angle'] * math.pi / 180) / math.max(1, s['n2']);
    return x.abs() > 1 ? null : math.asin(x);
  }

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height, c = Offset(w / 2, h / 2);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h / 2), Paint()..color = mix(const Color(0xFFF5FAFF), const Color(0xFF9CC8F0), (s['n1'] - 1) / 1.5));
    canvas.drawRect(Rect.fromLTWH(0, h / 2, w, h / 2), Paint()..color = mix(const Color(0xFFF5FAFF), const Color(0xFF9CC8F0), (s['n2'] - 1) / 1.5));
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), Paint()..color = const Color(0xFF6B8DB3)..strokeWidth = 1.5);
    drawDashed(canvas, Offset(w / 2, 6), Offset(w / 2, h - 6), Paint()..color = const Color(0xFF8A9199)..strokeWidth = 1);
    drawText(canvas, 'n₁ = ${fmtNum(s['n1'])} (${_medium(s['n1'])})', const Offset(8, 6), size: 10, bold: true);
    drawText(canvas, 'n₂ = ${fmtNum(s['n2'])} (${_medium(s['n2'])})', Offset(8, h - 18), size: 10, bold: true);

    final i = s['angle'] * math.pi / 180, len = math.min(w, h) * 0.5;
    final start = c + Offset(-math.sin(i), -math.cos(i)) * len;
    final r = _refracted(s);
    final reflectEnd = c + Offset(math.sin(i), -math.cos(i)) * len;
    final beam = Paint()..color = _beam..strokeWidth = 3..strokeCap = StrokeCap.round;
    drawArrow(canvas, start, c, beam, head: 9);
    canvas.drawLine(c, reflectEnd, Paint()..color = _beam.withValues(alpha: r == null ? 1 : 0.25)..strokeWidth = r == null ? 3 : 2);
    Offset? end;
    if (r != null) {
      end = c + Offset(math.sin(r), math.cos(r)) * len;
      canvas.drawLine(c, end, beam);
    } else {
      drawText(canvas, 'Phản xạ toàn phần', c + const Offset(8, 10), color: _beam, bold: true, background: Colors.white);
    }
    // photon chay doc tia
    final photon = Paint()..color = const Color(0xFFFFE082);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo((end ?? reflectEnd).dx, (end ?? reflectEnd).dy);
    drawFlow(canvas, path, s.t * 90, photon, spacing: 40, radius: 3.5);
    // cung goc
    final arc = Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 1.2;
    canvas.drawArc(Rect.fromCircle(center: c, radius: 26), -math.pi / 2 - i, i, false, arc);
    drawText(canvas, 'i', c + Offset(-math.sin(i / 2) * 36 - 3, -math.cos(i / 2) * 36 - 6), bold: true);
    if (r != null) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: 26), math.pi / 2 - r, r, false, arc);
      drawText(canvas, 'r', c + Offset(math.sin(r / 2) * 36 - 3, math.cos(r / 2) * 36 - 6), bold: true);
    }
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final r = _refracted(s);
    return [
      ('Góc tới i', '${fmtNum(s['angle'])}°'),
      ('Góc khúc xạ r', r == null ? 'Không có (phản xạ toàn phần)' : '${fmtNum(r * 180 / math.pi)}°'),
      if (s['n1'] > s['n2']) ('Góc giới hạn', '${fmtNum(math.asin(s['n2'] / s['n1']) * 180 / math.pi)}°'),
      ('Định luật', 'n₁ sin i = n₂ sin r'),
    ];
  }
}

// ================= Thau kinh =================
class LensModel extends SimModel {
  const LensModel();

  @override
  bool get animated => false;

  ({double f, double? di, double? k}) _image(SimInput s) {
    final f = s.option == 'diverging' ? -s['f'] : s['f'];
    final d = s['d'];
    if ((d - f).abs() < 0.05) return (f: f, di: null, k: null);
    final di = d * f / (d - f);
    return (f: f, di: di, k: -di / d);
  }

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height, axis = h / 2, x0 = w / 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final img = _image(s);
    final scale = (w / 2 - 16) / math.max(math.max(s['d'], s['f'] * 1.3), 15);
    final ho = h * 0.22;
    canvas.drawLine(Offset(0, axis), Offset(w, axis), Paint()..color = const Color(0xFF9AA4AE)..strokeWidth = 1);
    // thau kinh
    final lensPaint = Paint()..color = const Color(0xFF2F6FDB)..strokeWidth = 2.5;
    final top = Offset(x0, axis - h * 0.42), bot = Offset(x0, axis + h * 0.42);
    canvas.drawLine(top, bot, lensPaint);
    final conv = s.option != 'diverging';
    for (final (p, dir) in [(top, -1.0), (bot, 1.0)]) {
      final tip = conv ? 1.0 : -1.0;
      canvas.drawLine(p, p + Offset(-7, -dir * 8 * tip), lensPaint);
      canvas.drawLine(p, p + Offset(7, -dir * 8 * tip), lensPaint);
    }
    final fpx = s['f'] * scale;
    for (final (x, label) in [(x0 - fpx, 'F'), (x0 + fpx, "F'")]) {
      canvas.drawCircle(Offset(x, axis), 3, Paint()..color = _ink);
      drawText(canvas, label, Offset(x - 4, axis + 6), size: 10, bold: true);
    }
    // vat
    final ox = x0 - s['d'] * scale;
    final objTop = Offset(ox, axis - ho);
    drawArrow(canvas, Offset(ox, axis), objTop, Paint()..color = const Color(0xFF1E8E5A)..strokeWidth = 3);
    drawText(canvas, 'Vật', objTop + const Offset(-10, -16), size: 10, bold: true);

    final ray = Paint()..color = const Color(0xFFE5392B)..strokeWidth = 1.6;
    final virtual = Paint()..color = const Color(0xFFE5392B).withValues(alpha: 0.55)..strokeWidth = 1.2;
    Offset extend(Offset a, Offset b, double toX) {
      final t = (toX - a.dx) / (b.dx - a.dx);
      return a + (b - a) * t;
    }

    // tia 1: song song truc -> qua F' (hoi tu) hoac nhu xuat phat tu F (phan ky)
    final hit = Offset(x0, objTop.dy);
    canvas.drawLine(objTop, hit, ray);
    final fPrime = Offset(x0 + img.f * scale, axis);
    final out1 = conv ? extend(hit, fPrime, w + 10) : extend(fPrime, hit, w + 10);
    canvas.drawLine(hit, out1, ray);
    // tia 2: qua quang tam di thang
    final center = Offset(x0, axis);
    canvas.drawLine(objTop, extend(objTop, center, w + 10), ray);

    if (img.di != null) {
      final ix = x0 + img.di! * scale;
      final iy = axis - ho * img.k!;
      final real = img.di! > 0;
      if (!real) {
        drawDashed(canvas, hit, Offset(ix, iy), virtual);
        drawDashed(canvas, center, Offset(ix, iy), virtual);
      }
      final p = Paint()..color = const Color(0xFF8E44AD)..strokeWidth = 3;
      if (real) {
        drawArrow(canvas, Offset(ix, axis), Offset(ix, iy), p);
      } else {
        drawDashed(canvas, Offset(ix, axis), Offset(ix, iy), p, dash: 4, gap: 3);
        drawArrow(canvas, Offset(ix, iy + (iy < axis ? 6 : -6)), Offset(ix, iy), p);
      }
      drawText(canvas, real ? 'Ảnh thật' : 'Ảnh ảo', Offset(ix - 18, iy < axis ? iy - 16 : iy + 4), size: 10, bold: true,
          color: const Color(0xFF8E44AD), background: Colors.white);
    }
    canvas.restore();
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final img = _image(s);
    if (img.di == null) return [('Ảnh', 'Ở vô cực (vật đặt tại tiêu điểm)'), ('Công thức', '1/f = 1/d + 1/d\'')];
    final real = img.di! > 0, k = img.k!;
    final kind = '${real ? 'Ảnh thật' : 'Ảnh ảo'}, ${k < 0 ? 'ngược chiều' : 'cùng chiều'}, ${k.abs() > 1 ? 'lớn hơn vật' : 'nhỏ hơn vật'}';
    return [
      ('Khoảng cách ảnh d\'', '${fmtNum(img.di!)} cm'),
      ('Độ phóng đại k', fmtNum(k)),
      ('Tính chất', kind),
      ('Công thức', '1/f = 1/d + 1/d\''),
    ];
  }
}
