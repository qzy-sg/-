import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/design_widgets.dart';
import '../../core/page_chrome.dart';
import '../../core/project_entry.dart';

/// 手动建房资料：少填、智能默认，不做一条条核对。
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _name = TextEditingController();
  double _area = 89;
  String _type = '商品房';
  String _facing = '南';
  bool _busy = false;
  String? _error;

  static const _areaPresets = [60.0, 89.0, 110.0, 140.0];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      final name = _name.text.trim().isEmpty ? '我的房子' : _name.text.trim();
      final id = widget.projectId ?? '${(await client.createProject(name))['id']}';
      await saveProjectEntryMode(id, ProjectEntryMode.guided);
      await client.saveProfile(id, {
        'house_type': _type,
        'area_sqm': _area,
        'orientation': _facing,
        'household_notes': 'AI 帮做 · $_type · ${_facing}向',
        'constraints': ['不改动未知承重区域'],
      });
      if (!mounted) return;
      context.push('/projects/$id/upload');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '没能保存，请重试';
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
                    Expanded(child: Text('AI 帮做', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    AiMark(size: 40),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    const PageHeroTitle(
                      title: '先告诉我大概情况',
                      subtitle: '不用填全。面积和类型够用，其余交给识别。',
                    ),
                    const SizedBox(height: 20),
                    _Block(
                      title: '怎么称呼这套房子',
                      child: TextField(
                        controller: _name,
                        enabled: !_busy,
                        decoration: const InputDecoration(
                          hintText: '可不填，默认「我的房子」',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Block(
                      title: '大概面积',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_area.round()} ㎡',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                          ),
                          Slider(
                            value: _area.clamp(40, 200),
                            min: 40,
                            max: 200,
                            divisions: 32,
                            activeColor: AppColors.primary,
                            onChanged: _busy ? null : (v) => setState(() => _area = v.roundToDouble()),
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final preset in _areaPresets)
                                ChoiceChip(
                                  label: Text('${preset.round()}㎡'),
                                  selected: (_area - preset).abs() < 0.5,
                                  showCheckmark: false,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: (_area - preset).abs() < 0.5 ? Colors.white : AppColors.sub,
                                  ),
                                  onSelected: _busy ? null : (_) => setState(() => _area = preset),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Block(
                      title: '房子类型',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in const ['商品房', '公寓', '老房', '自建房'])
                            _Chip(
                              label: item,
                              selected: _type == item || (_type == '老房/二手房' && item == '老房'),
                              onTap: _busy
                                  ? null
                                  : () => setState(() => _type = item == '老房' ? '老房/二手房' : item),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _Block(
                      title: '主要朝向',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in const ['南', '东南', '东', '北', '不确定'])
                            _Chip(
                              label: item,
                              selected: _facing == item,
                              onTap: _busy ? null : () => setState(() => _facing = item),
                            ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              SoftBottomBar(
                child: PrimaryButton(
                  label: _busy ? '准备中…' : '下一步，放户型图',
                  onPressed: _busy ? null : _continue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: AppColors.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sub)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.chip,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.sub,
            ),
          ),
        ),
      ),
    );
  }
}
