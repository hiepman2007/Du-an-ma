import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../services/expr.dart';
import '../../theme.dart';
import 'common.dart';

class _VarSlider extends StatelessWidget {
  const _VarSlider({required this.v, required this.value, required this.onChanged});
  final LabVar v;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final divisions = ((v.max - v.min) / v.step).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(v.label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text('${fmtNum(value)} ${v.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
      Slider(
        value: value.clamp(v.min, v.max),
        min: v.min,
        max: v.max,
        divisions: divisions > 0 && divisions <= 1000 ? divisions : null,
        onChanged: onChanged,
      ),
    ]);
  }
}

/// Phong thi nghiem cong thuc: keo thanh truot, ket qua tinh ngay tren may.
class FormulaLabBlock extends StatefulWidget {
  const FormulaLabBlock({super.key, required this.block});
  final Block block;
  @override
  State<FormulaLabBlock> createState() => _FormulaLabBlockState();
}

class _FormulaLabBlockState extends State<FormulaLabBlock> {
  late final Formula _f = Formula.parse(widget.block.lab!.formula);
  late final Map<String, double> _vals = {for (final v in widget.block.lab!.variables) v.name: v.defaultValue};

  @override
  Widget build(BuildContext context) {
    final lab = widget.block.lab!;
    final result = _f.eval(_vals);
    final cs = Theme.of(context).colorScheme;
    return BlockCard(
      icon: Icons.science_outlined,
      label: 'Phòng thí nghiệm',
      title: widget.block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.block.body?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(widget.block.body!)),
        for (final v in lab.variables)
          _VarSlider(v: v, value: _vals[v.name]!, onChanged: (x) => setState(() => _vals[v.name] = x)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Text(lab.resultLabel, style: TextStyle(color: cs.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(result == null ? '—' : '${fmtNum(result)} ${lab.resultUnit}',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text('${lab.resultLabel} = ${prettyExpr(lab.formula)}', style: TextStyle(fontSize: 13, color: cs.onPrimaryContainer)),
          ]),
        ),
        SourceNote(block: widget.block),
      ]),
    );
  }
}

/// Kham pha ham so: tham so keo duoc, ham phu de so sanh, tiep tuyen (dao ham), dien tich (tich phan), nghiem, cuc tri.
/// Moi tinh toan chay tren may.
class FunctionGraphBlock extends StatefulWidget {
  const FunctionGraphBlock({super.key, required this.block});
  final Block block;
  @override
  State<FunctionGraphBlock> createState() => _FunctionGraphBlockState();
}

class _FunctionGraphBlockState extends State<FunctionGraphBlock> {
  late final Graph _g = widget.block.graph!;
  late final Formula _f = Formula.parse(_g.expression);
  late final List<Formula> _extras = _g.extraExpressions.map(Formula.parse).where((f) => f.isValid).toList();
  late final Map<String, double> _params = {for (final p in _g.params) p.name: p.defaultValue};
  late double _x0 = _g.xMin + (_g.xMax - _g.xMin) * 0.6;
  late double _a = _g.xMin + (_g.xMax - _g.xMin) * 0.25;
  late double _b = _g.xMin + (_g.xMax - _g.xMin) * 0.75;
  late final Set<String> _on = {..._g.tools};

  static const _palette = [Color(0xFF2B6CB0), Color(0xFF2F855A)];

  double? _y(Formula f, double x) {
    final v = f.eval({..._params, 'x': x});
    return v != null && v.abs() < 1e6 ? v : null;
  }

  List<FlSpot> _curve(Formula f, double from, double to, [int n = 160]) {
    final out = <FlSpot>[];
    for (var i = 0; i <= n; i++) {
      final x = from + (to - from) * i / n;
      final y = _y(f, x);
      if (y != null) out.add(FlSpot(x, y));
    }
    return out;
  }

  double? _deriv(double x) {
    final h = (_g.xMax - _g.xMin) * 1e-4;
    final a = _y(_f, x + h), b = _y(_f, x - h);
    return a == null || b == null ? null : (a - b) / (2 * h);
  }

  double? _integral(double a, double b) {
    const n = 200; // Simpson, n chan
    final h = (b - a) / n;
    var s = 0.0;
    for (var i = 0; i <= n; i++) {
      final y = _y(_f, a + i * h);
      if (y == null) return null;
      s += y * (i == 0 || i == n ? 1 : (i.isOdd ? 4 : 2));
    }
    return s * h / 3;
  }

  /// Diem doi dau cua g tren khoang, tinh lai bang chia doi.
  List<double> _signChanges(double? Function(double) g) {
    const n = 400;
    final xs = <double>[];
    double? prevX, prevY;
    for (var i = 0; i <= n; i++) {
      final x = _g.xMin + (_g.xMax - _g.xMin) * i / n;
      final y = g(x);
      if (y == null) {
        prevY = null;
        continue;
      }
      if (y == 0) {
        xs.add(x);
      } else if (prevY != null && prevY != 0 && prevY.sign != y.sign) {
        var lo = prevX!, hi = x, ylo = prevY;
        for (var k = 0; k < 40; k++) {
          final mid = (lo + hi) / 2;
          final ym = g(mid);
          if (ym == null) break;
          if (ym.sign == ylo.sign) {
            lo = mid;
            ylo = ym;
          } else {
            hi = mid;
          }
        }
        xs.add((lo + hi) / 2);
      }
      prevX = x;
      prevY = y;
    }
    return xs.take(6).toList();
  }

  Widget _toolChip(String id, String label, IconData icon) {
    final on = _on.contains(id);
    return FilterChip(
      selected: on,
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onSelected: (v) => setState(() => v ? _on.add(id) : _on.remove(id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final main = _curve(_f, _g.xMin, _g.xMax);
    final bars = <LineChartBarData>[];
    final notes = <Widget>[];

    if (_on.contains('area') && _a < _b) {
      final area = _curve(_f, _a, _b, 80);
      bars.add(LineChartBarData(
        spots: area,
        color: Colors.transparent,
        barWidth: 0,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.18), cutOffY: 0, applyCutOffY: true),
        aboveBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.18), cutOffY: 0, applyCutOffY: true),
      ));
      final s = _integral(_a, _b);
      notes.add(Text('∫ từ ${fmtNum(_a)} đến ${fmtNum(_b)} f(x) dx ≈ ${s == null ? '—' : fmtNum(s)}',
          style: const TextStyle(fontWeight: FontWeight.w700)));
    }
    bars.add(LineChartBarData(spots: main, color: AppColors.primary, barWidth: 3, dotData: const FlDotData(show: false)));
    for (var i = 0; i < _extras.length; i++) {
      bars.add(LineChartBarData(
        spots: _curve(_extras[i], _g.xMin, _g.xMax),
        color: _palette[i % _palette.length],
        barWidth: 2,
        dashArray: [6, 4],
        dotData: const FlDotData(show: false),
      ));
    }
    if (_on.contains('tangent')) {
      final y0 = _y(_f, _x0), k = _deriv(_x0);
      if (y0 != null && k != null) {
        bars.add(LineChartBarData(
          spots: [FlSpot(_g.xMin, y0 + k * (_g.xMin - _x0)), FlSpot(_g.xMax, y0 + k * (_g.xMax - _x0))],
          color: const Color(0xFF2B2525),
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ));
        bars.add(LineChartBarData(spots: [FlSpot(_x0, y0)], barWidth: 0, dotData: const FlDotData(show: true)));
        notes.add(Text("Tại x = ${fmtNum(_x0)}: f(x) = ${fmtNum(y0)}, f'(x) ≈ ${fmtNum(k)} (hệ số góc tiếp tuyến)",
            style: const TextStyle(fontWeight: FontWeight.w700)));
      }
    }
    if (_on.contains('roots')) {
      final roots = _signChanges((x) => _y(_f, x));
      if (roots.isNotEmpty) bars.add(LineChartBarData(spots: [for (final r in roots) FlSpot(r, 0)], barWidth: 0, color: Colors.transparent, dotData: const FlDotData(show: true)));
      notes.add(Text(roots.isEmpty ? 'Không có nghiệm trong khoảng đang xem' : 'Nghiệm: x ≈ ${roots.map(fmtNum).join('; ')}'));
    }
    if (_on.contains('extrema')) {
      final xs = _signChanges(_deriv);
      final pts = [for (final x in xs) if (_y(_f, x) != null) FlSpot(x, _y(_f, x)!)];
      if (pts.isNotEmpty) bars.add(LineChartBarData(spots: pts, barWidth: 0, color: Colors.transparent, dotData: const FlDotData(show: true)));
      notes.add(Text(pts.isEmpty ? 'Không có cực trị trong khoảng đang xem' : 'Cực trị tại: ${pts.map((p) => '(${fmtNum(p.x)}; ${fmtNum(p.y)})').join(', ')}'));
    }

    return BlockCard(
      icon: Icons.show_chart,
      label: 'Khám phá hàm số',
      title: widget.block.title,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (widget.block.body?.isNotEmpty == true) Text(widget.block.body!),
        const SizedBox(height: 8),
        Text('y = ${prettyExpr(_g.expression)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
        for (var i = 0; i < _extras.length; i++)
          Text('y = ${prettyExpr(_g.extraExpressions[i])}', style: TextStyle(fontWeight: FontWeight.w600, color: _palette[i % _palette.length])),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.3,
          child: main.length < 2
              ? const Center(child: Text('Không vẽ được đồ thị với tham số này'))
              : LineChart(LineChartData(
                  minX: _g.xMin,
                  maxX: _g.xMax,
                  clipData: const FlClipData.all(),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: true, border: Border.all(color: cs.outlineVariant)),
                  titlesData: const FlTitlesData(
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: const LineTouchData(enabled: false),
                  lineBarsData: bars,
                )),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _toolChip('tangent', 'Tiếp tuyến', Icons.call_made),
          _toolChip('area', 'Diện tích', Icons.area_chart_outlined),
          _toolChip('roots', 'Nghiệm', Icons.adjust),
          _toolChip('extrema', 'Cực trị', Icons.terrain_outlined),
        ]),
        const SizedBox(height: 6),
        ...notes,
        if (_on.contains('tangent'))
          _VarSlider(
            v: LabVar(name: 'x0', label: 'Điểm tiếp xúc x₀', unit: '', min: _g.xMin, max: _g.xMax, step: (_g.xMax - _g.xMin) / 200, defaultValue: _x0),
            value: _x0,
            onChanged: (v) => setState(() => _x0 = v),
          ),
        if (_on.contains('area')) ...[
          _VarSlider(
            v: LabVar(name: 'a', label: 'Cận dưới a', unit: '', min: _g.xMin, max: _g.xMax, step: (_g.xMax - _g.xMin) / 200, defaultValue: _a),
            value: _a,
            onChanged: (v) => setState(() => _a = v),
          ),
          _VarSlider(
            v: LabVar(name: 'b', label: 'Cận trên b', unit: '', min: _g.xMin, max: _g.xMax, step: (_g.xMax - _g.xMin) / 200, defaultValue: _b),
            value: _b,
            onChanged: (v) => setState(() => _b = v),
          ),
        ],
        for (final p in _g.params) _VarSlider(v: p, value: _params[p.name]!, onChanged: (x) => setState(() => _params[p.name] = x)),
        SourceNote(block: widget.block),
      ]),
    );
  }
}
