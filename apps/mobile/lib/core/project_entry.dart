import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'auth_controller.dart';

/// 新建路径：直传图纸 / AI 帮做。
enum ProjectEntryMode { quick, guided }

extension ProjectEntryModeX on ProjectEntryMode {
  String get wire => this == ProjectEntryMode.quick ? 'quick' : 'guided';

  static ProjectEntryMode? parse(String? raw) {
    switch (raw) {
      case 'quick':
        return ProjectEntryMode.quick;
      case 'guided':
        return ProjectEntryMode.guided;
      default:
        return null;
    }
  }
}

Future<void> saveProjectEntryMode(String projectId, ProjectEntryMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('project_entry_$projectId', mode.wire);
}

Future<ProjectEntryMode?> loadProjectEntryMode(String projectId) async {
  final prefs = await SharedPreferences.getInstance();
  return ProjectEntryModeX.parse(prefs.getString('project_entry_$projectId'));
}

bool _hasPanorama(Map<String, dynamic> latest) {
  final pans = latest['panoramas'];
  return '${latest['mode']}' == 'vr_panorama' && pans is List && pans.isNotEmpty;
}

/// 点「查看」：有全景直接看；否则按创建路径继续；[manage] 才进总控台。
Future<void> openProjectSmart(
  BuildContext context,
  WidgetRef ref,
  String projectId, {
  bool manage = false,
}) async {
  if (manage) {
    if (!context.mounted) return;
    context.push('/projects/$projectId');
    return;
  }

  final token = ref.read(authProvider).token;
  final client = ApiClient(token: token);

  try {
    final latest = await client.latestScene(projectId);
    if (_hasPanorama(latest) && context.mounted) {
      context.push('/projects/$projectId/scene');
      return;
    }
  } on ApiException catch (err) {
    if (err.status != 404 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    }
  } catch (_) {}

  Map<String, dynamic>? project;
  try {
    project = await client.getProject(projectId);
  } on ApiException catch (err) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    }
    return;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('打开失败，请重试')));
    }
    return;
  }

  if (!context.mounted) return;
  final versionId = '${project['current_design_version_id'] ?? ''}'.trim();
  if (versionId.isNotEmpty) {
    context.push('/projects/$projectId/scene?versionId=$versionId');
    return;
  }

  final mode = await loadProjectEntryMode(projectId);
  if (!context.mounted) return;
  switch (mode) {
    case ProjectEntryMode.quick:
      context.push('/projects/$projectId/upload');
    case ProjectEntryMode.guided:
      context.push('/projects/$projectId/profile');
    case null:
      context.push('/projects/$projectId');
  }
}
