import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

/// Bieu thuc toan do AI sinh (da kiem tra o server). Tinh hoan toan tren may, khong goi AI.
class Formula {
  Formula._(this._exp);
  final Expression? _exp;

  static final _parser = GrammarParser();

  factory Formula.parse(String source) {
    try {
      return Formula._(_parser.parse(source));
    } catch (_) {
      return Formula._(null);
    }
  }

  bool get isValid => _exp != null;

  /// Tra ve null neu khong tinh duoc (chia cho 0, sai cu phap...).
  double? eval(Map<String, double> vars) {
    final exp = _exp;
    if (exp == null) return null;
    try {
      final cm = ContextModel()
        ..bindVariableName('pi', Number(math.pi))
        ..bindVariableName('e', Number(math.e));
      vars.forEach((k, v) => cm.bindVariableName(k, Number(v)));
      final v = RealEvaluator(cm).evaluate(exp).toDouble();
      return v.isFinite ? v : null;
    } catch (_) {
      return null;
    }
  }
}

String fmtNum(double v) {
  if (v.abs() >= 1e6 || (v != 0 && v.abs() < 1e-3)) return v.toStringAsExponential(2);
  final s = v.toStringAsFixed(v.abs() >= 100 ? 1 : 2);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}

const _sup = {'0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹'};

/// Hien bieu thuc de doc: "a*x^2+b*x" -> "a·x² + b·x".
String prettyExpr(String e) => e
    .replaceAllMapped(RegExp(r'\^(\d+)'), (m) => m.group(1)!.split('').map((c) => _sup[c] ?? c).join())
    .replaceAll('*', '·')
    .replaceAllMapped(RegExp(r'(?<=[\w)²³])([+\-])(?=[\w(])'), (m) => ' ${m.group(1)} ');

/// Doi bieu thuc may ("a*x^2+b*x+c", "U/R", "sqrt(2*g*h)") sang TeX de hien dep.
/// Chi xu ly cac dang don gian; truong hop khac van doc duoc.
String exprToTex(String e) {
  var s = e.replaceAll(' ', '');
  // sqrt(...) khong long nhau
  s = s.replaceAllMapped(RegExp(r'sqrt\(([^()]*)\)'), (m) => r'\sqrt{' '${m.group(1)}}');
  // a/b voi a, b la ten bien / so / can
  s = s.replaceAllMapped(RegExp(r'([A-Za-z0-9_.]+|\\sqrt\{[^}]*\})/([A-Za-z0-9_.]+|\\sqrt\{[^}]*\})'),
      (m) => r'\frac{' '${m.group(1)}}{${m.group(2)}}');
  // luy thua
  s = s.replaceAllMapped(RegExp(r'\^\(([^()]*)\)'), (m) => '^{${m.group(1)}}');
  s = s.replaceAllMapped(RegExp(r'\^([A-Za-z0-9.]+)'), (m) => '^{${m.group(1)}}');
  // nhan: giua hai so dung \cdot, con lai viet lien
  s = s.replaceAllMapped(RegExp(r'(\d)\*(\d)'), (m) => '${m.group(1)} ' r'\cdot ' '${m.group(2)}');
  s = s.replaceAll('*', ' ');
  for (final f in ['sin', 'cos', 'tan', 'ln', 'log', 'exp']) {
    s = s.replaceAll(RegExp(r'(?<!\\)\b' '$f' r'\('), '\\$f(');
  }
  return s.replaceAll(RegExp(r'\bpi\b'), r'\pi ');
}
