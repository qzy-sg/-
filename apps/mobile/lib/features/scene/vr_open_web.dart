// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

void openVrStandalone(String viewerBase, Map<String, dynamic> payload) {
  final encoded = Uri.encodeComponent(jsonEncode(payload));
  final url = '$viewerBase#boot=$encoded';
  html.window.open(url, '_blank');
}
