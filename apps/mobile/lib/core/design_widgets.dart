import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'disclaimer.dart';
import 'page_chrome.dart';

const wizardSteps = [
  '房屋资料',
  '户型图',
  '户型识别',
  '需求对话',
  '住法方向',
  '设计版本',
  '效果图',
  'VR 全景',
];

class StepHeader extends StatelessWidget {
  const StepHeader({
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleBackButton(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final safe = current.clamp(1, wizardSteps.length);
    final target = safe / wizardSteps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: target),
            duration: const Duration(milliseconds: 640),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const ColoredBox(color: AppColors.chip),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF24564C), Color(0xFFC6A36A)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            '第 $safe 步 · ${wizardSteps[safe - 1]}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor});

  final Widget child;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    // Material owns the fill color so nested ListTiles can paint ink/splash.
    // Outer Container only keeps the soft shadow (no background color).
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppColors.shadow,
      ),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor ?? const Color(0x14C6A36A)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with SingleTickerProviderStateMixin {
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _shine,
        builder: (context, child) {
          final t = enabled ? _shine.value : 0.0;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment(-1.2 + t * 2.4, 0),
                end: Alignment(-0.4 + t * 2.4, 1),
                colors: enabled
                    ? const [Color(0xFF24564C), Color(0xFF1A453C), Color(0xFF102E28), Color(0xFF24564C)]
                    : const [Color(0xFF8AA39C), Color(0xFF667F78)],
                stops: enabled ? const [0, 0.35, 0.55, 1] : null,
              ),
              boxShadow: [
                BoxShadow(
                  color: enabled ? const Color(0x4014352F) : const Color(0x140F1C18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox.expand(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[Icon(widget.icon, size: 18, color: Colors.white), const SizedBox(width: 8)],
                  Text(widget.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class ChoicePills extends StatelessWidget {
  const ChoicePills({super.key, required this.options, required this.selected, required this.onSelect});

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: () => onSelect(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected == option ? AppColors.primary : AppColors.chip,
                borderRadius: BorderRadius.circular(12),
                boxShadow: selected == option
                    ? const [BoxShadow(color: Color(0x2814352F), blurRadius: 10, offset: Offset(0, 4))]
                    : null,
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 13,
                  color: selected == option ? Colors.white : AppColors.sub,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.text, this.action, this.icon = Icons.info_outline, this.tone = BannerTone.warn});

  final String text;
  final Widget? action;
  final IconData icon;
  final BannerTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = tone == BannerTone.warn ? AppColors.warnBg : AppColors.primarySoft;
    final fg = tone == BannerTone.warn ? AppColors.warnText : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone == BannerTone.warn ? AppColors.warnLine : AppColors.mint),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: fg, fontSize: 12, height: 1.4))),
          ?action,
        ],
      ),
    );
  }
}

enum BannerTone { warn, mint }

class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.body,
    required this.bottom,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final int step;
  final Widget body;
  final Widget bottom;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              StepHeader(title: title, subtitle: subtitle, trailing: trailing),
              const SizedBox(height: 6),
              StepProgress(current: step),
              const SizedBox(height: 12),
              Expanded(child: body),
              SoftBottomBar(child: bottom),
            ],
          ),
        ),
      ),
    );
  }
}

class DisclaimerBox extends StatefulWidget {
  const DisclaimerBox({super.key});

  @override
  State<DisclaimerBox> createState() => _DisclaimerBoxState();
}

class _DisclaimerBoxState extends State<DisclaimerBox> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return InkWell(
        onTap: () => setState(() => _open = true),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('仅供设计灵感，不构成结构、施工结论。轻点查看完整说明', style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
        ),
      );
    }
    return const NoticeBanner(text: disclaimerText, icon: Icons.shield_outlined);
  }
}
