import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/design_widgets.dart';
import '../../core/page_chrome.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  Map<String, dynamic>? _project;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiClient(token: ref.read(authProvider).token).getProject(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = data;
        _loading = false;
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
        _error = '打开失败，请重试';
        _loading = false;
      });
    }
  }

  String get _name => '${_project?['name'] ?? '我的房子'}';
  String get _city => '${_project?['city'] ?? ''}'.trim();
  bool get _hasVersion => '${_project?['current_design_version_id'] ?? ''}'.isNotEmpty;
  int get _step => _hasVersion ? 3 : 1;

  String get _subtitle {
    final parts = <String>[
      if (_city.isNotEmpty) _city,
      _hasVersion ? '已有方案' : '刚起步',
    ];
    return parts.join(' · ');
  }

  String get _suggestTitle => _hasVersion ? '看一看这一版' : '一键看到设计';
  String get _suggestHint => _hasVersion ? '效果图或全景，选一个就好' : '先上传户型图，看清识别结果再选风格';
  String get _suggestPath => _hasVersion
      ? '/projects/${widget.projectId}/scene'
      : '/projects/${widget.projectId}/upload';
  String get _suggestLabel => _hasVersion ? '看全景' : '传户型';

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这套方案？'),
        content: Text('「$_name」删掉后不能恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ApiClient(token: ref.read(authProvider).token).deleteProject(widget.projectId);
      if (!mounted) return;
      context.go('/projects');
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(err.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('删除失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.projectId;
    final steps = [
      _Step(
        index: 1,
        title: '准备',
        hint: '轻填资料，放上户型',
        actions: [
          _Action('资料', '/projects/$id/profile', Icons.edit_outlined),
          _Action('户型图', '/projects/$id/upload', Icons.upload_outlined),
        ],
      ),
      _Step(
        index: 2,
        title: '识别',
        hint: 'AI 读完一键采用',
        actions: [
          _Action('看识别', '/projects/$id/analysis', Icons.grid_view_outlined),
          _Action('去对话', '/projects/$id/chat', Icons.chat_bubble_outline),
        ],
      ),
      _Step(
        index: 3,
        title: '方案',
        hint: '选住法，再出效果',
        actions: [
          _Action('住法', '/projects/$id/layouts', Icons.auto_awesome_outlined),
          _Action('看版本', '/projects/$id/versions', Icons.layers_outlined),
        ],
      ),
      _Step(
        index: 4,
        title: '成果',
        hint: '效果图与环视',
        actions: [
          _Action('效果图', '/projects/$id/renders', Icons.image_outlined),
          _Action('全景', '/projects/$id/scene', Icons.threesixty_outlined),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: SafeArea(
          child: _loading
              ? const AiBusy(message: '打开这套房子…')
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: AppColors.danger)),
                          TextButton(onPressed: _load, child: const Text('重试')),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                      children: [
                        Row(
                          children: [
                            CircleBackButton(onPressed: () => context.go('/projects')),
                            const Spacer(),
                            IconButton(
                              tooltip: '删除方案',
                              onPressed: _delete,
                              icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Text('第 $_step / 4 步', style: const TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                              const SizedBox(height: 4),
                              Text(_subtitle, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SuggestBanner(
                          title: _suggestTitle,
                          hint: _suggestHint,
                          label: _suggestLabel,
                          onTap: () => context.push(_suggestPath),
                        ),
                        const SizedBox(height: 22),
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 10),
                          child: Text('调整某一步', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sub)),
                        ),
                        _FeatureList(steps: steps, current: _step),
                        const SizedBox(height: 8),
                        const DisclaimerBox(),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _Action {
  const _Action(this.label, this.path, this.icon);
  final String label;
  final String path;
  final IconData icon;
}

class _Step {
  const _Step({required this.index, required this.title, required this.hint, required this.actions});
  final int index;
  final String title;
  final String hint;
  final List<_Action> actions;
}

class _SuggestBanner extends StatelessWidget {
  const _SuggestBanner({
    required this.title,
    required this.hint,
    required this.label,
    required this.onTap,
  });

  final String title;
  final String hint;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101614), Color(0xFF1B3F38), Color(0xFFC6A36A)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x3314352F), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.white, size: 15),
              SizedBox(width: 6),
              Text('现在可以做', style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onTap,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.steps, required this.current});
  final List<_Step> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final step in steps) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Text(step.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sub)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(step.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                  if (step.index == current)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
                      child: const Text('当前', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            for (final action in step.actions)
              InkWell(
                onTap: () => context.push(action.path),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Row(
                    children: [
                      Icon(action.icon, size: 20, color: step.index == current ? AppColors.primary : AppColors.sub),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(action.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.chevron_right, size: 20, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            if (step != steps.last) const Divider(height: 1, color: AppColors.line),
          ],
        ],
      ),
    );
  }
}
