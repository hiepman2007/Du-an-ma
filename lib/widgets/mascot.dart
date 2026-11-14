import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Bieu cam cua linh vat Cu Do.
enum MascotMood { idle, happy, thinking, cheer, sad }

/// Linh vat "Cu Do": cu meo ve bang code theo mau chu dao cua app, khong dung anh.
class Mascot extends StatelessWidget {
  const Mascot({super.key, this.size = 72, this.mood = MascotMood.idle});
  final double size;
  final MascotMood mood;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _OwlPainter(mood)),
      );
}

class _OwlPainter extends CustomPainter {
  _OwlPainter(this.mood);
  final MascotMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s);
    const red = AppColors.primary, dark = AppColors.primaryDark;
    final ink = Paint()..color = const Color(0xFF2B2525);
    // tai (chom long)
    canvas.drawPath(Path()..moveTo(22, 30)..lineTo(18, 6)..lineTo(40, 22)..close(), Paint()..color = dark);
    canvas.drawPath(Path()..moveTo(78, 30)..lineTo(82, 6)..lineTo(60, 22)..close(), Paint()..color = dark);
    // than
    canvas.drawOval(const Rect.fromLTWH(14, 14, 72, 80), Paint()..color = red);
    // canh
    canvas.save();
    canvas.translate(16, 58);
    canvas.rotate((mood == MascotMood.cheer ? -0.9 : 0.25));
    canvas.drawOval(const Rect.fromLTWH(-8, -14, 16, 32), Paint()..color = dark);
    canvas.restore();
    canvas.save();
    canvas.translate(84, 58);
    canvas.rotate((mood == MascotMood.cheer ? 0.9 : -0.25));
    canvas.drawOval(const Rect.fromLTWH(-8, -14, 16, 32), Paint()..color = dark);
    canvas.restore();
    // bung
    canvas.drawOval(const Rect.fromLTWH(30, 50, 40, 40), Paint()..color = const Color(0xFFFFE3E6));
    for (final (x, y) in [(42.0, 62.0), (50.0, 66.0), (58.0, 62.0), (46.0, 74.0), (54.0, 74.0)]) {
      canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: 7, height: 5), 0, math.pi, false,
          Paint()..color = const Color(0xFFF2A7B0)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    }
    // mat
    final white = Paint()..color = Colors.white;
    for (final cx in [36.0, 64.0]) {
      canvas.drawCircle(Offset(cx, 40), 14, white);
      canvas.drawCircle(Offset(cx, 40), 14, Paint()..color = dark..style = PaintingStyle.stroke..strokeWidth = 2);
      switch (mood) {
        case MascotMood.happy || MascotMood.cheer:
          canvas.drawArc(Rect.fromCenter(center: Offset(cx, 43), width: 14, height: 12), math.pi, math.pi, false,
              Paint()..color = const Color(0xFF2B2525)..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
        case MascotMood.thinking:
          canvas.drawCircle(Offset(cx + 4, 35), 6, ink);
          canvas.drawCircle(Offset(cx + 6, 33), 2, white);
        case MascotMood.sad:
          canvas.drawCircle(Offset(cx, 44), 6, ink);
          canvas.drawLine(Offset(cx - 9, 27 + (cx < 50 ? 4 : 0)), Offset(cx + 9, 27 + (cx < 50 ? 0 : 4)),
              Paint()..color = dark..strokeWidth = 2.5..strokeCap = StrokeCap.round);
        case MascotMood.idle:
          canvas.drawCircle(Offset(cx + 1, 41), 6.5, ink);
          canvas.drawCircle(Offset(cx + 3, 38.5), 2.2, white);
      }
    }
    // mo
    canvas.drawPath(Path()..moveTo(45, 50)..lineTo(55, 50)..lineTo(50, 60)..close(), Paint()..color = const Color(0xFFFFB020));
    // chan
    final foot = Paint()..color = const Color(0xFFFFB020)..strokeWidth = 3..strokeCap = StrokeCap.round;
    for (final x in [40.0, 60.0]) {
      canvas.drawLine(Offset(x, 92), Offset(x - 4, 98), foot);
      canvas.drawLine(Offset(x, 92), Offset(x, 99), foot);
      canvas.drawLine(Offset(x, 92), Offset(x + 4, 98), foot);
    }
    // mu tot nghiep nho khi khen
    if (mood == MascotMood.cheer) {
      canvas.drawPath(Path()..moveTo(30, 16)..lineTo(50, 6)..lineTo(70, 16)..lineTo(50, 24)..close(), ink);
      canvas.drawLine(const Offset(66, 15), const Offset(70, 28), Paint()..color = const Color(0xFFFFB020)..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _OwlPainter old) => old.mood != mood;
}

/// Linh vat noi mot cau (bong bong loi thoai), dung o trang chu, khi AI dang lam, ket qua quiz.
class MascotBubble extends StatelessWidget {
  const MascotBubble({super.key, required this.text, this.mood = MascotMood.idle, this.size = 64, this.action});
  final String text;
  final MascotMood mood;
  final double size;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Mascot(size: size, mood: mood),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: size * 0.3),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(text, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
              if (action != null) ...[const SizedBox(height: 6), action!],
            ]),
          ),
        ),
      ]);
}
