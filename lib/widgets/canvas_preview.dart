import 'package:material_ui/material_ui.dart';

import 'canvas_frame_stub.dart' if (dart.library.js_interop) 'canvas_frame_web.dart';

/// Khung chay trang HTML do AI viet (kieu Canvas), cach ly:
/// Android dung WebView chan dieu huong, web dung iframe sandbox chi cho chay script.
/// HTML da duoc server boc CSP chan moi ket noi ngoai.
class CanvasPreview extends StatelessWidget {
  const CanvasPreview({super.key, required this.html});

  final String html;

  /// Thay khung that trong test (WebView khong chay duoc tren may ao test).
  static Widget Function(String html)? debugBuilder;

  @override
  Widget build(BuildContext context) => debugBuilder?.call(html) ?? CanvasFrame(html: html);
}
