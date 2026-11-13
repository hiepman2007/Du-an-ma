import 'dart:ui_web' as ui_web;

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

final _registered = <String>{};

/// Web: iframe srcdoc voi sandbox="allow-scripts" (khong cung nguon, khong mo cua so, khong dieu huong trang cha).
class CanvasFrame extends StatelessWidget {
  const CanvasFrame({super.key, required this.html});
  final String html;

  @override
  Widget build(BuildContext context) {
    final viewType = 'canvas-frame-${html.hashCode}-${html.length}';
    if (_registered.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final frame = web.HTMLIFrameElement()
          ..setAttribute('sandbox', 'allow-scripts')
          ..setAttribute('srcdoc', html)
          ..setAttribute('title', 'Mô phỏng');
        frame.style
          ..border = 'none'
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'white';
        return frame;
      });
    }
    return HtmlElementView(viewType: viewType);
  }
}
