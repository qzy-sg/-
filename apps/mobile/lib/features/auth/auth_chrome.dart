import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class AuthAtmosphere extends StatefulWidget {
  const AuthAtmosphere({super.key});

  @override
  State<AuthAtmosphere> createState() => _AuthAtmosphereState();
}

class _AuthAtmosphereState extends State<AuthAtmosphere> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(painter: _GlowPainter(_controller.value)),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C1210), Color(0xFF173830), Color(0xFF6A5E4C)],
        ).createShader(rect),
    );

    void orb(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final wave = math.sin(t * math.pi * 2);
    final wave2 = math.cos(t * math.pi * 2);
    orb(Offset(size.width * (0.78 + 0.06 * wave), size.height * (0.46 + 0.04 * wave2)), 150, const Color(0x66C6A36A));
    orb(Offset(size.width * (0.18 + 0.04 * wave2), size.height * (0.78 + 0.03 * wave)), 120, const Color(0x55308A78));

    final line = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final shift = 10 * wave;
    final plan = Path()
      ..moveTo(28, size.height * 0.5 + shift)
      ..lineTo(size.width * 0.62, size.height * 0.5 + shift)
      ..lineTo(size.width * 0.62, size.height * 0.72 + shift)
      ..lineTo(size.width * 0.28, size.height * 0.72 + shift)
      ..lineTo(size.width * 0.28, size.height * 0.58 + shift);
    canvas.drawPath(plan, line);
    canvas.drawLine(Offset(size.width * 0.28, size.height * 0.58 + shift), Offset(size.width * 0.46, size.height * 0.58 + shift), line);

    final dot = Paint()..color = const Color(0xE6C6A36A);
    for (var i = 0; i < 8; i++) {
      final phase = (t * 1.6 + i * 0.13) % 1;
      final x = size.width * ((i * 0.17) % 1);
      final y = -30 + phase * (size.height + 80);
      final head = Offset(x + y * 0.28, y);
      final tail = Offset(head.dx - 54, head.dy - 78);
      final streak = Paint()
        ..shader = const LinearGradient(colors: [Color(0x00FFFFFF), Color(0xFFFFF4D8)]).createShader(Rect.fromPoints(tail, head))
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tail, head, streak);
      canvas.drawCircle(head, 1.7, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) => oldDelegate.t != t;
}

class AuthMark extends StatelessWidget {
  const AuthMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(20)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: AppColors.brass, size: 14),
          SizedBox(width: 6),
          Text('AI 房屋设计', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class AuthAiChip extends StatelessWidget {
  const AuthAiChip(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0x28FFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x40FFFFFF))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.brass),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.keyboard,
    this.trailing,
    this.obscure = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboard;
  final Widget? trailing;
  final bool obscure;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFCFBF8), Color(0xFFF3F7F5)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x0C14352F), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: trailing,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: Color(0x33C6A36A))),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(18)), borderSide: BorderSide(color: AppColors.primary, width: 1.2)),
        ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: _FadeLine(fadeRight: false)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 12, color: AppColors.brass),
                SizedBox(width: 4),
                Text('或', style: TextStyle(fontSize: 12, color: AppColors.sub, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(child: _FadeLine(fadeRight: true)),
        ],
      ),
    );
  }
}

class _FadeLine extends StatelessWidget {
  const _FadeLine({required this.fadeRight});
  final bool fadeRight;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: fadeRight
              ? const [Color(0x66C6A36A), Color(0x00C6A36A)]
              : const [Color(0x00C6A36A), Color(0x66C6A36A)],
        ),
      ),
    );
  }
}

class AuthWarmFooter extends StatelessWidget {
  const AuthWarmFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(22, 2, 22, 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 13, color: AppColors.brass),
              SizedBox(width: 6),
              Text('装修可以慢慢来', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '先把灯选暖，沙发对着光，厨房留一张能一起吃饭的桌子。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.sub, height: 1.5),
          ),
          SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag('客厅暖灯'),
              _Tag('一起做饭'),
              _Tag('玄关放包'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(colors: [Color(0xFFF8F3EA), Color(0xFFEEF5F2)]),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
    );
  }
}

class AuthSheet extends StatelessWidget {
  const AuthSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -28),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFCF8), Color(0xFFF4EFE6)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [BoxShadow(color: Color(0x140F1C18), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: child,
      ),
    );
  }
}

class AuthHero extends StatelessWidget {
  const AuthHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
  });

  final String title;
  final String subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.42,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AuthAtmosphere(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      ?leading,
                      if (leading != null) const SizedBox(width: 8),
                      const AuthMark(),
                    ],
                  ),
                ),
                const Spacer(),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, height: 1.05)),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 14)),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AuthAiChip(Icons.auto_awesome, 'AI 读户型'),
                    AuthAiChip(Icons.chat_bubble_outline, '一起聊布局'),
                    AuthAiChip(Icons.threesixty_outlined, '看效果与全景'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WechatAuthButton extends StatelessWidget {
  const WechatAuthButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.78,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(colors: [Color(0xFF22C964), Color(0xFF07A352)]),
          boxShadow: const [BoxShadow(color: Color(0x2607C160), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: const SizedBox(
              height: 52,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wechat, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('微信一键授权登录', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WechatAuthSheet extends StatelessWidget {
  const WechatAuthSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 18),
          const CircleAvatar(radius: 26, backgroundColor: Color(0xFF07C160), child: Icon(Icons.wechat, color: Colors.white, size: 28)),
          const SizedBox(height: 12),
          const Text('微信授权', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('房屋设计助手申请绑定当前设备上的微信身份，用于登录。同一台设备再次授权会回到这个账号。', textAlign: TextAlign.center, style: TextStyle(color: AppColors.sub, height: 1.4)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('拒绝'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF07C160)), onPressed: () => Navigator.pop(context, true), child: const Text('允许'))),
            ],
          ),
        ],
      ),
    );
  }
}
