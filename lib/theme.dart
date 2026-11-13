import 'package:material_ui/material_ui.dart';

/// Phong cach theo thinklogic.vn: do chu dao, nen xam nhat, the trang vien manh, nhan in hoa mau do.
class AppColors {
  static const primary = Color(0xFFD01628);
  static const primaryDark = Color(0xFFA2111F);
  static const accent = Color(0xFFFFF1F0); // nen nhat mau do
  static const background = Color(0xFFF7F7F7);
  static const foreground = Color(0xFF262626);
  static const muted = Color(0xFF8C8C8C);
  static const border = Color(0xFFD9D9D9);
  static const ink = Color(0xFF2B2525); // the noi bat nen toi
  static const success = Color(0xFF1E8E3E);
  static const danger = Color(0xFFD93025);
}

const appRadius = 14.0;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.accent,
    onPrimaryContainer: AppColors.primaryDark,
    secondaryContainer: const Color(0xFFF5F5F5),
    onSecondaryContainer: AppColors.foreground,
    tertiaryContainer: AppColors.ink,
    onTertiaryContainer: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.foreground,
    surfaceContainerLow: Colors.white,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(appRadius),
    side: const BorderSide(color: AppColors.border, width: 0.8),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.foreground,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(color: AppColors.foreground, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: shape, margin: EdgeInsets.zero),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        foregroundColor: AppColors.foreground,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.accent,
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary, linearTrackColor: Color(0xFFF0F0F0)),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 0.8),
    // Chuyen trang muot: mo dan + truot nhe (Android).
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Nhan nho in hoa mau do phia tren tieu de (kieu "PHONG LUYEN THINKLOGIC").
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = AppColors.primary});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1.1));
}

/// Nhan + tieu de dam.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.eyebrow, required this.title, this.trailing});
  final String eyebrow, title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Eyebrow(eyebrow),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.foreground)),
            ]),
          ),
          ?trailing,
        ]),
      );
}

/// O so do kieu "01", "02".
class NumberTile extends StatelessWidget {
  const NumberTile(this.n, {super.key, this.done = false});
  final int n;
  final bool done;
  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: done ? AppColors.primary : AppColors.accent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: done
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(n.toString().padLeft(2, '0'),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
      );
}

/// The noi bat nen toi + nut do (kieu "30 de - mot nhip luyen ro rang").
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.eyebrow, required this.title, required this.subtitle, required this.action, required this.onTap});
  final String eyebrow, title, subtitle, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(appRadius)),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(eyebrow, color: const Color(0xFFFF8A94)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFFD6D6D6))),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onTap,
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action), const SizedBox(width: 6), const Icon(Icons.arrow_forward, size: 18)]),
          ),
        ]),
      );
}
