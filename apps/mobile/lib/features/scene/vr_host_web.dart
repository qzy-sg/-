// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import 'vr_host.dart';

Widget buildVrHost({
  required String viewerUrl,
  required VrEventCallback onEvent,
  required void Function(VrHostController controller) onReady,
}) {
  return _WebVrHost(viewerUrl: viewerUrl, onEvent: onEvent, onReady: onReady);
}

class _WebController implements VrHostController {
  _WebController(this._iframe);

  final html.IFrameElement _iframe;

  /// JSON round-trip so structured clone yields plain JS objects cross-origin.
  void _post(Map<String, dynamic> message) {
    final plain = jsonDecode(jsonEncode(message));
    _iframe.contentWindow?.postMessage(plain, '*');
  }

  @override
  Future<void> loadScene(Map<String, dynamic> payload) async {
    _post({'channel': 'house_vr', 'action': 'load', 'payload': payload});
  }

  @override
  Future<void> setRoom(String roomId) async {
    _post({'channel': 'house_vr', 'action': 'setCamera', 'room': roomId});
  }

  @override
  Future<void> resetLook() async {
    _post({'channel': 'house_vr', 'action': 'resetLook'});
  }

  @override
  Future<void> disposeViewer() async {
    _post({'channel': 'house_vr', 'action': 'dispose'});
  }
}

class _WebVrHost extends StatefulWidget {
  const _WebVrHost({required this.viewerUrl, required this.onEvent, required this.onReady});

  final String viewerUrl;
  final VrEventCallback onEvent;
  final void Function(VrHostController controller) onReady;

  @override
  State<_WebVrHost> createState() => _WebVrHostState();
}

class _WebVrHostState extends State<_WebVrHost> {
  late final String _viewType;
  late final html.IFrameElement _iframe;
  StreamSubscription<html.MessageEvent>? _sub;
  bool _readySent = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'house-vr-${identityHashCode(this)}-${DateTime.now().microsecondsSinceEpoch}';
    _iframe = html.IFrameElement()
      ..src = widget.viewerUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'fullscreen'
      ..allowFullscreen = true;
    _iframe.onLoad.listen((_) {
      if (_readySent || !mounted) return;
      _readySent = true;
      widget.onReady(_WebController(_iframe));
    });
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) => _iframe);
    _sub = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is Map) {
        final map = <String, dynamic>{};
        data.forEach((key, value) {
          map['$key'] = value;
        });
        if (map.containsKey('type')) {
          widget.onEvent(map);
        }
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _iframe.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
