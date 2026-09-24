import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/design_widgets.dart';
import '../../core/page_chrome.dart';

/// 户型识别：只读预览，一键采用。不做一条条「确认」。
class AnalysisPage extends ConsumerStatefulWidget {
  const AnalysisPage({super.key, required this.projectId, this.assetId});
  final String projectId;
  final String? assetId;

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> {
  List<_RoomRow> _rooms = const [];
  String? _taskId;
  String? _headline;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<Map<String, dynamic>> _waitTask(ApiClient client, Map<String, dynamic> created) async {
    var body = created;
    var taskId = '${body['id'] ?? ''}';
    for (var i = 0; i < 40; i++) {
      final status = '${body['status'] ?? ''}';
      if (status == 'succeeded') return body;
      if (status == 'failed' || status == 'canceled') {
        throw ApiException(body['error_message']?.toString() ?? '识别失败，请重试');
      }
      if (taskId.isEmpty) throw ApiException('识别任务异常');
      await Future<void>.delayed(Duration(milliseconds: i < 3 ? 200 : 400));
      body = await client.getTask(taskId);
      taskId = '${body['id'] ?? taskId}';
    }
    throw ApiException('识别时间有点久，请重试');
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _loading = true;
      _error = null;
      _rooms = const [];
      _headline = null;
    });
    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      final body = await _waitTask(
        client,
        await client.createAnalysis(widget.projectId, assetId: widget.assetId),
      );
      if (!mounted) return;
      final result = body['result'];
      final raw = result is Map ? result['rooms'] : null;
      final rooms = <_RoomRow>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final name = '${item['name'] ?? ''}'.trim();
          if (name.isEmpty) continue;
          final area = item['area_sqm'];
          rooms.add(
            _RoomRow(
              name: name,
              areaSqm: area is num ? area.toDouble() : null,
              confidence: item['confidence'] is num ? (item['confidence'] as num).toDouble() : null,
            ),
          );
        }
      }
      final total = rooms.fold<double>(0, (sum, r) => sum + (r.areaSqm ?? 0));
      setState(() {
        _taskId = '${body['id'] ?? ''}';
        _rooms = rooms;
        _headline = rooms.isEmpty ? null : '${rooms.length} 个空间 · 约 ${total > 0 ? total.toStringAsFixed(0) : '—'}㎡';
        _loading = false;
        if (rooms.isEmpty) {
          _error = '没认出房间，换一张更清晰的户型图试试';
        }
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '识别失败，请返回重新上传或重试';
        _loading = false;
      });
    }
  }

  Future<void> _adoptAndContinue() async {
    if (_busy || _taskId == null || _taskId!.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      await client.adoptAnalysis(widget.projectId, _taskId!);
      if (!mounted) return;
      context.go('/projects/${widget.projectId}/layouts');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '没能采用识别结果，请重试或换图';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    CircleBackButton(),
                    Expanded(child: Text('户型识别', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    AiMark(size: 40),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const AiBusy(message: '正在读户型…', hint: '识别房间与大致面积')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          PageHeroTitle(
                            title: _rooms.isEmpty ? '还没读清楚' : 'AI 已经读完了',
                            subtitle: _rooms.isEmpty
                                ? '换一张更清晰、带房间标注的图会更好'
                                : '只读预览，不用一条条点确认。不对就换图。',
                          ),
                          const SizedBox(height: 18),
                          if (_error != null) ...[
                            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13, height: 1.4)),
                            TextButton(onPressed: _runAnalysis, child: const Text('重新识别')),
                            TextButton(
                              onPressed: () => context.push('/projects/${widget.projectId}/upload'),
                              child: const Text('换一张户型图'),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_rooms.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.line),
                                boxShadow: AppColors.shadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_headline != null)
                                    Text(_headline!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  const Text('已自动整理，可直接往下做', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                  const SizedBox(height: 14),
                                  for (final room in _rooms)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(color: AppColors.brass, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(room.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                          ),
                                          Text(
                                            room.areaSqm == null ? '—' : '${room.areaSqm}㎡',
                                            style: const TextStyle(fontSize: 14, color: AppColors.sub, fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
              SoftBottomBar(
                child: PrimaryButton(
                  label: _busy
                      ? '正在继续…'
                      : _rooms.isEmpty
                          ? '重新识别'
                          : '就用这个，选住法',
                  onPressed: _loading || _busy
                      ? null
                      : _rooms.isEmpty
                          ? _runAnalysis
                          : _adoptAndContinue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomRow {
  const _RoomRow({required this.name, this.areaSqm, this.confidence});
  final String name;
  final double? areaSqm;
  final double? confidence;
}
