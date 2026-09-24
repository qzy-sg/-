import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/project_nav.dart';
import '../discover/style_catalog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _drift;

  String get _hello {
    final h = DateTime.now().hour;
    if (h < 11) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 720))..forward();
    _drift = AnimationController(vsync: this, duration: const Duration(milliseconds: 9000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _enter.dispose();
    _drift.dispose();
    super.dispose();
  }

  Widget _reveal(double start, Widget child) {
    final anim = CurvedAnimation(
      parent: _enter,
      curve: Interval(start, (start + 0.55).clamp(0, 1), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featured = styleById('cream') ?? houseStyles.first;
    final rest = houseStyles.where((item) => item.id != featured.id).take(6).toList();

    return Scaffold(
      backgroundColor: AppColors.page,
      body: Stack(
        children: [
          _WarmWash(drift: _drift),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                _reveal(0, _Top(hello: _hello, drift: _drift)),
                const SizedBox(height: 16),
                _reveal(
                  0.08,
                  _Hero(
                    style: featured,
                    drift: _drift,
                    onStart: () => context.push('/projects/new'),
                  ),
                ),
                const SizedBox(height: 22),
                _reveal(0.18, const _Label('就这三步')),
                const SizedBox(height: 10),
                _reveal(
                  0.22,
                  _Steps(
                    onNew: () => context.push('/projects/new'),
                    onUpload: () => openProjectPath(context, ref, '/upload'),
                    onScene: () => openProjectPath(context, ref, '/scene'),
                  ),
                ),
                const SizedBox(height: 18),
                _reveal(
                  0.32,
                  Row(
                    children: [
                      Expanded(
                        child: _SoftAction(
                          title: '继续上次',
                          hint: '回到正在做的房子',
                          icon: Icons.history_rounded,
                          onTap: () => openProjectPath(context, ref, ''),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SoftAction(
                          title: '问问顾问',
                          hint: '户型、预算、收纳',
                          icon: Icons.auto_awesome_outlined,
                          onTap: () => context.go('/ai'),
                          accent: true,
                          pulse: _drift,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                _reveal(
                  0.42,
                  Row(
                    children: [
                      const Expanded(child: _Label('挑个气质')),
                      TextButton(
                        onPressed: () => context.go('/discover'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.sub,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('全部', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                _reveal(
                  0.48,
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: rest.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) => _MoodCard(style: rest[index], tall: index.isEven),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '装修建议仅供灵感参考，不代替设计师和施工方。',
                  style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WarmWash extends StatelessWidget {
  const _WarmWash({required this.drift});
  final Animation<double> drift;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF3E6D4), Color(0xFFF6F3EE), Color(0xFFEEF4F1)],
                stops: [0, 0.28, 1],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: drift,
            builder: (context, _) => CustomPaint(painter: _HomeOrbPainter(drift.value)),
          ),
        ],
      ),
    );
  }
}

class _HomeOrbPainter extends CustomPainter {
  _HomeOrbPainter(this.t);
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

    orb(Offset(size.width * (0.88 + 0.03 * wave), size.height * (0.18 + 0.02 * wave2)), 120, const Color(0x40C6A36A));
    orb(Offset(size.width * (0.08 + 0.04 * wave2), size.height * (0.42 + 0.03 * wave)), 140, const Color(0x332F6B5E));
    orb(Offset(size.width * (0.62 + 0.05 * wave), size.height * (0.72 + 0.02 * wave2)), 100, const Color(0x28D7EBE6));
  }

  @override
  bool shouldRepaint(covariant _HomeOrbPainter oldDelegate) => oldDelegate.t != t;
}

class _Top extends StatelessWidget {
  const _Top({required this.hello, required this.drift});
  final String hello;
  final Animation<double> drift;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hello, style: const TextStyle(fontSize: 13, color: AppColors.sub, letterSpacing: 0.2)),
              const SizedBox(height: 4),
              const Text(
                '把这套房住得更舒服',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.15),
              ),
              const SizedBox(height: 6),
              const Text('选气质，出方案，再走进全景。', style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        AnimatedBuilder(
          animation: drift,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(drift.value);
            return Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF24564C), Color(0xFFC6A36A)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC6A36A).withValues(alpha: 0.22 + t * 0.18),
                    blurRadius: 16 + t * 8,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            );
          },
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.style, required this.drift, required this.onStart});
  final HouseStyle style;
  final Animation<double> drift;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 232,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x2214352F), blurRadius: 28, offset: Offset(0, 14))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: drift,
                  builder: (context, child) {
                    final t = Curves.easeInOut.transform(drift.value);
                    return Transform.scale(scale: 1.04 + t * 0.06, child: child);
                  },
                  child: Image.asset(
                    style.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.primary),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x22101614), Color(0x00101614), Color(0xE6101614)],
                      stops: [0, 0.42, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x66FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x88FFFFFF)),
                        ),
                        child: const Text('AI 空间顾问', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
                      Text(style.name, style: const TextStyle(color: Color(0xFFE8D5B0), fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text(
                        '从一间房子开始',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.15),
                      ),
                      const SizedBox(height: 4),
                      Text(style.vibe, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: onStart,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.ink,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('开始设计', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sub, letterSpacing: 0.2));
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.onNew, required this.onUpload, required this.onScene});
  final VoidCallback onNew;
  final VoidCallback onUpload;
  final VoidCallback onScene;

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('01', '新建房子', '面积和偏好', Icons.home_outlined, onNew),
      ('02', '放户型图', '一张图就够', Icons.upload_outlined, onUpload),
      ('03', '走进 VR', '按房间环视', Icons.threesixty_outlined, onScene),
    ];
    return Row(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                onTap: rows[i].$5,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: i == 0 ? const Color(0x55C6A36A) : AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(rows[i].$1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: i == 0 ? AppColors.brass : AppColors.muted)),
                          const Spacer(),
                          Icon(rows[i].$4, size: 16, color: AppColors.primary),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(rows[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(rows[i].$3, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({
    required this.title,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.accent = false,
    this.pulse,
  });

  final String title;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    Widget card = Material(
      color: accent ? AppColors.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent ? AppColors.mint : AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );

    if (accent && pulse != null) {
      card = AnimatedBuilder(
        animation: pulse!,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(pulse!.value);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08 + t * 0.12),
                  blurRadius: 12 + t * 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          );
        },
        child: card,
      );
    }

    return card;
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.style, required this.tall});
  final HouseStyle style;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: 128,
        height: tall ? 168 : 148,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/styles/${style.id}'),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x140F1C18), blurRadius: 16, offset: Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      style.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.primary),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xCC101614)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0x55FFFFFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              style.tags.first,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            style.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
