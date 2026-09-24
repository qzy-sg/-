import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/config.dart';
import '../../core/design_widgets.dart';
import '../../core/page_chrome.dart';

class RendersPage extends ConsumerStatefulWidget {
  const RendersPage({super.key, required this.projectId, this.versionId});
  final String projectId;
  final String? versionId;

  @override
  ConsumerState<RendersPage> createState() => _RendersPageState();
}

class _RendersPageState extends ConsumerState<RendersPage> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _versionId;
  String? _note;
  List<_Shot> _shots = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      var versionId = widget.versionId;
      if (versionId == null || versionId.isEmpty) {
        final items = await client.listVersions(widget.projectId);
        if (items.isNotEmpty && items.first is Map) {
          versionId = '${(items.first as Map)['id']}';
        }
      }
      if (versionId == null || versionId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = '请先确认一个设计方案';
          _loading = false;
        });
        return;
      }
      _versionId = versionId;
      await _createRender(client, versionId);
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '效果图生成失败';
        _loading = false;
        _busy = false;
      });
    }
  }

  Future<void> _createRender(ApiClient client, String versionId) async {
    setState(() => _busy = true);
    final task = await client.createRender(widget.projectId, versionId, confirmed: true);
    if (!mounted) return;
    final result = task['result'];
    final note = result is Map
        ? '${result['note'] ?? '效果图仅供看气氛，不是环视，也不保证真实尺寸。'}'
        : '效果图仅供看气氛，不是环视，也不保证真实尺寸。';
    final status = '${task['status'] ?? ''}';
    final shots = <_Shot>[];
    if (result is Map && result['shots'] is List) {
      for (final item in result['shots'] as List) {
        if (item is! Map) continue;
        final raw = '${item['url'] ?? ''}';
        if (raw.isEmpty) continue;
        final url = raw.startsWith('http') ? raw : '${AppConfig.apiBase}$raw';
        shots.add(
          _Shot(
            roomId: '${item['room_id'] ?? ''}',
            name: '${item['name'] ?? item['room_id'] ?? '房间'}',
            url: url,
            status: status == 'succeeded' ? '已生成' : status,
          ),
        );
      }
    }
    setState(() {
      _shots = shots;
      _note = note;
      _loading = false;
      _busy = false;
      if (shots.isEmpty && status == 'succeeded') {
        _error = '这一版还没有效果图';
      }
    });
  }

  void _openScene(_Shot? shot) {
    final params = <String, String>{};
    if (_versionId != null && _versionId!.isNotEmpty) {
      params['versionId'] = _versionId!;
    }
    if (shot != null && shot.roomId.isNotEmpty) {
      params['room'] = shot.roomId;
    }
    final query = params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';
    context.push('/projects/${widget.projectId}/scene$query');
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    const CircleBackButton(),
                    const Expanded(
                      child: Text('效果图', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    const AiMark(size: 40),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const AiBusy(message: '正在整理效果图…', hint: 'AI 按房间出正面图')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          PageHeroTitle(
                            title: _busy ? '正在出图' : '按房间看效果',
                            subtitle: _busy
                                ? 'AI 正在整理每个空间的正面效果…'
                                : '点一张就能进那个房间的环视',
                          ),
                          const SizedBox(height: 18),
                          if (_error != null) ...[
                            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                            TextButton(onPressed: _bootstrap, child: const Text('重试')),
                            const SizedBox(height: 8),
                          ],
                          if (_shots.isNotEmpty) ...[
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.82,
                              children: [
                                for (final shot in _shots)
                                  _RenderTile(
                                    shot: shot,
                                    onTap: () => _openScene(shot),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _note ?? '效果图仅供看气氛，不是环视，也不保证真实尺寸。',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                            ),
                          ],
                        ],
                      ),
              ),
              SoftBottomBar(
                child: PrimaryButton(
                  label: '去环视',
                  onPressed: _shots.isEmpty ? null : () => _openScene(null),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Shot {
  const _Shot({
    required this.roomId,
    required this.name,
    required this.url,
    required this.status,
  });

  final String roomId;
  final String name;
  final String url;
  final String status;
}

class _RenderTile extends StatefulWidget {
  const _RenderTile({required this.shot, required this.onTap});

  final _Shot shot;
  final VoidCallback onTap;

  @override
  State<_RenderTile> createState() => _RenderTileState();
}

class _RenderTileState extends State<_RenderTile> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RenderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shot.url != widget.shot.url) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final response = await Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (code) => code != null && code >= 200 && code < 500,
        ),
      ).get<List<int>>(widget.shot.url);
      final status = response.statusCode ?? 0;
      final data = response.data;
      if (status >= 400 || data == null || data.length < 32) {
        throw Exception('bad image');
      }
      if (!mounted) return;
      setState(() => _bytes = Uint8List.fromList(data));
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
            boxShadow: AppColors.shadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_bytes != null)
                        Image.memory(_bytes!, fit: BoxFit.cover)
                      else if (_failed)
                        Container(
                          color: AppColors.chip,
                          alignment: Alignment.center,
                          child: const Text('暂不可用', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                        )
                      else
                        Container(
                          color: AppColors.chip,
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                          child: Text(widget.shot.status, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.shot.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text('点开看环视', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
