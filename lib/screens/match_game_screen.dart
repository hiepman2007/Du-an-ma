import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/motion.dart';

/// Tro choi "Ghep nhanh": ghep thuat ngu voi nghia, tinh gio, ghep sai bi cong 2 giay.
/// Lay cap tu bo the ghi nho va cac cau ghep cap da co (khong goi AI).
class MatchGameScreen extends StatefulWidget {
  const MatchGameScreen({super.key, required this.courseId, this.seed});
  final String courseId;

  /// Co dinh thu tu xao tron (dung cho test).
  final int? seed;

  static const rounds = 6;

  static List<(String, String)> pairsFrom(Course c) {
    final out = <(String, String)>[];
    void add(String a, String b) {
      final x = a.trim(), y = b.trim();
      if (x.isEmpty || y.isEmpty || x.length > 80 || y.length > 140) return;
      if (out.any((p) => p.$1.toLowerCase() == x.toLowerCase())) return;
      out.add((x, y));
    }

    for (final a in c.artifacts) {
      for (final b in a.blocks) {
        for (final card in b.cards) {
          add(card.$1, card.$2);
        }
        for (final p in b.pairs) {
          add(p.$1, p.$2);
        }
      }
    }
    for (final l in c.lessons) {
      for (final b in l.blocks ?? const <Block>[]) {
        for (final card in b.cards) {
          add(card.$1, card.$2);
        }
        for (final p in b.pairs) {
          add(p.$1, p.$2);
        }
      }
    }
    return out;
  }

  @override
  State<MatchGameScreen> createState() => _MatchGameScreenState();
}

class _MatchGameScreenState extends State<MatchGameScreen> {
  late Random _rng;
  List<(String, String)> _round = [];
  List<int> _rightOrder = [];
  final Set<int> _done = {};
  int? _left, _wrongLeft, _wrongRight;
  int _penaltyMs = 0;
  final _watch = Stopwatch();
  Timer? _tick;
  bool _finished = false, _record = false;

  @override
  void initState() {
    super.initState();
    _rng = Random(widget.seed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _start() {
    final course = context.read<AppState>().courseById(widget.courseId);
    if (course == null) return;
    final pool = MatchGameScreen.pairsFrom(course)..shuffle(_rng);
    setState(() {
      _round = pool.take(MatchGameScreen.rounds).toList();
      _rightOrder = List.generate(_round.length, (i) => i)..shuffle(_rng);
      _done.clear();
      _left = _wrongLeft = _wrongRight = null;
      _penaltyMs = 0;
      _finished = _record = false;
    });
    _watch
      ..reset()
      ..start();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && !_finished) setState(() {});
    });
  }

  int get _elapsed => _watch.elapsedMilliseconds + _penaltyMs;

  Future<void> _pickRight(int index) async {
    final left = _left;
    if (left == null || _done.contains(index) || _finished) return;
    if (left == index) {
      setState(() {
        _done.add(index);
        _left = null;
      });
      if (_done.length == _round.length) {
        _watch.stop();
        _tick?.cancel();
        final state = context.read<AppState>();
        final course = state.courseById(widget.courseId);
        final record = course != null && await state.recordMatchTime(course, _elapsed);
        if (mounted) {
          setState(() {
            _finished = true;
            _record = record;
          });
        }
      }
    } else {
      setState(() {
        _penaltyMs += 2000;
        _wrongLeft = left;
        _wrongRight = index;
        _left = null;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _wrongLeft = _wrongRight = null);
      });
    }
  }

  Widget _card(String text, {required bool selected, required bool wrong, required bool done, required VoidCallback onTap}) {
    final color = done
        ? const Color(0xFFE6F4EA)
        : wrong
            ? const Color(0xFFFDE7E9)
            : selected
                ? AppColors.accent
                : Colors.white;
    final border = done
        ? AppColors.success
        : wrong
            ? AppColors.danger
            : selected
                ? AppColors.primary
                : AppColors.border;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: done ? 0.35 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: border, width: selected || wrong ? 2 : 1)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: done ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5))),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final course = context.watch<AppState>().courseById(widget.courseId);
    final seconds = (_elapsed / 1000).toStringAsFixed(1);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ghép nhanh'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('$seconds s', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: course == null
            ? const Center(child: Text('Sổ học tập không còn tồn tại.'))
            : _round.length < 3
                ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Chưa đủ cặp thuật ngữ để chơi. Hãy tạo bộ thẻ ghi nhớ trước.')))
                : _finished
                    ? _result(course)
                    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text('Đã ghép ${_done.length}/${_round.length} · ghép sai +2 giây',
                                style: const TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 6),
                            AnimatedBar(value: _done.length / _round.length),
                          ]),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Column(children: [
                                  for (var i = 0; i < _round.length; i++)
                                    _card(_round[i].$1,
                                        selected: _left == i,
                                        wrong: _wrongLeft == i,
                                        done: _done.contains(i),
                                        onTap: () => setState(() => _left = _left == i ? null : i)),
                                ]),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(children: [
                                  for (final i in _rightOrder)
                                    _card(_round[i].$2,
                                        selected: false, wrong: _wrongRight == i, done: _done.contains(i), onTap: () => _pickRight(i)),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text('Chọn một thuật ngữ bên trái, rồi chọn nghĩa đúng bên phải.',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                        ),
                      ]),
      ),
    );
  }

  Widget _result(Course course) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_record) const CelebrateBurst(size: 120) else const Icon(Icons.emoji_events_outlined, size: 72, color: AppColors.primary),
            const SizedBox(height: 12),
            Text('${(_elapsed / 1000).toStringAsFixed(1)} giây', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _record
                  ? 'Kỷ lục mới!'
                  : 'Kỷ lục: ${((course.bestMatchMs ?? _elapsed) / 1000).toStringAsFixed(1)} giây',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (_penaltyMs > 0) Text('Ghép sai ${_penaltyMs ~/ 2000} lần (+${_penaltyMs ~/ 1000} giây)', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _start, icon: const Icon(Icons.replay), label: const Text('Chơi lại')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Xong')),
          ]),
        ),
      );
}
