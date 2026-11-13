import 'package:material_ui/material_ui.dart';

import '../models/models.dart';

Future<StudyBrief?> showStudyGoal(BuildContext context, {required String topic, StudyBrief? previous, bool edit = false}) =>
    showDialog<StudyBrief>(context: context, builder: (_) => _StudyGoal(topic: topic, previous: previous, edit: edit));

class _StudyGoal extends StatefulWidget {
  const _StudyGoal({required this.topic, this.previous, required this.edit});

  final String topic;
  final StudyBrief? previous;
  final bool edit;

  @override
  State<_StudyGoal> createState() => _StudyGoalState();
}

class _StudyGoalState extends State<_StudyGoal> {
  late final _topic = TextEditingController(text: widget.previous?.topic ?? widget.topic);
  late final _scope = TextEditingController(text: widget.previous?.scope ?? '');
  late String _goal = widget.previous?.goal ?? 'Học nền tảng';
  late String _level = widget.previous?.level ?? 'Mới bắt đầu';
  late int _minutes = widget.previous?.minutesPerDay ?? 30;
  late DateTime? _exam = widget.previous?.examDate;
  late bool _search = widget.previous?.searchWeb ?? true;

  @override
  void dispose() {
    _topic.dispose();
    _scope.dispose();
    super.dispose();
  }

  void _submit({bool defaults = false}) {
    if (_topic.text.trim().isEmpty) return;
    final topic = _topic.text.trim();
    Navigator.pop(context, defaults ? StudyBrief(topic: topic, searchWeb: _search) : StudyBrief(
      topic: topic, goal: _goal, minutesPerDay: _minutes, level: _level, scope: _scope.text.trim(),
      examDate: _exam, searchWeb: _search,
    ));
  }

  Widget _choices<T>(String label, List<T> values, T current, String Function(T) name, ValueChanged<T> choose) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 14),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 4, children: [
        for (final value in values) ChoiceChip(label: Text(name(value)), selected: value == current, onSelected: (_) => setState(() => choose(value))),
      ]),
    ],
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.edit ? 'Điều chỉnh lịch học' : 'Mục tiêu học của bạn'),
    content: SizedBox(width: 490, child: SingleChildScrollView(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _topic, readOnly: widget.edit, maxLength: 180, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Môn hoặc chủ đề', counterText: '')),
        _choices('Bạn muốn đạt gì?', ['Học nền tảng', 'Ôn thi', 'Luyện vận dụng', 'Ôn phỏng vấn'], _goal, (v) => v, (v) => _goal = v),
        _choices('Mỗi ngày học được bao lâu?', [15, 30, 60, 90], _minutes, (v) => '$v phút', (v) => _minutes = v),
        _choices('Bạn đã học đến đâu?', ['Mới bắt đầu', 'Biết cơ bản', 'Muốn luyện nâng cao'], _level, (v) => v, (v) => _level = v),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(icon: const Icon(Icons.event_outlined), label: Text(_exam == null
            ? 'Thêm ngày thi'
            : 'Thi ngày ${_exam!.day}/${_exam!.month}/${_exam!.year}'), onPressed: () async {
              final now = DateUtils.dateOnly(DateTime.now());
              final date = await showDatePicker(context: context, firstDate: now,
                lastDate: DateTime(now.year + 3), initialDate: _exam != null && !_exam!.isBefore(now) ? _exam : now);
              if (date != null && mounted) setState(() => _exam = date);
            }),
          if (_exam != null) TextButton(onPressed: () => setState(() => _exam = null), child: const Text('Bỏ ngày thi')),
        ]),
        const SizedBox(height: 8),
        TextField(controller: _scope, readOnly: widget.edit, maxLength: 240, decoration: const InputDecoration(
          labelText: 'Phạm vi môn học (tùy chọn)', hintText: 'Ví dụ: chỉ chương 1–4', counterText: '')),
        if (!widget.edit)
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Tìm thêm tài liệu công khai'),
            value: _search, onChanged: (value) => setState(() => _search = value)),
      ],
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
      if (!widget.edit) TextButton(onPressed: _topic.text.trim().isEmpty ? null : () => _submit(defaults: true), child: const Text('Dùng mặc định')),
      FilledButton(onPressed: _topic.text.trim().isEmpty ? null : _submit, child: Text(widget.edit ? 'Lưu lịch học' : 'Lập lộ trình')),
    ],
  );
}
