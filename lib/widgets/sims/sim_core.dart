import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';

/// Dau vao mot khung hinh mo phong: gia tri thanh truot, lua chon (vd noi tiep/song song) va thoi gian.
class SimInput {
  const SimInput(this.v, this.option, this.t);
  final Map<String, double> v;
  final String? option;
  final double t;
  double operator [](String name) => v[name] ?? 0;
}

/// Bo may mot canh: ve len canvas tu dau vao (khong giu trang thai), tinh so do hien thi.
abstract class SimModel {
  const SimModel();
  void paint(Canvas canvas, Size size, SimInput input);
  List<(String, String)> readouts(SimInput input);

  /// Canh co hoat hinh theo thoi gian (hien nut Chay/Dung).
  bool get animated => true;

  /// Thoi gian chay roi tu dung; null = chay lien tuc den khi bam Dung.
  double? duration(SimInput input) => null;

  /// Cap nhat bien khi dang chay (vd chuan do tu nho giot). Tra false de dung.
  bool advance(Map<String, double> v, double dt) => true;
}

class SimScene {
  const SimScene({
    required this.id,
    required this.title,
    required this.subject,
    required this.icon,
    required this.summary,
    required this.vars,
    required this.model,
    this.options = const [],
    this.challenges = const [],
    this.aspect = 1.5,
  });
  final String id, title, subject, summary;
  final IconData icon;
  final List<LabVar> vars;
  final List<(String, String)> options; // (id, nhan)
  final List<String> challenges;
  final SimModel model;
  final double aspect;
}

LabVar simVar(String name, String label, String unit, double min, double max, double def, [double? step]) =>
    LabVar(name: name, label: label, unit: unit, min: min, max: max, step: step ?? (max - min) / 100, defaultValue: def);

// ---- tien ich ve ----

void drawText(Canvas canvas, String text, Offset at,
    {Color color = const Color(0xFF2B2525), double size = 11, bool bold = false, bool center = false, Color? background}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
    textDirection: TextDirection.ltr,
  )..layout();
  final pos = center ? at - Offset(tp.width / 2, tp.height / 2) : at;
  if (background != null) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx - 3, pos.dy - 1, tp.width + 6, tp.height + 2), const Radius.circular(4)),
        Paint()..color = background);
  }
  tp.paint(canvas, pos);
}

void drawArrow(Canvas canvas, Offset from, Offset to, Paint paint, {double head = 7}) {
  canvas.drawLine(from, to, paint);
  final d = to - from;
  if (d.distance < 1) return;
  final a = math.atan2(d.dy, d.dx);
  final p = Path()
    ..moveTo(to.dx, to.dy)
    ..lineTo(to.dx - head * math.cos(a - 0.45), to.dy - head * math.sin(a - 0.45))
    ..lineTo(to.dx - head * math.cos(a + 0.45), to.dy - head * math.sin(a + 0.45))
    ..close();
  canvas.drawPath(p, Paint()..color = paint.color);
}

void drawDashed(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 5, double gap = 4}) {
  final d = b - a;
  final len = d.distance;
  if (len < 1) return;
  final u = d / len;
  for (double s = 0; s < len; s += dash + gap) {
    canvas.drawLine(a + u * s, a + u * math.min(s + dash, len), paint);
  }
}

/// Cham tron chay doc duong dan (dong dien, tia sang...). [phase] tinh bang px.
void drawFlow(Canvas canvas, Path path, double phase, Paint paint, {double spacing = 18, double radius = 2.6}) {
  for (final m in path.computeMetrics()) {
    for (double s = phase % spacing; s < m.length; s += spacing) {
      final tan = m.getTangentForOffset(s);
      if (tan != null) canvas.drawCircle(tan.position, radius, paint);
    }
  }
}

/// Gia tri p di chuyen tu do va bat lai trong doan [0, len].
double bounce(double p, double len) {
  if (len <= 0) return 0;
  final m = p % (2 * len);
  return len - (m - len).abs();
}

Color mix(Color a, Color b, double t) => Color.lerp(a, b, t.clamp(0, 1).toDouble())!;

ui.Gradient vertical(Rect r, Color top, Color bottom) => ui.Gradient.linear(r.topCenter, r.bottomCenter, [top, bottom]);
