import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Chuyen dong co muc dich: xac nhan hanh dong, dan mat nguoi hoc; ton trong cai dat "giam chuyen dong" cua may.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

extension MotionX on Widget {
  /// Xuat hien lan luot (fade + truot len), tre theo thu tu [index].
  Widget enter(BuildContext context, {int index = 0, double dy = 0.08}) {
    if (reduceMotion(context)) return this;
    final delay = Duration(milliseconds: 40 * min(index, 10));
    return animate(delay: delay)
        .fadeIn(duration: 320.ms, curve: Curves.easeOutCubic)
        .slideY(begin: dy, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }
}

/// Nhan vao thi co nhe (phan hoi xuc giac thi giac), tha ra bat lai.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.scale = 0.97});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Vong tien do co hieu ung chay toi gia tri.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 52, this.stroke = 6, this.color = AppColors.primary, this.track, this.label});
  final double value;
  final double size, stroke;
  final Color color;
  final Color? track;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: stroke,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: track ?? color.withValues(alpha: 0.12),
            ),
          ),
          label ?? Text('${(v * 100).round()}%', style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }
}

/// Ba cham nhay "dang soan".
class TypingDots extends StatelessWidget {
  const TypingDots({super.key, this.color = AppColors.primary});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 3; i++)
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        )
            .animate(onPlay: (c) => c.repeat())
            .scaleXY(begin: 0.5, end: 1, delay: (i * 160).ms, duration: 380.ms, curve: Curves.easeInOut)
            .then()
            .scaleXY(begin: 1, end: 0.5, duration: 380.ms),
    ]);
  }
}

/// Qua cau AI phat sang (man cho AI soan bai).
class AiOrb extends StatelessWidget {
  const AiOrb({super.key, this.size = 120});
  final double size;
  @override
  Widget build(BuildContext context) {
    final orb = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [AppColors.primary, Color(0xFFFF7A59), Color(0xFFFFC371), AppColors.primary]),
        boxShadow: [BoxShadow(color: Color(0x55D01628), blurRadius: 40, spreadRadius: 6)],
      ),
      child: Center(
        child: Container(
          width: size * 0.72,
          height: size * 0.72,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome, size: size * 0.32, color: AppColors.primary),
        ),
      ),
    );
    if (reduceMotion(context)) return orb;
    return orb
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 0.94, end: 1.04, duration: 1100.ms, curve: Curves.easeInOut)
        .animate(onPlay: (c) => c.repeat())
        .rotate(duration: 6.seconds);
  }
}

/// Phao giay nho khi tra loi dung (ve bang CustomPainter, khong can thu vien).
class CelebrateBurst extends StatefulWidget {
  const CelebrateBurst({super.key, this.size = 160});
  final double size;
  @override
  State<CelebrateBurst> createState() => _CelebrateBurstState();
}

class _CelebrateBurstState extends State<CelebrateBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: _BurstPainter(_c.value))),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);
  final double t;
  static const _colors = [AppColors.primary, Color(0xFFFFC107), AppColors.success, Color(0xFF2B6CB0), Color(0xFFFF7A59)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final rnd = Random(11);
    final ease = Curves.easeOutCubic.transform(t);
    for (var i = 0; i < 22; i++) {
      final ang = 2 * pi * i / 22 + rnd.nextDouble() * 0.3;
      final dist = size.width * (0.18 + 0.32 * rnd.nextDouble()) * ease;
      final p = c + Offset(cos(ang) * dist, sin(ang) * dist + 30 * t * t);
      final paint = Paint()..color = _colors[i % _colors.length].withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(ang + t * 6);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -2, 8, 4), const Radius.circular(1.5)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}

/// Phan hoi dung/sai: dung -> rung nhe + bat len; sai -> rung manh + lac.
void answerHaptic(bool correct) {
  if (correct) {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.mediumImpact();
  }
}

extension FeedbackMotionX on Widget {
  Widget correctPop(BuildContext context) =>
      reduceMotion(context) ? this : animate().scaleXY(begin: 0.92, end: 1, duration: 360.ms, curve: Curves.elasticOut).fadeIn(duration: 160.ms);
  Widget wrongShake(BuildContext context) =>
      reduceMotion(context) ? this : animate().shakeX(hz: 5, amount: 6, duration: 420.ms).fadeIn(duration: 160.ms);
}

/// Nen gradient do dac trung (hero), co hai vong tron trang tri.
class HeroBackground extends StatelessWidget {
  const HeroBackground({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 22)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFD01628), Color(0xFFE8452F), Color(0xFFFF7A59)],
          ),
        ),
        child: Stack(children: [
          Positioned(right: -30, top: -40, child: _circle(140, 0.12)),
          Positioned(right: 40, bottom: -50, child: _circle(110, 0.08)),
          Positioned(left: -20, bottom: -30, child: _circle(70, 0.07)),
          Padding(padding: padding, child: child),
        ]),
      ),
    );
  }

  Widget _circle(double s, double a) =>
      Container(width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: a)));
}

/// Man cho AI: qua cau phat sang + cau trang thai doi luan phien (cho nguoi hoc biet AI dang lam gi).
class AiThinking extends StatefulWidget {
  const AiThinking({super.key, required this.messages, this.eyebrow = 'AI đang làm việc', this.hint = 'Thường mất 10–40 giây'});
  final List<String> messages;
  final String eyebrow, hint;
  @override
  State<AiThinking> createState() => _AiThinkingState();
}

class _AiThinkingState extends State<AiThinking> {
  int _i = 0;
  late final _timer = Stream.periodic(const Duration(milliseconds: 2600)).listen((_) {
    if (mounted && widget.messages.length > 1) setState(() => _i = (_i + 1) % widget.messages.length);
  });

  @override
  void initState() {
    super.initState();
    _timer;
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const AiOrb(size: 110),
      const SizedBox(height: 28),
      Eyebrow(widget.eyebrow),
      const SizedBox(height: 8),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a), child: child),
        ),
        child: Text(
          widget.messages[_i],
          key: ValueKey(_i),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: 10),
      const TypingDots(),
      const SizedBox(height: 10),
      Text(widget.hint, style: const TextStyle(color: AppColors.muted)),
    ]);
  }
}

/// Thanh tien do co hieu ung chay toi gia tri.
class AnimatedBar extends StatelessWidget {
  const AnimatedBar({super.key, required this.value, this.height = 8});
  final double value, height;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: height, borderRadius: BorderRadius.circular(height)),
      );
}
