import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../services/expr.dart';
import 'sim_core.dart';

const _ink = Color(0xFF2B2525);
const _red = Color(0xFFD01628);

// ================= Chuan do axit - bazo =================
/// Axit manh (HCl, nong do Ca, the tich Va) chuan do bang bazo manh (NaOH, Cb).
/// Bien Vb la phan tram cua 2 lan the tich tuong duong, nen moi bo thong so deu thay du duong cong.
class TitrationModel extends SimModel {
  const TitrationModel();

  double _veq(SimInput s) => s['Ca'] * s['Va'] / math.max(0.001, s['Cb']);
  double _vmax(SimInput s) => 2 * _veq(s);
  double _vb(SimInput s) => s['Vb'] / 100 * _vmax(s);

  double _ph(SimInput s, double vb) {
    final na = s['Ca'] * s['Va'], nb = s['Cb'] * vb, vt = s['Va'] + vb;
    if ((na - nb).abs() < 1e-9) return 7;
    final ph = na > nb ? -math.log((na - nb) / vt) / math.ln10 : 14 + math.log((nb - na) / vt) / math.ln10;
    return ph.clamp(0, 14).toDouble();
  }

  static Color indicator(String? option, double ph) {
    switch (option) {
      case 'methyl_orange':
        return ph < 3.1 ? const Color(0xFFE53935) : ph > 4.4 ? const Color(0xFFFDD835) : mix(const Color(0xFFE53935), const Color(0xFFFDD835), (ph - 3.1) / 1.3);
      case 'litmus':
        return ph < 5 ? const Color(0xFFE53935) : ph > 8 ? const Color(0xFF3949AB) : mix(const Color(0xFF8E24AA), const Color(0xFF7E57C2), (ph - 5) / 3);
      default: // phenolphthalein
        return ph < 8.2 ? const Color(0xFFF4F7FB) : mix(const Color(0xFFF8BBD0), const Color(0xFFD81B60), (ph - 8.2) / 1.8);
    }
  }

  static String indicatorName(String? option) =>
      switch (option) { 'methyl_orange' => 'Metyl da cam', 'litmus' => 'Quỳ tím', _ => 'Phenolphtalein' };

  @override
  bool advance(Map<String, double> v, double dt) {
    v['Vb'] = math.min(100, (v['Vb'] ?? 0) + dt * 10);
    return v['Vb']! < 100;
  }

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height;
    final vb = _vb(s), ph = _ph(s, vb);
    // buret
    final bx = w * 0.2, btop = 8.0, bbot = h * 0.46;
    final level = (s['Vb'] / 100).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTRB(bx - 6, btop + (bbot - btop) * level, bx + 6, bbot), Paint()..color = const Color(0xFFDDEBFA));
    canvas.drawRect(Rect.fromLTRB(bx - 6, btop, bx + 6, bbot), Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawLine(Offset(bx, bbot), Offset(bx, bbot + 10), Paint()..color = _ink..strokeWidth = 2);
    canvas.drawRect(Rect.fromCenter(center: Offset(bx, bbot + 4), width: 16, height: 5), Paint()..color = const Color(0xFF6B7178));
    drawText(canvas, 'NaOH ${fmtNum(s['Cb'])}M', Offset(bx + 10, btop + 2), size: 9, bold: true);
    // giot roi
    final flaskTop = h * 0.6;
    if (s.t > 0 && s['Vb'] < 100) {
      final fall = (s.t * 2.5) % 1;
      canvas.drawCircle(Offset(bx, bbot + 12 + fall * (flaskTop - bbot - 6)), 3, Paint()..color = const Color(0xFF90B8E8));
    }
    // binh tam giac
    final neckL = bx - 9, neckR = bx + 9, baseL = w * 0.04, baseR = w * 0.36, base = h - 8;
    final liquidTop = base - (base - flaskTop) * (0.45 + 0.35 * level);
    final flask = Path()
      ..moveTo(neckL, flaskTop - 18)
      ..lineTo(neckL, flaskTop)
      ..lineTo(baseL, base)
      ..lineTo(baseR, base)
      ..lineTo(neckR, flaskTop)
      ..lineTo(neckR, flaskTop - 18);
    canvas.save();
    canvas.clipPath(Path()..addPath(flask, Offset.zero)..close());
    canvas.drawRect(Rect.fromLTRB(0, liquidTop, w * 0.4, base), Paint()..color = indicator(s.option, ph));
    canvas.restore();
    canvas.drawPath(flask, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2);
    drawText(canvas, 'HCl ${fmtNum(s['Ca'])}M', Offset((baseL + baseR) / 2, base - 12), center: true, size: 9, bold: true);

    // duong cong pH
    final plot = Rect.fromLTRB(w * 0.5, 10, w - 8, h - 22);
    final axis = Paint()..color = const Color(0xFF9AA4AE)..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axis);
    drawText(canvas, 'pH', plot.topLeft + const Offset(4, 0), size: 10, bold: true);
    drawText(canvas, 'V NaOH', plot.bottomRight + const Offset(-40, 4), size: 9);
    double py(double p) => plot.bottom - plot.height * p / 14;
    drawDashed(canvas, Offset(plot.left, py(7)), Offset(plot.right, py(7)), Paint()..color = const Color(0xFFCCD2D8)..strokeWidth = 1);
    drawText(canvas, '7', Offset(plot.left - 10, py(7) - 6), size: 9);
    final vmax = _vmax(s);
    final curve = Path();
    for (var i = 0; i <= 160; i++) {
      final v = vmax * i / 160;
      final p = Offset(plot.left + plot.width * i / 160, py(_ph(s, v)));
      i == 0 ? curve.moveTo(p.dx, p.dy) : curve.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(curve, Paint()..color = const Color(0xFFB8C4D2)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    final done = Path();
    for (var i = 0; i <= 160 * level; i++) {
      final v = vmax * i / 160;
      final p = Offset(plot.left + plot.width * i / 160, py(_ph(s, v)));
      i == 0 ? done.moveTo(p.dx, p.dy) : done.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(done, Paint()..color = _red..strokeWidth = 2.5..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset(plot.left + plot.width * level, py(ph)), 4.5, Paint()..color = _red);
    final eqX = plot.left + plot.width / 2;
    drawDashed(canvas, Offset(eqX, plot.top), Offset(eqX, plot.bottom), Paint()..color = const Color(0xFFCCD2D8)..strokeWidth = 1);
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final vb = _vb(s), ph = _ph(s, vb);
    return [
      ('pH dung dịch', fmtNum(ph)),
      ('V NaOH đã nhỏ', '${fmtNum(vb)} mL'),
      ('V tương đương', '${fmtNum(_veq(s))} mL'),
      ('Chỉ thị', indicatorName(s.option)),
    ];
  }
}

// ================= Chuyen the =================
class StatesModel extends SimModel {
  const StatesModel();

  (double, double, String) _points(String? option) => option == 'ethanol' ? (-114.0, 78.0, 'Etanol') : (0.0, 100.0, 'Nước');

  String _state(SimInput s) {
    final (mp, bp, _) = _points(s.option);
    return s['T'] < mp ? 'Rắn' : s['T'] < bp ? 'Lỏng' : 'Khí';
  }

  @override
  void paint(Canvas canvas, Size size, SimInput s) {
    final w = size.width, h = size.height;
    final (mp, bp, _) = _points(s.option);
    final t = s['T'];
    final box = Rect.fromLTWH(12, 12, w * 0.62, h - 24);
    canvas.drawRect(box, Paint()..color = const Color(0xFFF4F8FC));
    canvas.drawRect(box, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2);
    final rnd = math.Random(3);
    final state = _state(s);
    final heat = ((t - mp + 60) / (bp - mp + 120)).clamp(0.0, 1.0);
    final dot = Paint()..color = mix(const Color(0xFF2F6FDB), _red, heat);
    const n = 36;
    for (var i = 0; i < n; i++) {
      final r1 = rnd.nextDouble(), r2 = rnd.nextDouble(), ang = rnd.nextDouble() * 2 * math.pi;
      Offset p;
      if (state == 'Rắn') {
        const cols = 6, gap = 17.0;
        final ox = box.center.dx - gap * (cols - 1) / 2, oy = box.bottom - 12 - gap * 5;
        final amp = 0.6 + 2.6 * ((t - (mp - 120)) / 120).clamp(0.0, 1.0);
        p = Offset(ox + (i % cols) * gap + amp * math.sin(s.t * 22 + i), oy + (i ~/ cols) * gap + amp * math.cos(s.t * 19 + i * 1.7));
      } else if (state == 'Lỏng') {
        final zone = Rect.fromLTRB(box.left + 6, box.bottom - box.height * 0.45, box.right - 6, box.bottom - 6);
        final sp = 18 + 30 * ((t - mp) / (bp - mp)).clamp(0.0, 1.0);
        p = Offset(zone.left + bounce(r1 * zone.width + math.cos(ang) * sp * s.t, zone.width),
            zone.top + bounce(r2 * zone.height + math.sin(ang) * sp * s.t, zone.height));
        if (i == 0) canvas.drawRect(zone.inflate(4), Paint()..color = const Color(0x332F6FDB));
      } else {
        final zone = box.deflate(6);
        final sp = 110 * math.sqrt((t + 273) / 373);
        p = Offset(zone.left + bounce(r1 * zone.width + math.cos(ang) * sp * s.t, zone.width),
            zone.top + bounce(r2 * zone.height + math.sin(ang) * sp * s.t, zone.height));
      }
      canvas.drawCircle(p, 6, dot);
    }
    // nhiet ke
    final tx = w * 0.84, tTop = 16.0, tBot = h - 30;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(tx - 6, tTop, tx + 6, tBot), const Radius.circular(6)), Paint()..color = Colors.white);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(tx - 6, tTop, tx + 6, tBot), const Radius.circular(6)),
        Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 1.5);
    const tMin = -150.0, tMax = 200.0;
    double ty(double v) => tBot - (tBot - tTop) * ((v - tMin) / (tMax - tMin)).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTRB(tx - 3, ty(t), tx + 3, tBot), Paint()..color = _red);
    canvas.drawCircle(Offset(tx, tBot + 6), 9, Paint()..color = _red);
    for (final (v, label) in [(mp, 'nóng chảy'), (bp, 'sôi')]) {
      canvas.drawLine(Offset(tx - 10, ty(v)), Offset(tx + 10, ty(v)), Paint()..color = _ink..strokeWidth = 1);
      drawText(canvas, '${fmtNum(v)}°', Offset(tx + 12, ty(v) - 6), size: 9, bold: true);
      drawText(canvas, label, Offset(tx - 58, ty(v) - 6), size: 8);
    }
    drawText(canvas, state, Offset(box.center.dx, box.top + 12), center: true, bold: true, size: 13, background: Colors.white);
  }

  @override
  List<(String, String)> readouts(SimInput s) {
    final (mp, bp, name) = _points(s.option);
    return [
      ('Chất', name),
      ('Nhiệt độ', '${fmtNum(s['T'])} °C'),
      ('Trạng thái', _state(s)),
      ('Nóng chảy / sôi', '${fmtNum(mp)} °C / ${fmtNum(bp)} °C'),
    ];
  }
}
