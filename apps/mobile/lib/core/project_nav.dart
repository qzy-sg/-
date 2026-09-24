import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_client.dart';
import 'auth_controller.dart';

/// 解析当前可用项目：优先有已确认房间/可全景的项目；没有就自动建一个。
Future<String?> resolveActiveProjectId(WidgetRef ref) async {
  final token = ref.read(authProvider).token;
  final client = ApiClient(token: token);
  final items = await client.listProjects();
  String? fallback;
  for (final item in items) {
    if (item is! Map || item['id'] == null) continue;
    final id = '${item['id']}'.trim();
    if (id.isEmpty || id == 'demo') continue;
    fallback ??= id;
    try {
      final latest = await client.latestScene(id);
      final pans = latest['panoramas'];
      if ('${latest['mode']}' == 'vr_panorama' && pans is List && pans.isNotEmpty) {
        return id;
      }
    } on ApiException catch (err) {
      if (err.status != 404) {
        // 无全景时继续试下一个；其它错误仍可用该项目兜底
      }
    }
  }
  if (fallback != null) return fallback;
  final created = await client.createProject('我的房子');
  final id = '${created['id'] ?? ''}'.trim();
  return id.isEmpty ? null : id;
}

Future<void> openProjectPath(
  BuildContext context,
  WidgetRef ref,
  String suffix, {
  String? query,
}) async {
  try {
    final id = await resolveActiveProjectId(ref);
    if (!context.mounted) return;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('还没有可用的房子，请先新建项目')));
      context.go('/projects');
      return;
    }
    final q = (query == null || query.isEmpty) ? '' : (query.startsWith('?') ? query : '?$query');
    context.push('/projects/$id$suffix$q');
  } on ApiException catch (err) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('打开失败，请稍后重试')));
  }
}
