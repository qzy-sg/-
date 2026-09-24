import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/design_widgets.dart';
import '../../core/page_chrome.dart';
import 'layout_catalog.dart';

/// 布局方向：像已上线装修 App 一样，先看 2～3 种住法，点选后直接出效果。
class LayoutsPage extends ConsumerStatefulWidget {
  const LayoutsPage({super.key, required this.projectId, this.options = const []});
  final String projectId;
  final List<Map<String, dynamic>> options;

  @override
  ConsumerState<LayoutsPage> createState() => _LayoutsPageState();
}

class _LayoutsPageState extends ConsumerState<LayoutsPage> {
  late List<Map<String, dynamic>> _options;
  String? _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _options = normalizeLayoutOptions(widget.options);
    _selected = _options.isEmpty ? null : '${_options.first['id']}';
  }

  Future<void> _save() async {
    Map<String, dynamic>? picked;
    for (final item in _options) {
      if ('${item['id']}' == _selected) {
        picked = item;
        break;
      }
    }
    if (picked == null) return;
    final choice = picked;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      Future<Map<String, dynamic>> save() => client.saveDraft(
            widget.projectId,
            confirmed: true,
            title: '${choice['title'] ?? '住法'} · AI 方案',
            summary: '${choice['summary'] ?? choice['vibe'] ?? ''}',
            options: [choice],
          );
      Map<String, dynamic> draft;
      try {
        draft = await save();
      } on ApiException catch (err) {
        // 还没确认过户型时，先自动铺一套常见房间，再保存住法。
        if (err.code != 'CONFIRMATION_REQUIRED') rethrow;
        await client.seedRooms(widget.projectId);
        draft = await save();
      }
      final versionId = '${draft['id'] ?? ''}'.trim();
      if (versionId.isNotEmpty) {
        await client.confirmVersion(widget.projectId, versionId);
      }
      if (!mounted) return;
      final q = versionId.isEmpty ? '' : '?versionId=$versionId';
      context.go('/projects/${widget.projectId}/renders$q');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '没能记下这一版，请重试';
        _saving = false;
      });
    }
  }

  void _reshuffle() {
    final next = List<Map<String, dynamic>>.from(defaultLayoutDirections)..shuffle();
    setState(() {
      _options = next;
      _selected = '${next.first['id']}';
      _error = null;
    });
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
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
                child: Row(
                  children: [
                    const CircleBackButton(),
                    const Expanded(
                      child: Text('住法方向', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                      onPressed: _saving ? null : _reshuffle,
                      child: const Text('换一批', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 4),
                    const AiMark(size: 40),
                  ],
                ),
              ),
              Expanded(
                child: _saving
                    ? const AiBusy(message: '正在生成效果…', hint: '记下这一版住法')
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        children: [
                          const RevealIn(
                            child: PageHeroTitle(
                              title: 'AI 为你想了几种住法',
                              subtitle: '先选一个大方向，细节之后还能改。选中后直接看效果图。',
                            ),
                          ),
                          const SizedBox(height: 20),
                          for (var i = 0; i < _options.length; i++) ...[
                            RevealIn(
                              delay: Duration(milliseconds: 60 + i * 50),
                              child: _DirectionCard(
                                index: i,
                                option: _options[i],
                                selected: _selected == '${_options[i]['id']}',
                                onTap: () => setState(() => _selected = '${_options[i]['id']}'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 4),
                            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                          ],
                        ],
                      ),
              ),
              SoftBottomBar(
                child: Column(
                  children: [
                    const Text(
                      '仅供灵感，不是施工图，也不保证真实尺寸。',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 10),
                    PrimaryButton(
                      label: '就按这个，看效果图',
                      icon: Icons.auto_awesome_outlined,
                      onPressed: _selected == null || _saving ? null : _save,
                    ),
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

class _DirectionCard extends StatelessWidget {
  const _DirectionCard({
    required this.index,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final Map<String, dynamic> option;
  final bool selected;
  final VoidCallback? onTap;

  static const _accents = [
    Color(0xFF1F4A42),
    Color(0xFF3D5A4C),
    Color(0xFF2A3F4A),
  ];

  @override
  Widget build(BuildContext context) {
    final title = '${option['title'] ?? '住法'}';
    final vibe = '${option['vibe'] ?? ''}';
    final summary = '${option['summary'] ?? ''}';
    final tags = option['tags'] is List ? (option['tags'] as List).map((e) => '$e').where((e) => e.isNotEmpty).toList() : const <String>[];
    final highlights = option['highlights'] is List
        ? (option['highlights'] as List).map((e) => '$e').where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final accent = _accents[index % _accents.length];

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, (1 - value) * 14), child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 1.8 : 1),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : AppColors.shadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 108,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent,
                              Color.lerp(accent, AppColors.brass, 0.35)!,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: -20,
                        top: -30,
                        child: Transform.rotate(
                          angle: -math.pi / 8,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '方向 ${index + 1}',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.1),
                                  ),
                                  if (vibe.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      vibe,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12, height: 1.2),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? AppColors.brass : Colors.white.withValues(alpha: 0.18),
                              ),
                              child: Icon(
                                selected ? Icons.check : Icons.circle_outlined,
                                size: 16,
                                color: selected ? AppColors.ink : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (summary.isNotEmpty)
                          Text(summary, style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.45)),
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final tag in tags.take(4))
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: selected ? AppColors.primarySoft : AppColors.chip,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? AppColors.primary : AppColors.sub,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (highlights.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          for (final line in highlights.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(Icons.north_east, size: 13, color: AppColors.brass),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(line, style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.35)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
