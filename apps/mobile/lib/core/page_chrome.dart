import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

/// 全站浅绿→奶油氛围，带轻量漂浮光斑（消费级 AI 装修感）。
class AppAtmosphere extends StatefulWidget {
  const AppAtmosphere({super.key, this.child, this.animate = true});

  final Widget? child;
  final bool animate;

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE6F0EC),
      Color(0xFFF6F3EE),
      Color(0xFFF2EEE6),
    ],
    stops: [0, 0.48, 1],
  );

  @override
  State<AppAtmosphere> createState() => _AppAtmosphereState();
}

class _AppAtmosphereState extends State<AppAtmosphere> with SingleTickerProviderStateMixin {
  AnimationController? _drift;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _drift = AnimationController(vsync: this, duration: const Duration(milliseconds: 12000))..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drift = _drift;
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: AppAtmosphere.gradient)),
        if (drift != null)
          IgnorePointer(
            child: AnimatedBuilder(
              animation: drift,
              builder: (context, _) => CustomPaint(painter: _SoftOrbPainter(drift.value)),
            ),
          ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _SoftOrbPainter extends CustomPainter {
  _SoftOrbPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = math.sin(t * math.pi);
    final wave2 = math.cos(t * math.pi);

    void orb(Offset c, double r, Color color) {
      canvas.drawCircle(
        c,
        r,
        Paint()..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    orb(
      Offset(size.width * (0.82 + 0.04 * wave), size.height * (0.12 + 0.03 * wave2)),
      110,
      const Color(0x38C6A36A),
    );
    orb(
      Offset(size.width * (0.12 + 0.05 * wave2), size.height * (0.28 + 0.04 * wave)),
      130,
      const Color(0x402F6B5E),
    );
    orb(
      Offset(size.width * (0.55 + 0.06 * wave), size.height * (0.78 + 0.03 * wave2)),
      90,
      const Color(0x28D7EBE6),
    );

    // 细碎光点，增强 AI 感但不抢内容
    final spark = Paint()..color = const Color(0x55C6A36A);
    for (var i = 0; i < 6; i++) {
      final phase = (t + i * 0.17) % 1;
      final x = size.width * (0.1 + (i * 0.15) % 0.8);
      final y = size.height * (0.08 + phase * 0.55);
      final a = 0.15 + 0.35 * math.sin((t + i) * math.pi * 2).abs();
      canvas.drawCircle(Offset(x, y), 1.6 + phase, spark..color = Color.fromRGBO(198, 163, 106, a));
    }
  }

  @override
  bool shouldRepaint(covariant _SoftOrbPainter oldDelegate) => oldDelegate.t != t;
}

class CircleBackButton extends StatelessWidget {
  const CircleBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppColors.shadow,
        ),
        child: const Icon(Icons.arrow_back_ios_new, size: 16, color: AppColors.text),
      ),
    );
  }
}

/// 右上角轻量 AI 标识，带呼吸感。
class AiMark extends StatefulWidget {
  const AiMark({super.key, this.size = 44});

  final double size;

  @override
  State<AiMark> createState() => _AiMarkState();
}

class _AiMarkState extends State<AiMark> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(AppColors.primarySoft, const Color(0xFFE8F4F0), t)!,
                Color.lerp(const Color(0xFFE8F4F0), AppColors.mint, t)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1 + t * 0.12),
                blurRadius: 10 + t * 14,
                spreadRadius: t * 1.8,
              ),
              BoxShadow(
                color: AppColors.brass.withValues(alpha: 0.06 + t * 0.08),
                blurRadius: 16 + t * 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Icon(Icons.auto_awesome, color: AppColors.primary, size: size * 0.45),
    );
  }
}

/// 入场渐显 + 轻上移，用于列表/分区 stagger。
class RevealIn extends StatelessWidget {
  const RevealIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        (delay.inMilliseconds / (duration.inMilliseconds + delay.inMilliseconds)).clamp(0.0, 0.85),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 14), child: child),
      ),
      child: child,
    );
  }
}

class PageHeroTitle extends StatelessWidget {
  const PageHeroTitle({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.4, height: 1.15),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: AppColors.muted.withValues(alpha: 0.95), height: 1.4),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing!,
        ],
      ],
    );
  }
}

class SoftBottomBar extends StatelessWidget {
  const SoftBottomBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom.clamp(0, 12)),
      decoration: const BoxDecoration(
        color: Color(0xF2F6F3EE),
        border: Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [BoxShadow(color: Color(0x0A0F1C18), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: child,
    );
  }
}

/// AI 等待态：呼吸光标 + 文案，替代裸转圈。
class AiBusy extends StatefulWidget {
  const AiBusy({
    super.key,
    this.message = 'AI 正在想…',
    this.hint,
  });

  final String message;
  final String? hint;

  @override
  State<AiBusy> createState() => _AiBusyState();
}

class _AiBusyState extends State<AiBusy> with SingleTickerProviderStateMixin {
  late final AnimationController _dots;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AiMark(size: 56),
            const SizedBox(height: 18),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _dots,
              builder: (context, _) {
                final phase = (_dots.value * 3).floor() % 3;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: i == phase ? 0.9 : 0.25),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (widget.hint != null) ...[
              const SizedBox(height: 12),
              Text(
                widget.hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 对话里「正在回复」的三点动画。
class AiTypingDots extends StatefulWidget {
  const AiTypingDots({super.key});

  @override
  State<AiTypingDots> createState() => _AiTypingDotsState();
}

class _AiTypingDotsState extends State<AiTypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
          boxShadow: const [BoxShadow(color: Color(0x0A0F1C18), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Transform.translate(
                    offset: Offset(0, -3.5 * (0.5 + 0.5 * math.sin((_c.value * math.pi * 2) + i * 1.1))),
                    child: Container(
                      width: 6,
                      height: 6,
                      margin: EdgeInsets.only(right: i == 2 ? 0 : 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(
                          alpha: 0.35 + 0.45 * ((math.sin((_c.value * math.pi * 2) + i) + 1) / 2),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
