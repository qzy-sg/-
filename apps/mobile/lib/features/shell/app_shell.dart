import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _tabs = [
    _Tab('/home', '概览', Icons.dashboard_outlined, Icons.dashboard),
    _Tab('/projects', '房子', Icons.home_work_outlined, Icons.home_work),
    _Tab('/ai', '问问', Icons.auto_awesome_outlined, Icons.auto_awesome, accent: true),
    _Tab('/discover', '风格', Icons.brush_outlined, Icons.brush),
    _Tab('/me', '我的', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  int _index(String path) {
    if (path.startsWith('/projects')) return 1;
    if (path.startsWith('/ai')) return 2;
    if (path.startsWith('/discover')) return 3;
    if (path.startsWith('/me')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _index(GoRouterState.of(context).uri.path);
    return Scaffold(
      backgroundColor: AppColors.page,
      body: MediaQuery.removePadding(context: context, removeBottom: true, child: child),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xF8FFFCFA),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xE0E7E2DA)),
            boxShadow: const [
              BoxShadow(color: Color(0x140F1C18), blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    tab: _tabs[i],
                    selected: index == i,
                    onTap: () => context.go(_tabs[i].path),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.label, this.icon, this.activeIcon, {this.accent = false});

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool accent;
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.tab.accent) {
      _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = widget.tab;
    final selected = widget.selected;
    final color = selected ? AppColors.primary : AppColors.muted;
    final pulse = _pulse;

    Widget iconChip = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(horizontal: tab.accent || selected ? 10 : 6, vertical: 4),
      decoration: BoxDecoration(
        color: tab.accent
            ? (selected ? AppColors.primary : AppColors.mint)
            : (selected ? AppColors.primarySoft : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        boxShadow: tab.accent && selected
            ? const [BoxShadow(color: Color(0x3314352F), blurRadius: 10, offset: Offset(0, 3))]
            : null,
      ),
      child: Icon(
        selected ? tab.activeIcon : tab.icon,
        size: tab.accent ? 18 : 20,
        color: tab.accent ? (selected ? Colors.white : AppColors.primary) : color,
      ),
    );

    if (pulse != null && tab.accent) {
      iconChip = AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(pulse.value);
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: (selected ? AppColors.primary : AppColors.brass).withValues(alpha: 0.12 + t * 0.16),
                  blurRadius: 8 + t * 10,
                  spreadRadius: t * 0.8,
                ),
              ],
            ),
            child: child,
          );
        },
        child: iconChip,
      );
    }

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            iconChip,
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
              child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
