import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../services/expr.dart';
import '../../theme.dart';
import 'sim_catalog.dart';
import 'sim_core.dart';

/// Mot canh mo phong chay that: canvas + nut Chay/Dung + so do + thanh truot + thu thach.
/// [overrides] la bien AI dieu chinh (cung ten bien trong danh muc), [challenges] thay cau thu thach mac dinh.
class PhenomenonSim extends StatefulWidget {
  const PhenomenonSim({
    super.key,
    required this.scene,
    this.option,
    this.overrides = const [],
    this.challenges = const [],
    this.onAsk,
    this.autoplay = false,
  });

  final SimScene scene;
  final String? option;
  final List<LabVar> overrides;
  final List<String> challenges;
  final ValueChanged<String>? onAsk;
  final bool autoplay;

  @override
  State<PhenomenonSim> createState() => _PhenomenonSimState();
}

class _PhenomenonSimState extends State<PhenomenonSim> with SingleTickerProviderStateMixin {
  late final List<LabVar> _vars = [
    for (final v in widget.scene.vars)
      widget.overrides.where((o) => o.name == v.name).map((o) => LabVar(
            name: v.name,
            label: o.label.isEmpty || o.label == o.name ? v.label : o.label,
            unit: o.unit.isEmpty ? v.unit : o.unit,
            min: o.min,
            max: o.max,
            step: o.step,
            defaultValue: o.defaultValue,
          )).firstOrNull ?? v,
  ];
  late final Map<String, double> _v = {for (final x in _vars) x.name: x.defaultValue};
  late String? _option = widget.scene.options.any((o) => o.$1 == widget.option) ? widget.option : widget.scene.options.firstOrNull?.$1;
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _t = 0;
  bool _running = false;
  final _tried = <int>{};

  SimInput get _input => SimInput(_v, _option, _t);

  @override
  void initState() {
    super.initState();
    if (widget.autoplay && widget.scene.model.animated) _play();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    setState(() {
      _t += dt;
      final keep = widget.scene.model.advance(_v, dt);
      final end = widget.scene.model.duration(_input);
      if (!keep || (end != null && _t >= end)) _stop();
    });
  }

  void _play() {
    final end = widget.scene.model.duration(_input);
    if (end != null && _t >= end) _t = 0;
    if (widget.scene.id == 'titration' && (_v['Vb'] ?? 0) >= 100) _v['Vb'] = 0;
    _last = Duration.zero;
    _running = true;
    _ticker.start();
  }

  void _stop() {
    _ticker.stop();
    _running = false;
  }

  void _reset() => setState(() {
        _stop();
        _t = 0;
        for (final x in _vars) {
          _v[x.name] = x.defaultValue;
        }
      });

  @override
  Widget build(BuildContext context) {
    final scene = widget.scene;
    final challenges = widget.challenges.isNotEmpty ? widget.challenges : scene.challenges;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: scene.aspect,
          child: Stack(children: [
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFFBFCFE),
                child: CustomPaint(painter: _ScenePainter(scene.model, _input)),
              ),
            ),
            if (scene.model.animated)
              Positioned(
                right: 8,
                bottom: 8,
                child: Row(children: [
                  _RoundButton(icon: Icons.restart_alt, tooltip: 'Đặt lại', onTap: _reset),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: _running ? Icons.pause : Icons.play_arrow,
                    tooltip: _running ? 'Dừng' : 'Chạy',
                    filled: true,
                    onTap: () => setState(() => _running ? _stop() : _play()),
                  ),
                ]),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (label, value) in scene.model.readouts(_input))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
            child: Text.rich(TextSpan(children: [
              TextSpan(text: '$label: ', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ])),
          ),
      ]),
      if (scene.options.length > 1) ...[
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [for (final (id, label) in scene.options) ButtonSegment(value: id, label: Text(label))],
            selected: {_option!},
            onSelectionChanged: (s) => setState(() => _option = s.first),
          ),
        ),
      ],
      const SizedBox(height: 6),
      for (final x in _vars)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(x.label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text('${fmtNum(_v[x.name]!)} ${x.unit}'.trim(), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          Slider(
            key: ValueKey('sim-${scene.id}-${x.name}'),
            value: _v[x.name]!.clamp(x.min, x.max),
            min: x.min,
            max: x.max,
            onChanged: (val) => setState(() => _v[x.name] = val),
          ),
        ]),
      if (challenges.isNotEmpty) ...[
        const SizedBox(height: 4),
        const Text('Thử thách', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        for (final (i, c) in challenges.indexed)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _tried.contains(i) ? _tried.remove(i) : _tried.add(i)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_tried.contains(i) ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20, color: _tried.contains(i) ? AppColors.success : AppColors.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(c)),
              ]),
            ),
          ),
      ],
      if (widget.onAsk != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => widget.onAsk!(_question()),
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Hỏi gia sư về hiện tượng này'),
          ),
        ),
    ]);
  }

  String _question() {
    final values = _vars.map((x) => '${x.label} ${fmtNum(_v[x.name]!)} ${x.unit}'.trim()).join(', ');
    final opt = widget.scene.options.where((o) => o.$1 == _option).map((o) => ' (${o.$2})').firstOrNull ?? '';
    return 'Giải thích giúp mình hiện tượng trong mô phỏng "${widget.scene.title}"$opt với $values.';
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.model, this.input);
  final SimModel model;
  final SimInput input;

  @override
  void paint(Canvas canvas, Size size) => model.paint(canvas, size, input);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onTap, this.filled = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: filled ? AppColors.primary : Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: filled ? Colors.white : AppColors.foreground, size: 24),
            ),
          ),
        ),
      );
}

/// Dung canh tu khoi AI (phenomenon_sim). Tra null neu canh khong co trong danh muc.
PhenomenonSim? simFromBlock(Block block, {ValueChanged<String>? onAsk}) {
  final cfg = block.rawMap('phenomenon');
  final scene = simCatalog['${cfg?['scene']}'];
  if (cfg == null || scene == null) return null;
  return PhenomenonSim(
    scene: scene,
    option: cfg['option'] as String?,
    overrides: [for (final v in (cfg['variables'] as List? ?? []).whereType<Map>()) LabVar.fromJson(Map<String, dynamic>.from(v))],
    challenges: [for (final c in (cfg['challenges'] as List? ?? [])) '$c'],
    onAsk: onAsk,
  );
}
