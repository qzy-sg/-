import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import 'conversation_store.dart';

/// 顾问开场问句库：覆盖户型→预算→风格→约束，句子完整便于模型一次答到点上。
class _AskPrompt {
  const _AskPrompt({
    required this.category,
    required this.title,
    required this.ask,
    required this.hint,
    required this.icon,
  });

  final String category;
  final String title;
  final String ask;
  final String hint;
  final IconData icon;
}

const _askCategories = ['全部', '户型', '预算', '风格', '约束', '收纳'];

const _askLibrary = <_AskPrompt>[
  _AskPrompt(
    category: '户型',
    title: '两室怎么改更住得开',
    ask: '我家大约两室一厅，想更住得开又不猛拆。先帮我理一理：哪些改动能提升使用感，哪些最好别动？',
    hint: '先谈动线，再谈拆改',
    icon: Icons.door_front_door_outlined,
  ),
  _AskPrompt(
    category: '户型',
    title: '动静分区怎么划',
    ask: '想把家里分成安静区和热闹区，有老人或小孩。按常见户型，怎么安排卧室、客餐厅和动线更合理？',
    hint: '睡区 / 客餐 / 通行',
    icon: Icons.account_tree_outlined,
  ),
  _AskPrompt(
    category: '户型',
    title: '阳台要不要并进客厅',
    ask: '在考虑要不要把阳台并进客厅。从采光、保温、晾晒和日常使用上，帮我列利弊和适用情况。',
    hint: '采光 vs 功能取舍',
    icon: Icons.wb_sunny_outlined,
  ),
  _AskPrompt(
    category: '预算',
    title: '15 万先花在哪',
    ask: '全屋硬装加基础软装大概 15 万预算。按优先级告诉我：哪些必须先做，哪些可以后补，哪里最容易超支？',
    hint: '必做 / 可缓 / 易超支',
    icon: Icons.payments_outlined,
  ),
  _AskPrompt(
    category: '预算',
    title: '钱花在看得见的地方',
    ask: '预算有限，想把钱花在每天看得见、摸得着的地方。柜体、地板、厨卫、灯光里，怎么排性价比？',
    hint: '触感与完成面优先',
    icon: Icons.savings_outlined,
  ),
  _AskPrompt(
    category: '风格',
    title: '现代简约但不冷',
    ask: '喜欢现代简约，但怕家里太冷太空。材质、颜色和灯光上怎么做，才能干净又有温度？',
    hint: '材质与光线升温',
    icon: Icons.auto_awesome_outlined,
  ),
  _AskPrompt(
    category: '风格',
    title: '小户型适合什么气质',
    ask: '小户型想显大显干净，又不要网红同质化。有哪些风格方向更稳妥，各适合什么样的人？',
    hint: '显大、耐看、好打理',
    icon: Icons.palette_outlined,
  ),
  _AskPrompt(
    category: '风格',
    title: '原木风怎么避脏乱',
    ask: '想走原木自然风，又怕显旧显乱。选材、颜色比例和收纳上要注意什么？',
    hint: '木色比例与收纳',
    icon: Icons.forest_outlined,
  ),
  _AskPrompt(
    category: '约束',
    title: '不能拆承重怎么优化',
    ask: '明确不能拆承重墙。在不动结构的前提下，用柜体、门洞、材质和灯光，还能做哪些提升居住感的优化？',
    hint: '结构不动也能改观',
    icon: Icons.shield_outlined,
  ),
  _AskPrompt(
    category: '约束',
    title: '出租房少改结构',
    ask: '房子是出租或过渡住，希望少改水电墙体。有哪些可逆、好恢复、但观感提升明显的改法？',
    hint: '可逆改造清单',
    icon: Icons.meeting_room_outlined,
  ),
  _AskPrompt(
    category: '约束',
    title: '有老人小孩要注意啥',
    ask: '家里有老人和小孩常住。从防滑、圆角、收纳高度、灯光和动线安全上，列一份装修时要注意的清单。',
    hint: '安全与便利并重',
    icon: Icons.family_restroom_outlined,
  ),
  _AskPrompt(
    category: '收纳',
    title: '小户型收纳从哪下手',
    ask: '小户型东西多、容易乱。按进门→客厅→卧室→厨房，给我一套不堆杂物的收纳优先级。',
    hint: '进门到厨房一条线',
    icon: Icons.inventory_2_outlined,
  ),
  _AskPrompt(
    category: '收纳',
    title: '玄关怎么不堆鞋包',
    ask: '玄关窄，鞋包快递容易堆。怎样用柜体分区和动线习惯，让进门干净好用？',
    hint: '落尘、挂放、隐藏',
    icon: Icons.door_sliding_outlined,
  ),
  _AskPrompt(
    category: '收纳',
    title: '厨房动线怎么省事',
    ask: '想把厨房洗切炒和收纳理顺，少走冤枉路。按常见小厨，怎么安排台面、高柜和电器位置更顺手？',
    hint: '洗切炒与柜体',
    icon: Icons.countertops_outlined,
  ),
];

class AiPage extends ConsumerStatefulWidget {
  const AiPage({super.key});

  @override
  ConsumerState<AiPage> createState() => _AiPageState();
}

class _AiPageState extends ConsumerState<AiPage> with TickerProviderStateMixin {
  final _store = AiConversationStore();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final AnimationController _pulse;
  late final AnimationController _dots;
  bool _ready = false;
  bool _busy = false;
  bool _showJump = false;
  int _appearToken = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
    _input.addListener(_onInput);
    _scroll.addListener(_onScroll);
    _store.addListener(_onStore);
    _boot();
  }

  Future<void> _boot() async {
    await _store.load();
    if (!mounted) return;
    setState(() => _ready = true);
    _jump(animate: false);
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  void _onInput() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final gap = _scroll.position.maxScrollExtent - _scroll.offset;
    final show = gap > 120;
    if (show != _showJump) setState(() => _showJump = show);
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    _input.removeListener(_onInput);
    _scroll.removeListener(_onScroll);
    _input.dispose();
    _scroll.dispose();
    _pulse.dispose();
    _dots.dispose();
    super.dispose();
  }

  void _jump({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (!animate) {
        _scroll.jumpTo(target);
        return;
      }
      _scroll.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    });
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast('已复制');
  }

  Future<void> _newChat() async {
    if (_busy) return;
    if (_store.active.isEmptyChat) {
      _toast('当前已是新对话');
      return;
    }
    await _store.createNew();
    _input.clear();
    _jump(animate: false);
  }

  Future<void> _openHistory() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _HistorySheet(
        store: _store,
        onSelect: (id) async {
          Navigator.of(context).pop();
          await _store.select(id);
          _jump(animate: false);
        },
        onDelete: _confirmDelete,
      ),
    );
  }

  Future<void> _confirmDelete(String id) async {
    final chat = _store.byId(id);
    if (chat == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这段对话？'),
        content: Text('「${chat.title}」删除后无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _store.delete(id);
      _toast('已删除');
    }
  }

  Future<void> _send(String text) async {
    final value = text.trim();
    if (value.isEmpty || _busy || !_ready) return;
    final id = _store.active.id;
    setState(() {
      _busy = true;
      _appearToken++;
    });
    _input.clear();
    await _store.append(id, ChatMessage(mine: true, text: value, at: DateTime.now()));
    _jump();
    await _ask(id, value);
  }

  Future<void> _ask(String id, String value) async {
    try {
      final buffer = StringBuffer();
      await _store.upsertAssistantStream(id, '…');
      final data = await ApiClient(token: ref.read(authProvider).token).consultPreferStream(
        value,
        onDelta: (delta) {
          buffer.write(delta);
          unawaited(_store.upsertAssistantStream(id, buffer.toString()));
          if (_store.active.id == id) _jump();
        },
      );
      final reply = '${data['reply'] ?? buffer.toString()}'.trim();
      await _store.upsertAssistantStream(
        id,
        reply.isEmpty ? '已收到。这是灵感，不构成结构、施工结论。' : reply,
        finalize: true,
      );
    } on ApiException catch (err) {
      await _store.upsertAssistantStream(id, err.message, finalize: true);
    } catch (_) {
      await _store.upsertAssistantStream(id, '发送失败，请重试', finalize: true);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _appearToken++;
        });
      }
      if (_store.active.id == id) _jump();
    }
  }

  Future<void> _regenerate() async {
    if (_busy) return;
    final chat = _store.active;
    final messages = List<ChatMessage>.from(chat.messages);
    if (messages.length < 2 || messages.last.mine) return;
    ChatMessage? lastUser;
    for (final item in messages.reversed) {
      if (item.mine) {
        lastUser = item;
        break;
      }
    }
    if (lastUser == null) return;
    messages.removeLast();
    setState(() => _busy = true);
    await _store.replaceMessages(chat.id, messages);
    _jump();
    await _ask(chat.id, lastUser.text);
  }

  @override
  Widget build(BuildContext context) {
    final chat = _ready ? _store.active : null;
    final messages = chat?.messages ?? const <ChatMessage>[];
    final fresh = chat?.isEmptyChat ?? true;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.page,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEFF5F2), Color(0xFFF6F3EE), Color(0xFFF6F3EE)],
                stops: [0, 0.22, 1],
              ),
            ),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(painter: _AiWashPainter(_pulse.value)),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _TopBar(
                  pulse: _pulse,
                  busy: _busy,
                  title: fresh ? '问问' : (chat?.title ?? '问问'),
                  onHistory: _ready ? _openHistory : null,
                  onNew: _ready ? _newChat : null,
                ),
                Expanded(
                  child: !_ready
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : Stack(
                          children: [
                            if (fresh && !_busy)
                              _EmptyState(pulse: _pulse, onPick: _send)
                            else
                              ListView(
                                controller: _scroll,
                                padding: EdgeInsets.fromLTRB(16, 4, 16, 20 + bottom),
                                children: [
                                  for (var i = 0; i < messages.length; i++)
                                    if (!_isGreeting(messages[i]))
                                      _Bubble(
                                        key: ValueKey('${chat!.id}-$i-${messages[i].text.hashCode}'),
                                        message: messages[i],
                                        animate: i == messages.length - 1,
                                        appearToken: _appearToken,
                                        showTools: !_busy && i == messages.length - 1 && !messages[i].mine && !fresh,
                                        onCopy: () => _copy(messages[i].text),
                                        onRetry: _regenerate,
                                      ),
                                  if (_busy) _Typing(controller: _dots),
                                ],
                              ),
                            if (_showJump && !fresh)
                              Positioned(
                                right: 16,
                                bottom: 8,
                                child: _JumpButton(onTap: _jump),
                              ),
                          ],
                        ),
                ),
                _Composer(
                  controller: _input,
                  busy: _busy || !_ready,
                  bottomInset: bottom,
                  onSend: () => _send(_input.text),
                  onClear: _input.clear,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiWashPainter extends CustomPainter {
  _AiWashPainter(this.t);
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

    orb(Offset(size.width * (0.85 + 0.03 * wave), size.height * 0.08), 100, const Color(0x33C6A36A));
    orb(Offset(size.width * (0.1 + 0.04 * wave2), size.height * 0.22), 120, const Color(0x282F6B5E));
  }

  @override
  bool shouldRepaint(covariant _AiWashPainter oldDelegate) => oldDelegate.t != t;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.pulse,
    required this.busy,
    required this.title,
    required this.onHistory,
    required this.onNew,
  });

  final Animation<double> pulse;
  final bool busy;
  final String title;
  final VoidCallback? onHistory;
  final VoidCallback? onNew;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tight = constraints.maxWidth < 220;
          return Row(
            children: [
              _SoftOrb(pulse: pulse, busy: busy, size: tight ? 28 : 32),
              SizedBox(width: tight ? 6 : 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: tight ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      busy ? '正在想…' : '先聊怎么住',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (tight)
                PopupMenuButton<String>(
                  tooltip: '更多',
                  padding: EdgeInsets.zero,
                  onSelected: (value) {
                    if (value == 'history') onHistory?.call();
                    if (value == 'new') onNew?.call();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'history', enabled: onHistory != null, child: const Text('历史')),
                    PopupMenuItem(value: 'new', enabled: onNew != null, child: const Text('新对话')),
                  ],
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(Icons.more_horiz, size: 20, color: AppColors.sub),
                  ),
                )
              else ...[
                _QuietIcon(icon: Icons.history_rounded, tooltip: '历史', onTap: onHistory),
                _QuietIcon(icon: Icons.edit_square, tooltip: '新对话', onTap: onNew),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _QuietIcon extends StatelessWidget {
  const _QuietIcon({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: onTap == null ? AppColors.line : AppColors.sub),
          ),
        ),
      ),
    );
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.pulse, required this.busy, this.size = 40});
  final Animation<double> pulse;
  final bool busy;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(pulse.value);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B3F38), Color(0xFF2F6B5E), Color(0xFFC6A36A)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2F6B5E).withValues(alpha: 0.16 + t * 0.14),
                blurRadius: 10 + t * 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: busy
          ? Padding(
              padding: EdgeInsets.all(size * 0.28),
              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.42),
    );
  }
}

class _EmptyState extends StatefulWidget {
  const _EmptyState({required this.pulse, required this.onPick});
  final Animation<double> pulse;
  final ValueChanged<String> onPick;

  @override
  State<_EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<_EmptyState> {
  late String _category;
  late int _batch;
  late _AskPrompt _featured;

  @override
  void initState() {
    super.initState();
    _category = '全部';
    _batch = DateTime.now().day % 3;
    _featured = _askLibrary[DateTime.now().day % _askLibrary.length];
  }

  List<_AskPrompt> get _filtered {
    if (_category == '全部') return _askLibrary;
    return _askLibrary.where((p) => p.category == _category).toList();
  }

  List<_AskPrompt> get _visible {
    final pool = _filtered;
    if (pool.isEmpty) return const [];
    final size = math.min(4, pool.length);
    final start = (_batch * size) % pool.length;
    return [for (var i = 0; i < size; i++) pool[(start + i) % pool.length]];
  }

  void _shuffle() {
    setState(() {
      _batch++;
      final pool = _filtered;
      if (pool.isNotEmpty) {
        _featured = pool[(_batch + DateTime.now().second) % pool.length];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cards = _visible;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const SizedBox(height: 12),
        Center(child: _SoftOrb(pulse: widget.pulse, busy: false, size: 56)),
        const SizedBox(height: 16),
        const Text(
          '今天想怎么住？',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
        const SizedBox(height: 8),
        const Text(
          '点一张卡片，我会按场景帮你理清取舍。\n只作灵感参考，不构成结构或施工结论。',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 22),
        _FeaturedAsk(prompt: _featured, onTap: () => widget.onPick(_featured.ask)),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text('按场景选', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sub)),
            const Spacer(),
            TextButton.icon(
              onPressed: _shuffle,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('换一批', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _askCategories.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _CategoryChip(
                  label: _askCategories[i],
                  selected: _category == _askCategories[i],
                  onTap: () => setState(() {
                    _category = _askCategories[i];
                    _batch = 0;
                  }),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            key: ValueKey('${_category}_${_batch}_${cards[i].title}'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 280 + i * 60),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(offset: Offset(0, (1 - value) * 10), child: child),
            ),
            child: _AskCard(prompt: cards[i], onTap: () => widget.onPick(cards[i].ask)),
          ),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : AppColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.sub,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedAsk extends StatelessWidget {
  const _FeaturedAsk({required this.prompt, required this.onTap});
  final _AskPrompt prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF14352F), Color(0xFF1F4A40), Color(0xFF3E6258)],
            ),
            boxShadow: const [BoxShadow(color: Color(0x2814352F), blurRadius: 20, offset: Offset(0, 10))],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x28C6A36A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0x55C6A36A)),
                      ),
                      child: const Text('顾问先抛一个', style: TextStyle(color: Color(0xFFE8D5B0), fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Text(prompt.category, style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  prompt.title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3),
                ),
                const SizedBox(height: 6),
                Text(
                  prompt.hint,
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(prompt.icon, size: 16, color: const Color(0xFFE8D5B0)),
                    const SizedBox(width: 8),
                    const Text('点这里开始', style: TextStyle(color: Color(0xFFE8D5B0), fontSize: 12, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFFE8D5B0)),
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

class _AskCard extends StatelessWidget {
  const _AskCard({required this.prompt, required this.onTap});
  final _AskPrompt prompt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(prompt.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          prompt.category,
                          style: const TextStyle(fontSize: 11, color: AppColors.brass, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        const Icon(Icons.north_east_rounded, size: 14, color: AppColors.muted),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prompt.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prompt.hint,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.message,
    required this.animate,
    required this.appearToken,
    required this.showTools,
    required this.onCopy,
    required this.onRetry,
  });

  final ChatMessage message;
  final bool animate;
  final int appearToken;
  final bool showTools;
  final VoidCallback onCopy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final bubble = GestureDetector(
      onLongPress: onCopy,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * (mine ? 0.78 : 0.86)),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(mine ? 20 : 8),
            bottomRight: Radius.circular(mine ? 8 : 20),
          ),
          boxShadow: mine
              ? null
              : const [BoxShadow(color: Color(0x0A0F1C18), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: mine ? Colors.white : AppColors.text,
            height: 1.55,
            fontSize: 15,
          ),
        ),
      ),
    );

    final row = Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: showTools ? 6 : 14, top: mine ? 2 : 4),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text('问问', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
            ),
          if (animate)
            TweenAnimationBuilder<double>(
              key: ValueKey(appearToken),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Opacity(
                opacity: value,
                child: Transform.translate(offset: Offset(0, (1 - value) * 8), child: child),
              ),
              child: row,
            )
          else
            row,
          if (showTools)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 2),
              child: Row(
                children: [
                  _ToolIcon(icon: Icons.copy_rounded, tooltip: '复制', onTap: onCopy),
                  const SizedBox(width: 4),
                  _ToolIcon(icon: Icons.refresh_rounded, tooltip: '再问一次', onTap: onRetry),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 16, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('问问', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Color(0x0A0F1C18), blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Opacity(
                        opacity: 0.35 + 0.65 * ((math.sin((controller.value + i * 0.2) * math.pi * 2) + 1) / 2),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JumpButton extends StatelessWidget {
  const _JumpButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: const Color(0x22000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.bottomInset,
    required this.onSend,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool busy;
  final double bottomInset;
  final VoidCallback onSend;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 4, 14, 10 + bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.line),
          boxShadow: const [BoxShadow(color: Color(0x120F1C18), blurRadius: 22, offset: Offset(0, 8))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !busy,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(fontSize: 15, height: 1.4),
                decoration: const InputDecoration(
                  hintText: '说说户型、预算或风格…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            if (hasText)
              IconButton(
                onPressed: onClear,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
              ),
            Material(
              color: hasText && !busy ? AppColors.primary : AppColors.chip,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: hasText && !busy ? onSend : null,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: hasText && !busy ? Colors.white : AppColors.muted,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.store, required this.onSelect, required this.onDelete});

  final AiConversationStore store;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.store.conversations;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.58,
      minChildSize: 0.4,
      maxChildSize: 0.88,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4))),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('历史对话', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('${items.length} 段', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('还没有对话', style: TextStyle(color: AppColors.muted)))
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final chat = items[index];
                          final selected = chat.id == widget.store.activeId;
                          return Material(
                            color: selected ? AppColors.primarySoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => widget.onSelect(chat.id),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chat.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: selected ? AppColors.primary : AppColors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${_ago(chat.updatedAt)} · ${chat.preview}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '删除',
                                      onPressed: () => widget.onDelete(chat.id),
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _isGreeting(ChatMessage message) {
  return !message.mine &&
      message.text.contains('我是你的设计顾问') &&
      message.text.contains('不构成结构、施工结论');
}

String _ago(DateTime time) {
  final delta = DateTime.now().difference(time);
  if (delta.inMinutes < 1) return '刚刚';
  if (delta.inHours < 1) return '${delta.inMinutes} 分钟前';
  if (delta.inDays < 1) return '${delta.inHours} 小时前';
  if (delta.inDays < 7) return '${delta.inDays} 天前';
  return '${time.month}/${time.day}';
}
