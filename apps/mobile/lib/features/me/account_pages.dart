import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import 'avatar.dart';

class AccountScaffold extends StatelessWidget {
  const AccountScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: AppColors.shadow),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _city;
  late final TextEditingController _bio;
  late String _avatarId;
  Uint8List? _customBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _name = TextEditingController(text: auth.displayName ?? '');
    _city = TextEditingController(text: auth.city ?? '');
    _bio = TextEditingController(text: auth.bio ?? '');
    _avatarId = auth.avatarId ?? 'orb';
    _customBytes = auth.avatarBytes;
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 72);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _customBytes = bytes;
      _avatarId = 'custom';
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final auth = ref.read(authProvider);
    final ok = await auth.updateProfile(
      displayName: _name.text,
      city: _city.text,
      bio: _bio.text,
      avatarId: _avatarId,
      avatarBytes: _avatarId == 'custom' ? _customBytes : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '资料已更新' : (auth.error ?? '保存失败'))),
    );
    if (ok) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _name.text.trim().isEmpty ? '主' : _name.text.trim().substring(0, 1);
    return AccountScaffold(
      title: '编辑个人资料',
      subtitle: '头像和称呼会显示在你的主页',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Center(
            child: Column(
              children: [
                AiAvatar(
                  size: 96,
                  avatarId: _avatarId,
                  initial: initial,
                  customBytes: _customBytes,
                  showCameraBadge: true,
                  onTap: _pickPhoto,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _pickPhoto,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('从相册更换头像'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('AI 头像风格', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('点选一组气质，或上面上传自己的照片。', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in avatarPresets)
                GestureDetector(
                  onTap: () => setState(() {
                    _avatarId = preset.id;
                    if (_avatarId != 'custom') _customBytes = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _avatarId == preset.id ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: AiAvatar(size: 52, avatarId: preset.id, initial: initial),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _LabeledField(label: '称呼', controller: _name, hint: '例如：小林', onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          _LabeledField(label: '所在城市', controller: _city, hint: '例如：杭州'),
          const SizedBox(height: 12),
          _LabeledField(label: '一句话简介', controller: _bio, hint: '例如：两居室 · 喜欢暖色', maxLines: 3),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(colors: [Color(0xFF24564C), Color(0xFF102E28)]),
                boxShadow: const [BoxShadow(color: Color(0x4014352F), blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _saving ? null : _save,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Text(
                      _saving ? '保存中…' : '保存资料',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      title: '关于我们',
      subtitle: '把房子聊清楚，再慢慢定下来',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _BrandCard(),
          const SizedBox(height: 16),
          const _InfoBlock(
            icon: Icons.home_outlined,
            title: '能帮你做什么',
            lines: [
              '聊聊怎么住、预算和不能动的地方',
              '按喜欢的风格看空间和全景',
              '上传自己的户型图，继续往下改',
            ],
          ),
          const SizedBox(height: 12),
          const _InfoBlock(
            icon: Icons.favorite_border,
            title: '我们怎么做',
            lines: [
              '一步一步确认，不一下子给你终稿',
              '不确定的地方会标明，方便你改',
              '方案可以保存，下次接着看',
            ],
          ),
          const SizedBox(height: 12),
          const _InfoBlock(
            icon: Icons.shield_outlined,
            title: '请你知道',
            lines: [
              '这里给出的是装修灵感，不是施工图',
              '涉及拆墙、水电、燃气时，请找专业人员到现场看',
              '最终怎么做，以你和施工方确认为准',
            ],
          ),
          const SizedBox(height: 22),
          Center(child: Text('版本 1.0.0', style: TextStyle(fontSize: 12, color: AppColors.muted))),
        ],
      ),
    );
  }
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _ctrl = TextEditingController();
  String _tag = '体验';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      title: '意见反馈',
      subtitle: '你的感受，我们会看',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _SoftLead(
            icon: Icons.edit_note_outlined,
            title: '哪里不顺，直接说',
            body: '一句话也行。我们会用来把下一次体验做得更清楚。',
          ),
          const SizedBox(height: 16),
          const Text('反馈类型', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final tag in ['体验', 'AI 回复', '全景', '上传', '其他'])
                ChoiceChip(
                  label: Text(tag),
                  selected: _tag == tag,
                  selectedColor: AppColors.primarySoft,
                  onSelected: (_) => setState(() => _tag = tag),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: '说说哪里不好用，或想加的小功能…',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                if (_ctrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('先写一点内容吧')));
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已收到「$_tag」反馈，谢谢')));
                context.pop();
              },
              child: const Text('提交反馈'),
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AccountScaffold(
      title: '隐私与协议',
      subtitle: '你的信息，只为帮你设计',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: const [
          _SoftLead(
            icon: Icons.lock_outline,
            title: '我们认真对待你的家',
            body: '户型、对话和资料只用来帮你做设计，不会拿去打广告或转给别人。',
          ),
          SizedBox(height: 14),
          _InfoBlock(
            icon: Icons.inventory_2_outlined,
            title: '会用到哪些信息',
            lines: [
              '你登录时留下的手机号或微信身份',
              '你填写的称呼、城市和简介',
              '你上传的户型图，以及聊过的装修想法',
            ],
          ),
          SizedBox(height: 12),
          _InfoBlock(
            icon: Icons.auto_awesome_outlined,
            title: '用来做什么',
            lines: [
              '记住你的房子，下次打开还能接着看',
              '按你的风格给出布局和空间建议',
              '在「我的」里显示你选好的头像和称呼',
            ],
          ),
          SizedBox(height: 12),
          _InfoBlock(
            icon: Icons.back_hand_outlined,
            title: '你可以怎么做',
            lines: [
              '随时修改称呼、城市和头像',
              '退出登录后，这台设备上不再保持登录',
              '方案仍在你的账号里，重新登录就能看到',
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14352F), Color(0xFF2C564C)],
        ),
        boxShadow: AppColors.shadow,
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0x33C6A36A),
            child: Icon(Icons.auto_awesome, color: Color(0xFFE8D5B0), size: 26),
          ),
          SizedBox(height: 12),
          Text('房屋设计助手', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text(
            '先聊清楚怎么住，再一起看风格和空间。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SoftLead extends StatelessWidget {
  const _SoftLead({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.icon, required this.title, required this.lines});
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.shadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          for (final line in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 5, color: AppColors.brass),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(line, style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.sub))),
              ],
            ),
            if (line != lines.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
