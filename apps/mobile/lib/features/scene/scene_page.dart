import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/config.dart';
import '../../core/design_widgets.dart';
import '../../core/page_chrome.dart';
import 'immersive_panorama_page.dart';
import 'panorama_look.dart';
import 'style_tour.dart';

class ScenePage extends ConsumerStatefulWidget {
  const ScenePage({
    super.key,
    required this.projectId,
    this.versionId,
    this.styleName,
    this.initialRoom,
    this.openImmersive = false,
  });
  final String projectId;
  final String? versionId;
  final String? styleName;
  final String? initialRoom;
  final bool openImmersive;

  @override
  ConsumerState<ScenePage> createState() => _ScenePageState();
}

class _ScenePageState extends ConsumerState<ScenePage> {
  Map<String, dynamic>? _manifest;
  String _room = '';
  bool _loading = true;
  bool _forceNew = false;
  double _progress = 0;
  String? _error;
  String? _note;
  List<Map<String, dynamic>> _panoramas = const [];
  bool _stylePreview = false;
  bool _immersive = false;
  bool _immersiveQueued = false;

  StyleTour? get _tour => styleTourFor(widget.styleName);

  @override
  void initState() {
    super.initState();
    _immersiveQueued = widget.openImmersive;
    _bootstrap();
  }

  Map<String, dynamic> _scenePayload() {
    final photo = _stylePreview || '${_manifest?['source']}' == 'floorplan_photo';
    return {
      'readonly': true,
      'mode': 'vr_panorama',
      'photo': photo,
      'scene_version_id': _manifest?['scene_version_id'],
      'default_room': _room,
      'rooms': [for (final item in _panoramas) '${item['room_id']}'],
      'panoramas': _absolutePanoramas(),
    };
  }

  Future<void> _applyManifest(Map<String, dynamic> manifest) async {
    final raw = manifest['panoramas'];
    final rooms = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          rooms.add(Map<String, dynamic>.from(item));
        }
      }
    }
    if (rooms.isEmpty) {
      throw ApiException('没有可环视的全景房间');
    }
    _panoramas = rooms;
    final preferred = widget.initialRoom?.trim() ?? '';
    final hasPreferred = preferred.isNotEmpty && rooms.any((item) => '${item['room_id']}' == preferred);
    _room = hasPreferred ? preferred : '${manifest['default_room'] ?? rooms.first['room_id']}';
    _manifest = manifest;
    _note = '${manifest['license_note'] ?? 'VR 全景示意，只供环视，不能编辑。'}';
  }

  Future<void> _bootstrap() async {
    final tour = _tour;
    if (tour != null) {
      final pans = stylePreviewPanoramas(widget.styleName, AppConfig.apiBase);
      final rooms = pans.isNotEmpty
          ? pans
          : [
              {
                'room_id': 'room_0',
                'name': tour.roomName,
                'url': '${AppConfig.apiBase}/viewer/panoramas/${tour.file}',
              },
            ];
      final preferred = widget.initialRoom?.trim() ?? '';
      final hasPreferred = preferred.isNotEmpty && rooms.any((item) => '${item['room_id']}' == preferred);
      setState(() {
        _stylePreview = true;
        _loading = false;
        _error = null;
        _progress = 0.55;
        _forceNew = false;
        _manifest = null;
        _panoramas = rooms;
        _room = hasPreferred ? preferred : '${rooms.first['room_id']}';
        _note = rooms.length > 1
            ? '可切换 ${rooms.length} 个房间环视。${tour.credit}'
            : tour.credit;
      });
      if (_immersiveQueued) {
        _immersiveQueued = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openImmersive();
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _progress = 0.1;
      _stylePreview = false;
    });
    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      Map<String, dynamic>? manifest;
      if (!_forceNew) {
        try {
          final latest = await client.latestScene(widget.projectId);
          final pans = latest['panoramas'];
          final mode = '${latest['mode'] ?? ''}';
          if (mode == 'vr_panorama' && pans is List && pans.isNotEmpty) {
            final bound = '${latest['design_version_id'] ?? ''}';
            final wanted = widget.versionId ?? '';
            if (wanted.isEmpty || bound.isEmpty || bound == wanted) {
              manifest = latest;
            }
          }
        } on ApiException catch (err) {
          if (err.status != 404) rethrow;
        }
      }
      if (manifest == null) {
        final task = await client.createScene(
          widget.projectId,
          designVersionId: widget.versionId,
          confirmed: true,
        );
        if ('${task['status']}' != 'succeeded') {
          throw ApiException(task['error_message']?.toString() ?? '全景还在生成，请稍后重试');
        }
        final result = task['result'];
        final sceneId = result is Map ? result['scene_version_id'] as String? : null;
        if (sceneId == null) {
          throw ApiException('全景任务未返回版本');
        }
        manifest = await client.manifest(widget.projectId, sceneId);
      }
      await _applyManifest(manifest);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _progress = 0.55;
        _forceNew = false;
      });
      if (_immersiveQueued) {
        _immersiveQueued = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openImmersive();
        });
      }
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
        if (err.code == 'CONFIRMATION_REQUIRED') {
          _error = '${err.message}。请先完成户型识别并一键采用，再回来看全景。';
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = '全景加载失败：$err';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _absolutePanoramas() {
    final items = <Map<String, dynamic>>[];
    for (final item in _panoramas) {
      final raw = '${item['url'] ?? ''}';
      final url = raw.isEmpty || raw.startsWith('http') ? raw : '${AppConfig.apiBase}$raw';
      items.add({...item, 'url': url});
    }
    return items;
  }

  String? _currentUrl() {
    for (final item in _absolutePanoramas()) {
      if ('${item['room_id']}' == _room) return '${item['url']}';
    }
    final items = _absolutePanoramas();
    if (items.isEmpty) return null;
    return '${items.first['url']}';
  }

  Future<void> _confirm() async {
    final sceneId = _manifest?['scene_version_id']?.toString();
    if (sceneId == null || sceneId.isEmpty) return;
    try {
      await ApiClient(token: ref.read(authProvider).token).confirmScene(widget.projectId, sceneId);
      if (!mounted) return;
      context.go('/projects');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _error = err.message);
    }
  }

  void _setRoom(String roomId) {
    setState(() {
      _room = roomId;
      _progress = 0.7;
    });
  }

  Future<void> _openImmersive() async {
    if (_panoramas.isEmpty || (!_stylePreview && _manifest == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('还没有可打开的全景')));
      return;
    }
    setState(() => _immersive = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ImmersivePanoramaPage(
          viewerUrl: '${AppConfig.apiBase}/viewer/?v=6',
          payload: _scenePayload(),
          panoramas: _absolutePanoramas(),
          initialRoom: _room,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _immersive = false);
    if (next == null || next.isEmpty || next == _room) return;
    _setRoom(next);
  }

  Future<void> _onImageError(String message) async {
    if (!mounted) return;
    final expired = message.contains('过期');
    final tooDark = message.contains('过暗');
    final missing = message.contains('不存在');
    setState(() => _error = message);
    if (expired) {
      // 重新拉最新清单拿新签名，不强制重建。
      await _bootstrap();
      return;
    }
    if (tooDark || missing) {
      await _rebuild();
    }
  }

  Future<void> _rebuild() async {
    setState(() {
      _forceNew = true;
      _error = null;
    });
    await _bootstrap();
  }

  String _roomChipLabel(Map<String, dynamic> item) {
    final name = '${item['name'] ?? item['room_id']}';
    final kind = '${item['room_kind'] ?? ''}'.trim();
    final area = item['area_sqm'];
    final bits = <String>[name];
    if (kind.isNotEmpty && kind != name) bits.add(kind);
    if (area is num && area > 0) {
      final text = area % 1 == 0 ? area.toStringAsFixed(0) : area.toStringAsFixed(1);
      bits.add('$text㎡');
    }
    return bits.join(' · ');
  }

  String _headline() {
    final name = _tour?.name ?? widget.styleName;
    if (name != null && name.isNotEmpty) {
      return _loading ? '正在打开「$name」' : '「$name」· 拖动环视';
    }
    if ('${_manifest?['source']}' == 'floorplan_photo') {
      return _loading ? '按房型匹配实景…' : '按房间类型匹配的实景环视';
    }
    return _loading ? '生成中…' : '拖动环视，只能看不能改';
  }

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      title: 'VR 全景',
      subtitle: _headline(),
      step: 8,
      trailing: const AiMark(size: 40),
      body: _loading
          ? const AiBusy(message: '正在打开全景…', hint: '按房间匹配环视画面')
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  if (_error != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12, height: 1.4)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(onPressed: _bootstrap, child: const Text('重试')),
                        if (!_stylePreview) ...[
                          TextButton(onPressed: _rebuild, child: const Text('重新生成')),
                        ],
                        TextButton(onPressed: _openImmersive, child: const Text('进入环视')),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!_immersive)
                    Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_currentUrl() != null)
                              PanoramaLook(
                                key: ValueKey(_currentUrl()),
                                url: _currentUrl()!,
                                onReady: () {
                                  if (!mounted) return;
                                  setState(() {
                                    _progress = 1;
                                    _error = null;
                                  });
                                },
                                onError: _onImageError,
                              )
                            else
                              const ColoredBox(
                                color: Color(0xFF2F463F),
                                child: Center(
                                  child: Text('还没有可环视的全景', style: TextStyle(color: Colors.white70)),
                                ),
                              ),
                            const Positioned(
                              left: 10,
                              top: 10,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.all(Radius.circular(12))),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text('左右拖动预览 · 点右上角进入环视', style: TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Material(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: _openImmersive,
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.fullscreen, size: 16, color: Colors.white),
                                        SizedBox(width: 4),
                                        Text('进入环视', style: TextStyle(color: Colors.white, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _openImmersive, child: const Text('进入环视')),
                  ),
                  LinearProgressIndicator(
                    value: _progress.clamp(0.05, 1),
                    minHeight: 4,
                    color: AppColors.primary,
                    backgroundColor: AppColors.chip,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 4,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final item in _panoramas)
                              ChoiceChip(
                                label: Text(_roomChipLabel(item)),
                                selected: _room == '${item['room_id']}',
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _room == '${item['room_id']}' ? Colors.white : AppColors.sub,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => _setRoom('${item['room_id']}'),
                              ),
                          ],
                        ),
                        if (_note != null) ...[
                          const SizedBox(height: 12),
                          Text(_note!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                        const SizedBox(height: 8),
                        const DisclaimerBox(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottom: _stylePreview
          ? PrimaryButton(label: '返回', onPressed: () => context.pop())
          : PrimaryButton(
              label: '确认这一版全景',
              onPressed: _manifest == null ? null : _confirm,
            ),
    );
  }
}
