import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Android/iOS: WebView chay HTML, chan moi dieu huong ra ngoai.
class CanvasFrame extends StatefulWidget {
  const CanvasFrame({super.key, required this.html});
  final String html;

  @override
  State<CanvasFrame> createState() => _CanvasFrameState();
}

class _CanvasFrameState extends State<CanvasFrame> {
  late final WebViewController _ctrl = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.white)
    ..setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (r) => r.url.startsWith('about:') || r.url.startsWith('data:')
          ? NavigationDecision.navigate
          : NavigationDecision.prevent,
    ));

  @override
  void initState() {
    super.initState();
    _ctrl.loadHtmlString(widget.html);
  }

  @override
  void didUpdateWidget(CanvasFrame old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) _ctrl.loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _ctrl);
}
