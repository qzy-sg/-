import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/page_chrome.dart';

/// 新建房子：直传图纸 / AI 帮做。
class NewProjectPage extends StatelessWidget {
  const NewProjectPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: Row(
                  children: [
                    CircleBackButton(),
                    Expanded(child: Text('新建房子', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    AiMark(size: 40),
                  ],
                ),
              ),
              const PageHeroTitle(
                title: '怎么开始',
                subtitle: '两种路径都能先看到空间，再慢慢改。',
              ),
              const SizedBox(height: 22),
              _PathCard(
                badge: '更快',
                title: '直传图纸',
                body: '上传户型图，选风格后直接出效果图和 VR。少填表，先看一眼。',
                points: const ['上传户型', '选风格', '看全景'],
                dark: true,
                onTap: () => context.push('/projects/new/quick'),
              ),
              const SizedBox(height: 12),
              _PathCard(
                badge: '更贴合',
                title: 'AI 帮做',
                body: '大概面积与类型 → 放户型 → AI 读完一键采用 → 选住法。不用一条条确认房间。',
                points: const ['轻填资料', '放户型', '一键继续'],
                dark: false,
                onTap: () => context.push('/projects/new/guided'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.badge,
    required this.title,
    required this.body,
    required this.points,
    required this.dark,
    required this.onTap,
  });

  final String badge;
  final String title;
  final String body;
  final List<String> points;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.text;
    final sub = dark ? const Color(0xD6FFFFFF) : AppColors.muted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: dark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF102E28), Color(0xFF1B3F38), Color(0xFF2F5C52)],
                  )
                : null,
            color: dark ? null : Colors.white,
            border: dark ? null : Border.all(color: AppColors.line),
            boxShadow: dark
                ? const [BoxShadow(color: Color(0x2414352F), blurRadius: 22, offset: Offset(0, 10))]
                : AppColors.shadow,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0x22C6A36A) : AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: dark ? Border.all(color: const Color(0x55C6A36A)) : null,
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dark ? const Color(0xFFE8D5B0) : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(title, style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(body, style: TextStyle(color: sub, fontSize: 13, height: 1.45)),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < points.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0x22FFFFFF) : AppColors.chip,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${i + 1}  ${points[i]}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? Colors.white : AppColors.sub),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '开始',
                      style: TextStyle(color: dark ? const Color(0xFFE8D5B0) : AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 16, color: dark ? const Color(0xFFE8D5B0) : AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
