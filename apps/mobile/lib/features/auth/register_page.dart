import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/design_widgets.dart';
import 'auth_chrome.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _agreed = false;
  bool _sending = false;
  String? _hint;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authProvider);
    if (auth.busy) return;
    final phone = _phone.text.replaceAll(RegExp(r'\s+'), '');
    if (!_agreed) {
      setState(() => _hint = '请先勾选协议');
      return;
    }
    if (phone.length != 11) {
      setState(() => _hint = '请输入 11 位手机号');
      return;
    }
    if (_code.text.trim().length != 6) {
      setState(() => _hint = '请先获取验证码');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _hint = '密码至少 6 位');
      return;
    }
    setState(() => _hint = null);
    await auth.register(phone, _code.text.trim(), _password.text);
  }

  Future<void> _requestCode() async {
    final phone = _phone.text.replaceAll(RegExp(r'\s+'), '');
    if (phone.length != 11) {
      setState(() => _hint = '请输入 11 位手机号');
      return;
    }
    setState(() {
      _sending = true;
      _hint = null;
    });
    try {
      final body = await ApiClient().requestSms(phone);
      if (!mounted) return;
      final code = body['dev_code'];
      setState(() {
        if (code is String && code.isNotEmpty) {
          _code.text = code;
          _hint = '本地模拟，验证码已填入';
        } else {
          _hint = '验证码已签发，请查看服务端日志';
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _hint = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: AppColors.page,
      body: Column(
        children: [
          AuthHero(
            title: '创建账号',
            subtitle: '登记一套房子，方案和对话都留在这里。',
            leading: IconButton(
              onPressed: () => context.pop(),
              style: IconButton.styleFrom(backgroundColor: const Color(0x33FFFFFF), foregroundColor: Colors.white),
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            ),
          ),
          Expanded(
            child: AuthSheet(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Column(
                        children: [
                          const Align(alignment: Alignment.centerLeft, child: Text('先告诉我，怎么称呼你', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                          const SizedBox(height: 4),
                          const Align(alignment: Alignment.centerLeft, child: Text('注册后 AI 会记住你的户型和偏好。', style: TextStyle(fontSize: 12, color: AppColors.muted))),
                          const SizedBox(height: 16),
                          AuthField(controller: _name, hint: '怎么称呼你', icon: Icons.person_outline, keyboard: TextInputType.name),
                          const SizedBox(height: 12),
                          AuthField(controller: _phone, hint: '手机号', icon: Icons.phone_iphone, keyboard: TextInputType.phone),
                          const SizedBox(height: 12),
                          AuthField(
                            controller: _code,
                            hint: '验证码',
                            icon: Icons.sms_outlined,
                            keyboard: TextInputType.number,
                            trailing: TextButton(onPressed: _sending ? null : _requestCode, child: Text(_sending ? '发送中' : '获取')),
                          ),
                          const SizedBox(height: 12),
                          AuthField(controller: _password, hint: '设置密码，至少 6 位', icon: Icons.lock_outline, keyboard: TextInputType.visiblePassword, obscure: true),
                          Row(
                            children: [
                              Checkbox(value: _agreed, onChanged: (value) => setState(() => _agreed = value ?? false), activeColor: AppColors.primary, visualDensity: VisualDensity.compact),
                              const Expanded(child: Text('同意协议。AI 输出不构成结构、施工结论。', style: TextStyle(fontSize: 12, color: AppColors.sub, height: 1.4))),
                            ],
                          ),
                          if (_hint != null || auth.error != null)
                            Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_hint ?? auth.error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)))),
                          PrimaryButton(label: auth.busy ? '注册中' : '注册并进入', icon: Icons.home_outlined, onPressed: auth.busy ? null : _submit),
                          TextButton(onPressed: () => context.pop(), child: const Text('已有账号，去登录')),
                        ],
                      ),
                    ),
                  ),
                  const SafeArea(top: false, child: AuthWarmFooter()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
