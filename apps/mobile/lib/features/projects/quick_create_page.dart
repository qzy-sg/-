import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/floor_plan_pick.dart';
import '../../core/quick_design.dart';
import '../discover/style_catalog.dart';

/// 方案 B：上传户型 → 只读预览 → 选风格 → 效果图 + VR
class QuickCreatePage extends ConsumerStatefulWidget {
  const QuickCreatePage({super.key, this.initialStyleId});

  final String? initialStyleId;

  @override
  ConsumerState<QuickCreatePage> createState() => _QuickCreatePageState();
}

class _QuickCreatePageState extends ConsumerState<QuickCreatePage> {
  String? _styleId;
  Uint8List? _bytes;
  String _fileName = 'floorplan.jpg';
  String _contentType = 'image/jpeg';
  FloorPlanPreview? _preview;
  bool _busy = false;
  String _phase = '';
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialStyleId;
    if (initial != null && styleById(initial) != null) {
      _styleId = initial;
    } else {
      _styleId = 'cream';
    }
  }

  HouseStyle? get _style => styleById(_styleId ?? '');
  bool get _hasPreview => _preview != null && _preview!.rooms.isNotEmpty;

  Future<void> _pickPlan([String? prefer]) async {
    if (_busy) return;
    final picked = await pickFloorPlan(context, prefer: prefer);
    if (picked == null || !mounted) return;
    setState(() {
      _bytes = picked.bytes;
      _fileName = picked.name;
      _contentType = picked.contentType;
      _preview = null;
      _error = null;
    });
  }

  Future<void> _recognize() async {
    if (_busy) return;
    if (_bytes == null || _bytes!.isEmpty) {
      setState(() => _error = '先上传户型图');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _phase = '开始识别…';
      _progress = 0.04;
    });
    try {
      final preview = await runFloorPlanPreview(
        client: ApiClient(token: ref.read(authProvider).token),
        imageBytes: _bytes!,
        imageName: _fileName,
        contentType: _contentType,
        projectId: _preview?.projectId,
        onProgress: (label, value) {
          if (!mounted) return;
          setState(() {
            _phase = label;
            _progress = value;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _busy = false;
        _phase = '';
        _progress = 0;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _busy = false;
        _preview = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '没能读出户型，换一张更清晰的图试试';
        _busy = false;
        _preview = null;
      });
    }
  }

  Future<void> _generate() async {
    if (_busy) return;
    final preview = _preview;
    if (preview == null) {
      setState(() => _error = '请先识别户型');
      return;
    }
    if (_styleId == null) {
      setState(() => _error = '先选一个喜欢的风格');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _phase = '开始生成…';
      _progress = 0.04;
    });
    try {
      final style = _style;
      final result = await runDesignFromPreview(
        client: ApiClient(token: ref.read(authProvider).token),
        projectId: preview.projectId,
        styleName: style?.name,
        styleId: _styleId,
        onProgress: (label, value) {
          if (!mounted) return;
          setState(() {
            _phase = label;
            _progress = value;
          });
        },
      );
      if (!mounted) return;
      final q = <String>[
        if (result.versionId != null && result.versionId!.isNotEmpty) 'versionId=${result.versionId}',
        if (_styleId != null && _styleId!.isNotEmpty) 'style=$_styleId',
      ].join('&');
      final suffix = q.isEmpty ? '' : '?$q';
      if (result.sceneId != null && result.sceneId!.isNotEmpty) {
        context.go('/projects/${result.projectId}/scene$suffix');
      } else {
        context.go('/projects/${result.projectId}/renders$suffix');
      }
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '没能完成，请重试';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final style = _style;
    final preview = _preview;

    return Scaffold(
      backgroundColor: AppColors.page,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F1EE), Color(0xFFF6F3EE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _busy ? null : () => context.pop(),
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppColors.shadow),
                        child: const Icon(Icons.arrow_back_ios_new, size: 16),
                      ),
                    ),
                    const Expanded(
                      child: Text('直传图纸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    Text(
                      _hasPreview ? '确认读到的户型，再选风格' : '上传户型图',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hasPreview
                          ? '下面是自动提取结果，不用手改。不对就换图重识。'
                          : '只根据户型图提取房间，不填面积和备注。',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    const Text('1. 户型图', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    const Text('必传。支持相册、拍照、文件。', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    if (_bytes == null)
                      Row(
                        children: [
                          Expanded(child: _SourceBtn(icon: Icons.photo_library_outlined, label: '相册', onTap: _busy ? null : () => _pickPlan('gallery'))),
                          const SizedBox(width: 8),
                          Expanded(child: _SourceBtn(icon: Icons.photo_camera_outlined, label: '拍照', onTap: _busy ? null : () => _pickPlan('camera'))),
                          const SizedBox(width: 8),
                          Expanded(child: _SourceBtn(icon: Icons.folder_open_outlined, label: '文件', onTap: _busy ? null : () => _pickPlan('file'))),
                        ],
                      )
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: AspectRatio(
                              aspectRatio: 1.6,
                              child: Image.memory(_bytes!, fit: BoxFit.cover),
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Row(
                              children: [
                                _MiniChip(
                                  label: '更换',
                                  onTap: _busy
                                      ? null
                                      : () async {
                                          await _pickPlan();
                                        },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (_hasPreview && preview != null) ...[
                      const SizedBox(height: 20),
                      const Text('2. 识别结果', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      const Text('只读预览，无需勾选确认。', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(preview.headline, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                            if (preview.note != null) ...[
                              const SizedBox(height: 6),
                              Text(preview.note!, style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35)),
                            ],
                            const SizedBox(height: 12),
                            for (final room in preview.rooms) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${room['name'] ?? '房间'}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      room['area_sqm'] is num ? '${room['area_sqm']}㎡' : '',
                                      style: const TextStyle(fontSize: 13, color: AppColors.sub),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            TextButton(
                              onPressed: _busy ? null : _recognize,
                              child: const Text('不对，换图重识'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('3. 喜欢的风格', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 108,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: houseStyles.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final item = houseStyles[index];
                            final selected = item.id == _styleId;
                            return GestureDetector(
                              onTap: _busy ? null : () => setState(() => _styleId = item.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 2 : 1),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.asset(item.image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.primary)),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withValues(alpha: selected ? 0.6 : 0.45)],
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      const Positioned(right: 8, top: 8, child: Icon(Icons.check_circle, color: Colors.white, size: 18)),
                                    Align(
                                      alignment: Alignment.bottomLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (style != null) ...[
                        const SizedBox(height: 8),
                        Text(style.hint, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 18),
                      Text(_phase, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: _progress.clamp(0.05, 1),
                          minHeight: 6,
                          color: AppColors.primary,
                          backgroundColor: AppColors.chip,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF8AA39C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy
                        ? null
                        : _hasPreview
                            ? _generate
                            : (_bytes == null ? null : _recognize),
                    child: Text(
                      _busy
                          ? (_hasPreview ? '正在生成…' : '正在识别…')
                          : (_hasPreview ? '生成效果图与环视' : '识别户型'),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceBtn extends StatelessWidget {
  const _SourceBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ),
    );
  }
}
