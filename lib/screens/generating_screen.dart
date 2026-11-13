import 'package:material_ui/material_ui.dart';

import '../services/api_client.dart';
import '../theme.dart';

/// Man hinh cho AI: hien tung buoc; loi thi cho thu lai. Tra ve ket qua qua Navigator.pop.
class GeneratingScreen<T> extends StatefulWidget {
  const GeneratingScreen({super.key, required this.title, required this.run});
  final String title;
  final Future<T> Function(void Function(String step) onStep) run;
  @override
  State<GeneratingScreen<T>> createState() => _GeneratingScreenState<T>();
}

class _GeneratingScreenState<T> extends State<GeneratingScreen<T>> {
  String _step = 'Đang chuẩn bị…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    setState(() => _error = null);
    try {
      final r = await widget.run((s) {
        if (mounted) setState(() => _step = s);
      });
      if (mounted) Navigator.pop(context, r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Có lỗi xảy ra: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _error == null
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5)),
                  const SizedBox(height: 24),
                  const Eyebrow('AI đang làm việc'),
                  const SizedBox(height: 6),
                  Text(_step, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Thường mất 15–40 giây', style: TextStyle(color: AppColors.muted)),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: _go, child: const Text('Thử lại')),
                ]),
        ),
      ),
    );
  }
}
