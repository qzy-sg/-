import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/page_chrome.dart';
import '../../core/project_entry.dart';

class ProjectListPage extends ConsumerStatefulWidget {
  const ProjectListPage({super.key});

  @override
  ConsumerState<ProjectListPage> createState() => _ProjectListPageState();
}

class _ProjectListPageState extends ConsumerState<ProjectListPage> {
  List<_House> _projects = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  Future<void> _sync() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiClient(token: ref.read(authProvider).token).listProjects();
      if (!mounted) return;
      setState(() {
        _projects = [
          for (final item in items)
            if (item is Map) _House.fromJson(Map<String, dynamic>.from(item)),
        ];
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
        _error = '加载失败，下拉或点右上角重试';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    await context.push('/projects/new');
    if (mounted) _sync();
  }

  Future<void> _deleteHouse(_House house) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这套方案？'),
        content: Text('「${house.title}」删掉后不能恢复。'),
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
      await ApiClient(token: ref.read(authProvider).token).deleteProject(house.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('已删除')));
      await _sync();
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
    final focus = _projects.isEmpty ? null : _projects.first;

    return Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _sync,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                    child: RevealIn(
                      child: PageHeroTitle(
                        title: '房子',
                        subtitle: _loading ? '正在整理…' : '一套一套推进，不着急一次做完',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AiMark(size: 40),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: '新建房子',
                              onPressed: _create,
                              icon: Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Color(0x3314352F), blurRadius: 12, offset: Offset(0, 4))],
                                ),
                                child: const Icon(Icons.add, color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AiBusy(message: '正在整理房子…'),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, style: const TextStyle(color: AppColors.danger)),
                          TextButton(onPressed: _sync, child: const Text('重试')),
                        ],
                      ),
                    ),
                  )
                else if (_projects.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyHouse(onCreate: _create),
                  )
                else ...[
                  if (focus != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                        child: _FocusCard(
                          house: focus,
                          onTap: () => openProjectSmart(context, ref, focus.id),
                          onManage: () => openProjectSmart(context, ref, focus.id, manage: true),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          const Text('全部房子', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text('${_projects.length}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: _projects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final house = _projects[index];
                        return _HouseRow(
                          house: house,
                          onTap: () => openProjectSmart(context, ref, house.id),
                          onManage: () => openProjectSmart(context, ref, house.id, manage: true),
                          onDelete: () => _deleteHouse(house),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _House {
  const _House({
    required this.id,
    required this.title,
    required this.city,
    required this.active,
    required this.hasVersion,
    required this.updatedLabel,
  });

  factory _House.fromJson(Map<String, dynamic> raw) {
    final status = '${raw['status'] ?? 'active'}';
    final city = '${raw['city'] ?? ''}'.trim();
    final hasVersion = '${raw['current_design_version_id'] ?? ''}'.isNotEmpty;
    final updated = DateTime.tryParse('${raw['updated_at'] ?? ''}');
    return _House(
      id: '${raw['id'] ?? ''}',
      title: '${raw['name'] ?? '未命名'}',
      city: city,
      active: status != 'archived',
      hasVersion: hasVersion,
      updatedLabel: _ago(updated),
    );
  }

  final String id;
  final String title;
  final String city;
  final bool active;
  final bool hasVersion;
  final String updatedLabel;

  int get step => hasVersion ? 3 : 1;

  String get nextLabel {
    if (!active) return '查看成果';
    if (hasVersion) return '看方案与全景';
    return '从户型开始';
  }

  String get meta {
    final parts = <String>[
      if (city.isNotEmpty) city,
      active ? '进行中' : '已归档',
      updatedLabel,
    ];
    return parts.join(' · ');
  }
}

String _ago(DateTime? time) {
  if (time == null) return '刚刚';
  final delta = DateTime.now().difference(time);
  if (delta.inMinutes < 1) return '刚刚';
  if (delta.inHours < 1) return '${delta.inMinutes} 分钟前';
  if (delta.inDays < 1) return '${delta.inHours} 小时前';
  if (delta.inDays < 7) return '${delta.inDays} 天前';
  return '${time.month}/${time.day}';
}

class _EmptyHouse extends StatelessWidget {
  const _EmptyHouse({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(0xFF1B3F38), Color(0xFFC6A36A)]),
            ),
            child: const Icon(Icons.home_work_outlined, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('还没有房子', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            '建一套，再慢慢传户型、看方案。\n随时可以从这一步继续。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onCreate,
            child: const Text('新建一套', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.house, required this.onTap, required this.onManage});
  final _House house;
  final VoidCallback onTap;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF101614), Color(0xFF1B3F38), Color(0xFFC6A36A)],
            ),
            boxShadow: const [BoxShadow(color: Color(0x3314352F), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      house.hasVersion ? '可查看' : '接着做',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onManage,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xE6FFFFFF),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('管理', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(house.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(house.nextLabel, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
              const SizedBox(height: 16),
              _StepDots(step: house.step, light: true),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onTap,
                  child: Text(house.hasVersion ? '查看' : '继续', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseRow extends StatelessWidget {
  const _HouseRow({required this.house, required this.onTap, required this.onManage, required this.onDelete});
  final _House house;
  final VoidCallback onTap;
  final VoidCallback onManage;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: house.active
                        ? const [Color(0xFF1B3F38), Color(0xFF6F8F82)]
                        : const [Color(0xFF8C908C), Color(0xFFC8C4BC)],
                  ),
                ),
                child: const Icon(Icons.apartment_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(house.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(house.meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    _StepDots(step: house.step, light: false),
                  ],
                ),
              ),
              IconButton(
                tooltip: '管理',
                onPressed: onManage,
                icon: const Icon(Icons.tune_rounded, size: 20, color: AppColors.muted),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.light});
  final int step;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 4; i++) ...[
          if (i > 1) const SizedBox(width: 4),
          Container(
            width: i <= step ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: i <= step
                  ? (light ? Colors.white : AppColors.primary)
                  : (light ? const Color(0x44FFFFFF) : AppColors.line),
            ),
          ),
        ],
      ],
    );
  }
}
