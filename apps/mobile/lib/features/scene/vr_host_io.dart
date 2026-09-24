import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'vr_host.dart';

Widget buildVrHost({
  required String viewerUrl,
  required VrEventCallback onEvent,
  required void Function(VrHostController controller) onReady,
}) {
  return _IoVrHost(viewerUrl: viewerUrl, onEvent: onEvent, onReady: onReady);
}

class _IoController implements VrHostController {
  _IoController(this._web);

  final WebViewController _web;

  @override
  Future<void> loadScene(Map<String, dynamic> payload) async {
    final encoded = jsonEncode(payload);
    await _web.runJavaScript('window.hostLoadScene && window.hostLoadScene($encoded)');
  }

  @override
  Future<void> setRoom(String roomId) async {
    final safe = roomId.replaceAll("'", r"\'");
    await _web.runJavaScript("window.hostSetCamera && window.hostSetCamera('$safe')");
  }

  @override
  Future<void> resetLook() async {
    await _web.runJavaScript('window.hostResetLook && window.hostResetLook()');
  }

  @override
  Future<void> disposeViewer() async {
    await _web.runJavaScript('window.hostDispose && window.hostDispose()');
  }
}

class _IoVrHost extends StatefulWidget {
  const _IoVrHost({required this.viewerUrl, required this.onEvent, required this.onReady});

  final String viewerUrl;
  final VrEventCallback onEvent;
  final void Function(VrHostController controller) onReady;

  @override
  State<_IoVrHost> createState() => _IoVrHostState();
}

class _IoVrHostState extends State<_IoVrHost> {
  late final WebViewController _controller;
  late final _IoController _host;
  bool _pushed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _host = _IoController(_controller);
    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF111111))
      ..addJavaScriptChannel(
        'HouseViewer',
        onMessageReceived: (message) {
          try {
            final data = jsonDecode(message.message);
            if (data is Map) {
              widget.onEvent(Map<String, dynamic>.from(data));
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (_pushed) return;
            _pushed = true;
            widget.onReady(_host);
          },
          onWebResourceError: (error) {
            widget.onEvent({'type': 'scene.error', 'message': '查看器加载失败：${error.description}'});
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.viewerUrl));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
