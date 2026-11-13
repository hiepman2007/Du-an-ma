/// Tien ich hoa hoc chay tren may: doc cong thuc, tinh khoi luong mol, hien chi so duoi.
library;

const atomicMass = <String, double>{
  'H': 1.008, 'He': 4.003, 'Li': 6.94, 'Be': 9.012, 'B': 10.81, 'C': 12.011, 'N': 14.007, 'O': 15.999,
  'F': 18.998, 'Ne': 20.180, 'Na': 22.990, 'Mg': 24.305, 'Al': 26.982, 'Si': 28.085, 'P': 30.974,
  'S': 32.06, 'Cl': 35.45, 'Ar': 39.948, 'K': 39.098, 'Ca': 40.078, 'Sc': 44.956, 'Ti': 47.867,
  'V': 50.942, 'Cr': 51.996, 'Mn': 54.938, 'Fe': 55.845, 'Co': 58.933, 'Ni': 58.693, 'Cu': 63.546,
  'Zn': 65.38, 'Ga': 69.723, 'Ge': 72.630, 'As': 74.922, 'Se': 78.971, 'Br': 79.904, 'Kr': 83.798,
  'Rb': 85.468, 'Sr': 87.62, 'Y': 88.906, 'Zr': 91.224, 'Mo': 95.95, 'Ag': 107.868, 'Cd': 112.414,
  'Sn': 118.710, 'Sb': 121.760, 'I': 126.904, 'Xe': 131.293, 'Cs': 132.905, 'Ba': 137.327,
  'W': 183.84, 'Pt': 195.084, 'Au': 196.967, 'Hg': 200.592, 'Pb': 207.2, 'Bi': 208.980, 'U': 238.029,
};

const _sub = {'₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4', '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9'};
const _toSub = {'0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉'};

/// Doi chi so duoi Unicode ve so thuong.
String plainFormula(String f) => f.split('').map((c) => _sub[c] ?? c).join().replaceAll('.', '·').replaceAll(' ', '');

/// Hien chi so duoi: "H2SO4" -> "H₂SO₄", giu he so dau phuong trinh ("2H2O" -> "2H₂O").
String prettyFormula(String f) {
  final b = StringBuffer();
  var subscripting = false; // dang trong chuoi so dung sau nguyen to / dau ngoac
  for (var i = 0; i < f.length; i++) {
    final c = f[i];
    if (_toSub.containsKey(c)) {
      final prev = i > 0 ? f[i - 1] : ' ';
      if (subscripting || RegExp(r'[A-Za-z)\]]').hasMatch(prev)) {
        subscripting = true;
        b.write(_toSub[c]);
        continue;
      }
    }
    subscripting = false;
    b.write(c);
  }
  return b.toString();
}

/// Dem nguyen tu: ho tro ngoac (), [], hidrat "CuSO4·5H2O". Tra ve null neu khong doc duoc.
Map<String, int>? parseFormula(String input) {
  final f = plainFormula(input.trim());
  if (f.isEmpty) return null;
  final total = <String, int>{};
  for (final part in f.split('·')) {
    final m = RegExp(r'^(\d+)(.*)$').firstMatch(part);
    final coef = m == null ? 1 : int.parse(m.group(1)!);
    final body = m == null ? part : m.group(2)!;
    final counts = _parseGroup(body);
    if (counts == null) return null;
    counts.forEach((k, v) => total[k] = (total[k] ?? 0) + v * coef);
  }
  return total.isEmpty ? null : total;
}

Map<String, int>? _parseGroup(String s) {
  final stack = <Map<String, int>>[{}];
  var i = 0;
  int readNum() {
    final start = i;
    while (i < s.length && RegExp(r'\d').hasMatch(s[i])) {
      i++;
    }
    return start == i ? 1 : int.parse(s.substring(start, i));
  }

  while (i < s.length) {
    final c = s[i];
    if (c == '(' || c == '[') {
      stack.add({});
      i++;
    } else if (c == ')' || c == ']') {
      if (stack.length < 2) return null;
      i++;
      final n = readNum();
      final top = stack.removeLast();
      top.forEach((k, v) => stack.last[k] = (stack.last[k] ?? 0) + v * n);
    } else if (RegExp(r'[A-Z]').hasMatch(c)) {
      var el = c;
      i++;
      if (i < s.length && RegExp(r'[a-z]').hasMatch(s[i])) {
        el += s[i];
        i++;
      }
      if (!atomicMass.containsKey(el)) return null;
      final n = readNum();
      stack.last[el] = (stack.last[el] ?? 0) + n;
    } else {
      return null;
    }
  }
  return stack.length == 1 ? stack.first : null;
}

double? molarMass(String formula) {
  final counts = parseFormula(formula);
  if (counts == null) return null;
  return counts.entries.fold<double>(0, (s, e) => s + atomicMass[e.key]! * e.value);
}
