enum DsaAlgorithm { binarySearch, breadthFirst, depthFirst }

typedef DsaEdge = (String from, String to);

class DsaSimulation {
  const DsaSimulation._({
    required this.algorithm,
    this.values = const [],
    this.target,
    this.nodes = const [],
    this.edges = const [],
    this.start,
    this.directed = false,
  });

  final DsaAlgorithm algorithm;
  final List<int> values;
  final int? target;
  final List<String> nodes;
  final List<DsaEdge> edges;
  final String? start;
  final bool directed;

  static DsaSimulation? tryParse(Map<String, dynamic> data) {
    final algorithm = switch (data['algorithm']) {
      'binary_search' => DsaAlgorithm.binarySearch,
      'bfs' => DsaAlgorithm.breadthFirst,
      'dfs' => DsaAlgorithm.depthFirst,
      _ => null,
    };
    if (algorithm == null) return null;

    if (algorithm == DsaAlgorithm.binarySearch) {
      final values = data['values'];
      final target = data['target'];
      if (values is! List ||
          values.isEmpty ||
          values.length > 16 ||
          !_boundedInt(target)) {
        return null;
      }
      final sorted = <int>[];
      for (final value in values) {
        if (!_boundedInt(value)) return null;
        final number = value as int;
        if (sorted.isNotEmpty && sorted.last > number) return null;
        sorted.add(number);
      }
      return DsaSimulation._(
        algorithm: algorithm,
        values: List.unmodifiable(sorted),
        target: target as int,
      );
    }

    final nodes = data['nodes'];
    final edges = data['edges'];
    final start = data['start'];
    if (nodes is! List ||
        nodes.isEmpty ||
        nodes.length > 10 ||
        edges is! List ||
        edges.length > 30) {
      return null;
    }
    final names = <String>{};
    for (final name in nodes) {
      if (name is! String ||
          name.trim().isEmpty ||
          name.length > 12 ||
          !names.add(name)) {
        return null;
      }
    }
    if (start is! String || !names.contains(start)) return null;

    final directed = data['directed'] == true;
    final connections = <DsaEdge>{};
    for (final edge in edges) {
      final (from, to) = switch (edge) {
        [final String from, final String to] => (from, to),
        {'from': final String from, 'to': final String to} => (from, to),
        _ => ('', ''),
      };
      if (!names.contains(from) || !names.contains(to) || from == to) {
        return null;
      }
      if (directed || !connections.contains((to, from))) {
        connections.add((from, to));
      }
    }
    return DsaSimulation._(
      algorithm: algorithm,
      nodes: List.unmodifiable(names),
      edges: List.unmodifiable(connections),
      start: start,
      directed: directed,
    );
  }

  static bool _boundedInt(Object? value) =>
      value is int && value.abs() <= 999999;

  List<BinarySearchStep> binarySearchSteps() {
    final goal = target!;
    final steps = <BinarySearchStep>[];
    var low = 0;
    var high = values.length - 1;
    while (low <= high) {
      final middle = low + ((high - low) ~/ 2);
      final comparison = values[middle].compareTo(goal);
      steps.add(
        BinarySearchStep(
          low: low,
          high: high,
          middle: middle,
          comparison: comparison,
        ),
      );
      if (comparison == 0) return steps;
      if (comparison < 0) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return [...steps, BinarySearchStep(low: low, high: high)];
  }

  List<TraversalStep> traversalSteps() {
    final first = start!;
    final breadthFirst = algorithm == DsaAlgorithm.breadthFirst;
    final neighbors = {for (final node in nodes) node: <String>{}};
    for (final (from, to) in edges) {
      neighbors[from]!.add(to);
      if (!directed) neighbors[to]!.add(from);
    }

    final visited = <String>{};
    final pending = [first];
    final steps = <TraversalStep>[];
    while (pending.isNotEmpty) {
      final node = breadthFirst ? pending.removeAt(0) : pending.removeLast();
      if (!visited.add(node)) continue;
      final next = nodes
          .where(
            (name) =>
                neighbors[node]!.contains(name) && !visited.contains(name),
          )
          .toList();
      if (breadthFirst) {
        pending.addAll(next.where((name) => !pending.contains(name)));
      } else {
        for (final name in next.reversed) {
          pending.remove(name);
          pending.add(name);
        }
      }
      steps.add(
        TraversalStep(
          active: node,
          visited: List.unmodifiable(visited),
          pending: List.unmodifiable(pending),
        ),
      );
    }
    return steps;
  }
}

class BinarySearchStep {
  const BinarySearchStep({
    required this.low,
    required this.high,
    this.middle,
    this.comparison,
  });

  final int low;
  final int high;
  final int? middle;
  final int? comparison;
}

class TraversalStep {
  const TraversalStep({
    required this.active,
    required this.visited,
    required this.pending,
  });

  final String active;
  final List<String> visited;
  final List<String> pending;
}
