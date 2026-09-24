import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/page_chrome.dart';
import 'avatar.dart';

class MePage extends ConsumerStatefulWidget {
  const MePage({super.key});

  @override
  ConsumerState<MePage> createState() => _MePageState();
}

class _MePageState extends ConsumerState<MePage> {
  static const _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider).refreshProfile();
    });
  }

  String get _providerLabel {
    final auth = ref.read(authProvider);
    switch (auth.authProvider) {
      case 'wechat':
        return '微信登录';
      case 'phone':
        return '手机号登录';
      default:
        return '账号登录';
    }
  }

  Future<void> _clearCache() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            const Icon(Icons.cleaning_services_outlined, color: AppColors.primary, size: 28),
            const SizedBox(height: 10),
            const Text('清理本地缓存？', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('不会删掉你的房子和方案，只是清掉临时内容，打开会更干净。', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('清理'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await ref.read(authProvider).clearLocalCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('本地缓存已清理')));
  }

  Future<void> _copyVersion() async {
    await Clipboard.setData(const ClipboardData(text: '房屋设计助手 $_version'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('版本号已复制')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final name = (auth.displayName != null && auth.displayName!.isNotEmpty) ? auth.displayName! : '设计主人';
    final city = (auth.city != null && auth.city!.isNotEmpty) ? auth.city! : '未设置城市';
    final bio = (auth.bio != null && auth.bio!.isNotEmpty) ? auth.bio! : '还没写简介，点编辑补一句吧';
    final phone = auth.phoneMasked;
    final initial = name.isNotEmpty ? name.substring(0, 1) : '主';

    return Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _AiHeader(
            name: name,
            initial: initial,
            city: city,
            bio: bio,
            providerLabel: _providerLabel,
            phone: phone,
            avatarId: auth.avatarId ?? 'orb',
            avatarBytes: auth.avatarBytes,
            onEdit: () => context.push('/me/edit'),
            onAvatar: () => context.push('/me/edit'),
          ),
          const SizedBox(height: 14),
          _StatRow(
            onProjects: () => context.go('/projects'),
            onAi: () => context.go('/ai'),
            onDiscover: () => context.go('/discover'),
          ),
          const SizedBox(height: 8),
          _Section(
            title: '快捷入口',
            children: [
              _Tile(Icons.apartment_outlined, '我的房子', '继续当前方案', () => context.go('/projects')),
              _Tile(Icons.auto_awesome_outlined, '问问顾问', '独立 AI 对话', () => context.go('/ai')),
              _Tile(Icons.brush_outlined, '风格灵感', '本周封面与气质', () => context.go('/discover')),
            ],
          ),
          _Section(
            title: '偏好与通知',
            children: [
              _SwitchTile(
                icon: Icons.notifications_none_outlined,
                title: '方案进度提醒',
                hint: '方案有进展时提醒你',
                value: auth.notifyEnabled,
                onChanged: (v) => ref.read(authProvider).setNotifyEnabled(v),
              ),
              _Tile(Icons.cleaning_services_outlined, '清理缓存', '让页面打开更轻快', _clearCache),
            ],
          ),
          _Section(
            title: '帮助与关于',
            children: [
              _Tile(Icons.info_outline, '关于我们', '了解这款设计助手', () => context.push('/me/about')),
              _Tile(Icons.chat_bubble_outline, '意见反馈', '说说哪里不好用', () => context.push('/me/feedback')),
              _Tile(Icons.policy_outlined, '隐私与协议', '你的信息如何被使用', () => context.push('/me/privacy')),
              _Tile(Icons.verified_outlined, '当前版本', '版本 $_version', _copyVersion),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text('退出登录', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('下次进入需要重新登录', style: TextStyle(fontSize: 12)),
                onTap: () => ref.read(authProvider).logout(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 20, 32),
            child: Text(
              '装修建议仅供灵感参考，不代替设计师和施工方。',
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _AiHeader extends StatefulWidget {
  const _AiHeader({
    required this.name,
    required this.initial,
    required this.city,
    required this.bio,
    required this.providerLabel,
    required this.avatarId,
    required this.onEdit,
    required this.onAvatar,
    this.phone,
    this.avatarBytes,
  });

  final String name;
  final String initial;
  final String city;
  final String bio;
  final String providerLabel;
  final String avatarId;
  final String? phone;
  final Uint8List? avatarBytes;
  final VoidCallback onEdit;
  final VoidCallback onAvatar;

  @override
  State<_AiHeader> createState() => _AiHeaderState();
}

class _AiHeaderState extends State<_AiHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No nested Stack here: ListView gives unbounded height, and a Stack with only
    // Positioned children would assert size.isFinite.
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Container(
          width: double.infinity,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2A25), Color(0xFF1F4A40), Color(0xFF3E6258)],
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(198, 163, 106, 0.14 + t * 0.1),
                blurRadius: 48 + t * 12,
                offset: Offset(40 + t * 8, -12 - t * 6),
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Color.fromRGBO(255, 255, 255, 0.08 + t * 0.06),
                blurRadius: 36 + t * 8,
                offset: Offset(-36 - t * 6, 28 + t * 4),
                spreadRadius: -6,
              ),
            ],
          ),
          child: child,
        );
      },
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: const Color(0x55C6A36A)),
                      color: const Color(0x22FFFFFF),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 14, color: Color(0xFFE8D5B0)),
                        SizedBox(width: 6),
                        Text('AI 空间顾问 · 我的', style: TextStyle(color: Color(0xFFE8D5B0), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0x28FFFFFF),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('编辑资料', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AiAvatar(
                    size: 68,
                    avatarId: widget.avatarId,
                    initial: widget.initial,
                    customBytes: widget.avatarBytes,
                    showCameraBadge: true,
                    onTap: widget.onAvatar,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(widget.bio, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13, height: 1.35)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Chip(icon: Icons.location_on_outlined, label: widget.city),
                            _Chip(icon: Icons.verified_user_outlined, label: widget.providerLabel),
                            if (widget.phone != null && widget.phone!.isNotEmpty) _Chip(icon: Icons.phone_iphone, label: widget.phone!),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x22FFFFFF),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xE0FFFFFF)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Color(0xE0FFFFFF), fontSize: 11)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.onProjects, required this.onAi, required this.onDiscover});
  final VoidCallback onProjects;
  final VoidCallback onAi;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _StatCard(Icons.home_work_outlined, '方案', '继续设计', onProjects)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(Icons.psychology_alt_outlined, '顾问', '随时聊', onAi)),
          const SizedBox(width: 10),
          Expanded(child: _StatCard(Icons.palette_outlined, '风格', '逛一逛', onDiscover)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.icon, this.title, this.hint, this.onTap);
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(hint, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 54, color: AppColors.line),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.icon, this.title, this.hint, this.onTap);
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      activeThumbColor: Colors.white,
      activeTrackColor: AppColors.primary,
    );
  }
}
