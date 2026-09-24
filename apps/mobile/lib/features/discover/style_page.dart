import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/project_nav.dart';
import 'style_catalog.dart';

class StylePage extends ConsumerStatefulWidget {
  const StylePage({super.key, required this.style});

  final HouseStyle style;

  @override
  ConsumerState<StylePage> createState() => _StylePageState();
}

class _StylePageState extends ConsumerState<StylePage> {
  late final PageController _pages;
  int _index = 0;

  List<StyleScene> get _gallery => widget.style.gallery;

  @override
  void initState() {
    super.initState();
    _pages = PageController();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _buildWithStyle() {
    context.push('/projects/new/quick?style=${widget.style.id}');
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final gallery = _gallery;
    final current = gallery[_index.clamp(0, gallery.length - 1)];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: gallery.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final scene = gallery[index];
              return Image.asset(
                scene.image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(color: AppColors.primary),
              );
            },
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x14000000),
                  Color(0x00000000),
                  Color(0xB3101614),
                  Color(0xF2101614),
                ],
                stops: [0, 0.18, 0.42, 0.72, 1],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0x66FFFFFF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x44FFFFFF)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x55FFFFFF),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                    child: Text(
                      '${_index + 1} / ${gallery.length} · ${current.room}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 14 + bottomInset),
              decoration: const BoxDecoration(
                color: Color(0xF8F6F3EE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, -8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(style.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text(style.vibe, style: const TextStyle(fontSize: 13, color: AppColors.sub, height: 1.4)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: gallery.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final scene = gallery[index];
                        final selected = index == _index;
                        return GestureDetector(
                          onTap: () {
                            _pages.animateToPage(index, duration: const Duration(milliseconds: 240), curve: Curves.easeOutCubic);
                            setState(() => _index = index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 2 : 1),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    scene.image,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const ColoredBox(color: AppColors.chip),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      color: const Color(0x99000000),
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Text(
                                        scene.room,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          filled: true,
                          icon: Icons.threesixty_outlined,
                          title: '看 VR',
                          hint: '多房间环视',
                          onTap: () => openProjectPath(
                            context,
                            ref,
                            '/scene',
                            query: 'style=${style.id}&room=room_$_index&immersive=1',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ActionTile(
                          filled: false,
                          icon: Icons.auto_awesome_outlined,
                          title: '按这风格建',
                          hint: '一键看到设计',
                          onTap: _buildWithStyle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.filled,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final bool filled;
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : Colors.white;
    final fg = filled ? Colors.white : AppColors.primary;
    final muted = filled ? const Color(0xCCFFFFFF) : AppColors.muted;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 88,
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: filled ? null : Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: fg, size: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w700, height: 1.15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 11, height: 1.15),
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
