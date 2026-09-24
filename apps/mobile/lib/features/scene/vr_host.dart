import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'vr_host_io.dart' if (dart.library.html) 'vr_host_web.dart' as impl;

typedef VrEventCallback = void Function(Map<String, dynamic> event);

abstract class VrHostController {
  Future<void> loadScene(Map<String, dynamic> payload);
  Future<void> setRoom(String roomId);
  Future<void> resetLook();
  Future<void> disposeViewer();
}

/// VR 全景宿主：移动端 WebView，Chrome/Web 用 iframe（webview_flutter 无 Web 实现）。
class VrHost extends StatelessWidget {
  const VrHost({
    super.key,
    required this.viewerUrl,
    required this.onEvent,
    required this.onReady,
  });

  final String viewerUrl;
  final VrEventCallback onEvent;
  final void Function(VrHostController controller) onReady;

  static bool get supportedOnThisPlatform => kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return impl.buildVrHost(
      viewerUrl: viewerUrl,
      onEvent: onEvent,
      onReady: onReady,
    );
  }
}
