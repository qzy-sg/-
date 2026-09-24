import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_theme.dart';
import '../../core/page_chrome.dart';
import 'style_catalog.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  static const _filters = ['全部', '明亮', '原木', '柔和', '轻奢', '工业', '夜色'];
  String _filter = '全部';

  List<HouseStyle> get _visible {
    if (_filter == '全部') return houseStyles;
    return houseStyles.where((style) {
      return style.tags.any((tag) => tag.contains(_filter)) || style.name.contains(_filter);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    return Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RevealIn(
                        child: PageHeroTitle(
                          title: '风格',
                          subtitle: '先感受空间，再决定怎么住',
                          trailing: AiMark(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filters.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final label = _filters[index];
                            final selected = label == _filter;
                            return AnimatedScale(
                              scale: selected ? 1.04 : 1,
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              child: ChoiceChip(
                                label: Text(label),
                                selected: selected,
                                showCheckmark: false,
                                selectedColor: AppColors.primary,
                                backgroundColor: Colors.white,
                                side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : AppColors.sub,
                                ),
                                onSelected: (_) => setState(() => _filter = label),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('暂时没有这类风格', style: TextStyle(color: AppColors.muted))),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: RevealIn(delay: const Duration(milliseconds: 80), child: _FeaturedCard(items.first)),
                  ),
                ),
                if (items.length > 1)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.78,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => RevealIn(
                          delay: Duration(milliseconds: 100 + index * 40),
                          child: _StyleTile(items[index + 1]),
                        ),
                        childCount: items.length - 1,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard(this.style);
  final HouseStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/styles/${style.id}'),
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          height: 210,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), boxShadow: AppColors.shadow),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'style-hero-${style.id}',
                  child: Image.asset(
                    style.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const ColoredBox(color: AppColors.primary),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x14000000), Color(0x00000000), Color(0xCC101614)],
                    ),
                  ),
                ),
                const Positioned(
                  left: 18,
                  top: 16,
                  child: _FeaturedBadge(),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 18,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(style.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(style.vibe, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13, height: 1.35)),
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

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: const Text('本周推荐', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile(this.style);
  final HouseStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/styles/${style.id}'),
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: AppColors.shadow),
          child: SizedBox.expand(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'style-hero-${style.id}',
                    child: Image.asset(
                      style.image,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const ColoredBox(color: AppColors.primary),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xB3101614)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    right: 14,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x55FFFFFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          style.tags.first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          style.hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xE0FFFFFF), fontSize: 11),
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
    );
  }
}
