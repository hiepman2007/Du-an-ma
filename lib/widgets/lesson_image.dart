import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Anh xem truoc cua mot bai tren lo trinh. Chua co anh (dang tim / khong tim thay / loi mang) thi hien
/// o mau co bieu tuong, mau theo ten bai de cac bai trong de phan biet.
class LessonImage extends StatefulWidget {
  const LessonImage({super.key, required this.course, required this.lesson, this.size = 56, this.radius = 10, this.aspect});
  final Course course;
  final Lesson lesson;
  final double size, radius;

  /// Dat ti le (vd 16/9) de anh chiem het chieu ngang thay vi o vuong [size].
  final double? aspect;

  @override
  State<LessonImage> createState() => _LessonImageState();
}

class _LessonImageState extends State<LessonImage> {
  late Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = context.read<AppState>().lessonImage(widget.course, widget.lesson);
  }

  static const _palette = [Color(0xFFFDE7E9), Color(0xFFE8F0FE), Color(0xFFE6F4EA), Color(0xFFFFF4E5), Color(0xFFF3E8FD)];

  Widget _placeholder() {
    final color = _palette[widget.lesson.title.hashCode.abs() % _palette.length];
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Icon(Icons.auto_stories_outlined, size: widget.aspect == null ? widget.size * 0.42 : 34, color: AppColors.primary.withValues(alpha: 0.7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = FutureBuilder<String?>(
      future: _url,
      builder: (_, snap) {
        final url = snap.data;
        if (url == null) return _placeholder();
        return Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder(),
            frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : _placeholder());
      },
    );
    final clipped = ClipRRect(borderRadius: BorderRadius.circular(widget.radius), child: image);
    if (widget.aspect != null) return AspectRatio(aspectRatio: widget.aspect!, child: clipped);
    return SizedBox(width: widget.size, height: widget.size, child: clipped);
  }
}
