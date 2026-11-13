import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../blocks/common.dart';
import '../rich_content.dart';
import 'dsa_simulation.dart';

class DsaSimulationBlock extends StatelessWidget {
  const DsaSimulationBlock({super.key, required this.block});

  final Block block;

  @override
  Widget build(BuildContext context) {
    final simulation = DsaSimulation.tryParse(
      block.rawMap('dsa_sim') ?? block.raw,
    );
    return BlockCard(
      icon: Icons.account_tree_outlined,
      label: 'Mô phỏng thuật toán',
      title: block.title,
      child: simulation == null
          ? const Text('Dữ liệu mô phỏng chưa hợp lệ.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (block.body case final String body when body.isNotEmpty)
                  RichContent(body),
                _SimulationPlayer(
                  key: ObjectKey(block),
                  simulation: simulation,
                ),
              ],
            ),
    );
  }
}

class _SimulationPlayer extends StatefulWidget {
  const _SimulationPlayer({super.key, required this.simulation});

  final DsaSimulation simulation;

  @override
  State<_SimulationPlayer> createState() => _SimulationPlayerState();
}

class _SimulationPlayerState extends State<_SimulationPlayer> {
  late final _binary = widget.simulation.algorithm == DsaAlgorithm.binarySearch
      ? widget.simulation.binarySearchSteps()
      : null;
  late final _traversal = _binary == null
      ? widget.simulation.traversalSteps()
      : null;
  int _step = 0;
  Timer? _timer;

  int get _count => _binary?.length ?? _traversal!.length;
  bool get _finished => _step == _count - 1;

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _move(int step) {
    setState(() {
      _stop();
      _step = step;
    });
  }

  void _togglePlayback() {
    setState(() {
      if (_timer != null) {
        _stop();
        return;
      }
      if (_finished) _step = 0;
      _timer = Timer.periodic(const Duration(milliseconds: 850), (_) {
        setState(() {
          if (!_finished) _step++;
          if (_finished) _stop();
        });
      });
    });
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final simulation = widget.simulation;
    final binary = _binary;
    final running = _timer != null;
    final algorithm = switch (simulation.algorithm) {
      DsaAlgorithm.binarySearch => 'Tìm kiếm nhị phân',
      DsaAlgorithm.breadthFirst => 'Duyệt theo chiều rộng (BFS)',
      DsaAlgorithm.depthFirst => 'Duyệt theo chiều sâu (DFS)',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(algorithm, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (binary != null)
          _BinaryFrame(simulation: simulation, step: binary[_step])
        else
          _TraversalFrame(
            simulation: simulation,
            step: _traversal![_step],
            finished: _finished,
          ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text('Bước mô phỏng ${_step + 1}/$_count'),
        ),
        Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Đặt lại mô phỏng',
              onPressed: _step == 0 && !running ? null : () => _move(0),
              icon: const Icon(Icons.restart_alt),
            ),
            IconButton(
              tooltip: 'Lùi bước mô phỏng',
              onPressed: _step == 0 ? null : () => _move(_step - 1),
              icon: const Icon(Icons.skip_previous),
            ),
            IconButton(
              tooltip: running ? 'Tạm dừng mô phỏng' : 'Chạy mô phỏng',
              onPressed: _count < 2 ? null : _togglePlayback,
              icon: Icon(running ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              tooltip: 'Tiến bước mô phỏng',
              onPressed: _finished ? null : () => _move(_step + 1),
              icon: const Icon(Icons.skip_next),
            ),
          ],
        ),
      ],
    );
  }
}

class _BinaryFrame extends StatelessWidget {
  const _BinaryFrame({required this.simulation, required this.step});

  final DsaSimulation simulation;
  final BinarySearchStep step;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final middle = step.middle;
    final values = simulation.values;
    final target = simulation.target;
    final detail = switch (step.comparison) {
      null => 'Khoảng tìm kiếm đã rỗng. Không tìm thấy $target.',
      0 => 'Tìm thấy $target ở chỉ số $middle.',
      < 0 => '${values[middle!]} < $target. Tiếp tục tìm ở nửa bên phải.',
      _ => '${values[middle!]} > $target. Tiếp tục tìm ở nửa bên trái.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Giá trị cần tìm: $target'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (var i = 0; i < values.length; i++)
              _ArrayCell(
                value: values[i],
                index: i,
                foreground: i == middle ? colors.onPrimary : colors.onSurface,
                background: i == middle
                    ? colors.primary
                    : i >= step.low && i <= step.high
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                active: i == middle,
                inRange: i >= step.low && i <= step.high,
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (middle != null)
          Text('Trái: ${step.low} · Giữa: $middle · Phải: ${step.high}'),
        Text(detail),
      ],
    );
  }
}

class _ArrayCell extends StatelessWidget {
  const _ArrayCell({
    required this.value,
    required this.index,
    required this.foreground,
    required this.background,
    required this.active,
    required this.inRange,
  });

  final int value;
  final int index;
  final Color foreground;
  final Color background;
  final bool active;
  final bool inRange;

  @override
  Widget build(BuildContext context) => Semantics(
    excludeSemantics: true,
    label:
        'Chỉ số $index, giá trị $value${active
            ? ', vị trí giữa'
            : inRange
            ? ', đang xét'
            : ', đã loại'}',
    child: Container(
      constraints: const BoxConstraints(minWidth: 40),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value',
            style: TextStyle(fontWeight: FontWeight.w700, color: foreground),
          ),
          Text('$index', style: TextStyle(fontSize: 10, color: foreground)),
        ],
      ),
    ),
  );
}

class _TraversalFrame extends StatelessWidget {
  const _TraversalFrame({
    required this.simulation,
    required this.step,
    required this.finished,
  });

  final DsaSimulation simulation;
  final TraversalStep step;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final breadthFirst = simulation.algorithm == DsaAlgorithm.breadthFirst;
    final pending = breadthFirst ? step.pending : step.pending.reversed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 230,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final nodes = simulation.nodes;
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              const nodeRadius = 17.0;
              final layoutRadius = math.max(
                0.0,
                math.min(size.width, size.height) / 2 - nodeRadius - 5,
              );
              final positions = {
                for (var i = 0; i < nodes.length; i++)
                  nodes[i]: Offset(
                    size.width / 2 +
                        (nodes.length == 1
                            ? 0
                            : math.sin(i * 2 * math.pi / nodes.length) *
                                  layoutRadius),
                    size.height / 2 -
                        (nodes.length == 1
                            ? 0
                            : math.cos(i * 2 * math.pi / nodes.length) *
                                  layoutRadius),
                  ),
              };
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GraphEdges(
                        positions: positions,
                        edges: simulation.edges,
                        directed: simulation.directed,
                        color: colors.onSurfaceVariant.withValues(alpha: .55),
                        nodeRadius: nodeRadius,
                      ),
                    ),
                  ),
                  for (final node in nodes)
                    Positioned(
                      left: positions[node]!.dx - nodeRadius,
                      top: positions[node]!.dy - nodeRadius,
                      width: nodeRadius * 2,
                      height: nodeRadius * 2,
                      child: Tooltip(
                        message: node,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: node == step.active
                                ? colors.primary
                                : step.visited.contains(node)
                                ? colors.primaryContainer
                                : colors.surfaceContainerHighest,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                node,
                                style: TextStyle(
                                  color: node == step.active
                                      ? colors.onPrimary
                                      : colors.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        Text('Đang xét: ${step.active}'),
        Text('Đã duyệt: ${step.visited.join(' → ')}'),
        Text(
          '${breadthFirst ? 'Hàng đợi' : 'Ngăn xếp (đỉnh trước)'}: ${pending.isEmpty ? 'rỗng' : pending.join(', ')}',
        ),
        if (finished && step.visited.length < simulation.nodes.length)
          const Text('Đã duyệt hết các đỉnh có thể đi tới từ đỉnh xuất phát.'),
      ],
    );
  }
}

class _GraphEdges extends CustomPainter {
  const _GraphEdges({
    required this.positions,
    required this.edges,
    required this.directed,
    required this.color,
    required this.nodeRadius,
  });

  final Map<String, Offset> positions;
  final List<DsaEdge> edges;
  final bool directed;
  final Color color;
  final double nodeRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8;
    for (final (from, to) in edges) {
      final origin = positions[from]!;
      final destination = positions[to]!;
      final delta = destination - origin;
      if (delta.distance <= nodeRadius * 2) continue;
      final direction = delta / delta.distance;
      final tip = destination - direction * nodeRadius;
      canvas.drawLine(origin + direction * nodeRadius, tip, paint);
      if (directed) {
        final wing = Offset(-direction.dy, direction.dx) * 4;
        final base = tip - direction * 8;
        canvas.drawLine(base + wing, tip, paint);
        canvas.drawLine(base - wing, tip, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GraphEdges oldDelegate) =>
      positions != oldDelegate.positions ||
      edges != oldDelegate.edges ||
      color != oldDelegate.color ||
      directed != oldDelegate.directed;
}
