import 'dart:typed_data';

import 'api_client.dart';
import 'project_entry.dart';

typedef QuickProgress = void Function(String label, double progress);

/// 方案 B：先识户型出只读预览，再选风格生成效果图与 VR。
class FloorPlanPreview {
  const FloorPlanPreview({
    required this.projectId,
    required this.taskId,
    required this.rooms,
    required this.headline,
    this.totalAreaSqm,
    this.note,
  });

  final String projectId;
  final String taskId;
  final List<Map<String, dynamic>> rooms;
  final String headline;
  final double? totalAreaSqm;
  final String? note;
}

class QuickDesignResult {
  const QuickDesignResult({
    required this.projectId,
    this.versionId,
    this.styleId,
    this.sceneId,
    this.renderTaskId,
  });

  final String projectId;
  final String? versionId;
  final String? styleId;
  final String? sceneId;
  final String? renderTaskId;
}

Future<FloorPlanPreview> runFloorPlanPreview({
  required ApiClient client,
  required Uint8List imageBytes,
  String imageName = 'floorplan.jpg',
  String contentType = 'image/jpeg',
  String? projectId,
  QuickProgress? onProgress,
}) async {
  void note(String label, double progress) => onProgress?.call(label, progress);

  if (imageBytes.isEmpty) {
    throw ApiException('请先上传户型图');
  }

  var id = (projectId ?? '').trim();
  if (id.isEmpty) {
    note('创建项目', 0.08);
    final created = await client.createProject('我的房子');
    id = '${created['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      throw ApiException('没能建起这套房子');
    }
    await saveProjectEntryMode(id, ProjectEntryMode.quick);
  }

  note('上传户型图', 0.22);
  final assetId = await client.uploadImage(
    id,
    filename: imageName,
    contentType: contentType,
    bytes: imageBytes,
  );

  note('正在读取户型', 0.45);
  final analysis = await _waitTask(client, await client.createAnalysis(id, assetId: assetId));
  final taskId = '${analysis['id'] ?? ''}'.trim();
  if (taskId.isEmpty) {
    throw ApiException('识别任务异常');
  }

  note('整理识别结果', 0.78);
  final adopted = await client.adoptAnalysis(id, taskId);
  final preview = adopted['preview'];
  final rooms = <Map<String, dynamic>>[];
  if (preview is Map && preview['rooms'] is List) {
    for (final item in preview['rooms'] as List) {
      if (item is Map) rooms.add(Map<String, dynamic>.from(item));
    }
  }
  if (rooms.isEmpty && adopted['rooms'] is List) {
    for (final item in adopted['rooms'] as List) {
      if (item is Map) rooms.add(Map<String, dynamic>.from(item));
    }
  }
  if (rooms.isEmpty) {
    throw ApiException('没认出房间，换一张更清晰的户型图试试');
  }

  final headline = preview is Map && '${preview['headline'] ?? ''}'.isNotEmpty
      ? '${preview['headline']}'
      : '${rooms.length} 个空间';
  final totalRaw = preview is Map ? preview['total_area_sqm'] : null;
  final total = totalRaw is num ? totalRaw.toDouble() : null;

  note('识别完成', 1);
  return FloorPlanPreview(
    projectId: id,
    taskId: taskId,
    rooms: rooms,
    headline: headline,
    totalAreaSqm: total,
    note: adopted['note']?.toString(),
  );
}

Future<QuickDesignResult> runDesignFromPreview({
  required ApiClient client,
  required String projectId,
  String? styleName,
  String? styleId,
  QuickProgress? onProgress,
}) async {
  void note(String label, double progress) => onProgress?.call(label, progress);
  final styleLabel = (styleName == null || styleName.isEmpty) ? '推荐风格' : styleName;

  note('生成设计方案', 0.2);
  final draft = await client.saveDraft(
    projectId,
    confirmed: true,
    title: '$styleLabel · AI 方案',
    summary: '按户型识别结果与风格自动生成',
    styleId: styleId,
    options: [
      {
        'name': styleLabel,
        'title': styleLabel,
        'summary': '按当前户型与风格整理的一版方向',
        'style_id': ?styleId,
      },
    ],
  );
  final versionId = '${draft['id'] ?? ''}'.trim();
  if (versionId.isEmpty) {
    throw ApiException('方案没有生成成功');
  }
  await client.confirmVersion(projectId, versionId);

  // 项目名跟着风格走，列表更好认
  try {
    await client.updateProject(projectId, name: '$styleLabel · 我的房子');
  } catch (_) {}

  note('生成效果图', 0.48);
  final renderTask = await _waitTask(
    client,
    await client.createRender(projectId, versionId, confirmed: true),
  );
  final renderTaskId = '${renderTask['id'] ?? ''}'.trim();

  note('生成环视', 0.78);
  final sceneTask = await _waitTask(
    client,
    await client.createScene(projectId, designVersionId: versionId, confirmed: true),
  );
  final result = sceneTask['result'];
  final sceneId = result is Map ? '${result['scene_version_id'] ?? ''}' : '';
  if (sceneId.isEmpty) {
    throw ApiException('环视没有生成成功，请稍后在房子里重试');
  }

  note('完成', 1);
  return QuickDesignResult(
    projectId: projectId,
    versionId: versionId,
    styleId: styleId,
    sceneId: sceneId,
    renderTaskId: renderTaskId.isEmpty ? null : renderTaskId,
  );
}

Future<Map<String, dynamic>> _waitTask(ApiClient client, Map<String, dynamic> created) async {
  var body = created;
  var taskId = '${body['id'] ?? ''}';
  for (var i = 0; i < 50; i++) {
    final status = '${body['status'] ?? ''}';
    if (status == 'succeeded') return body;
    if (status == 'failed' || status == 'canceled') {
      throw ApiException(body['error_message']?.toString() ?? '生成失败，请重试');
    }
    if (taskId.isEmpty) {
      throw ApiException('任务没有返回编号');
    }
    await Future<void>.delayed(Duration(milliseconds: i < 3 ? 200 : 450));
    body = await client.getTask(taskId);
    taskId = '${body['id'] ?? taskId}';
  }
  throw ApiException('生成时间有点久，请稍后在房子里继续');
}
