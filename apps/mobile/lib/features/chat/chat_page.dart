import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/design_widgets.dart';
import '../../core/page_chrome.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_Bubble>[
    const _Bubble(false, '说说你怎么住。我会按已确认的房间给方向，不会把猜测写成事实。'),
  ];
  List<Map<String, dynamic>> _options = const [];
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send(String text) async {
    final content = text.trim();
    if (content.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _messages.add(_Bubble(true, content));
    });
    _input.clear();
    _jump();
    try {
      final body = await ApiClient(token: ref.read(authProvider).token).sendMessage(widget.projectId, content);
      if (!mounted) return;
      final reply = '${body['reply'] ?? '已记下。'}';
      final raw = body['options'];
      final options = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) options.add(Map<String, dynamic>.from(item));
        }
      }
      setState(() {
        _messages.add(_Bubble(false, reply));
        if (options.isNotEmpty) _options = options;
        _busy = false;
      });
      _jump();
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _messages.add(_Bubble(false, err.message));
        _busy = false;
      });
      _jump();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '发送失败，请重试';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      title: '说说你的生活',
      subtitle: '答完就能出方向',
      step: 4,
      trailing: const AiMark(size: 40),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < _messages.length; i++)
                  RevealIn(
                    delay: Duration(milliseconds: i == _messages.length - 1 ? 40 : 0),
                    duration: const Duration(milliseconds: 360),
                    child: _ChatBubble(bubble: _messages[i], onChip: i == 0 && !_busy ? _send : null),
                  ),
                if (_busy) const AiTypingDots(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [BoxShadow(color: Color(0x0A0F1C18), blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: TextField(
                      controller: _input,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        hintText: '想改什么，直接说',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                        ),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: _busy ? const Color(0xFF8AA39C) : AppColors.primary,
                  shape: const CircleBorder(),
                  elevation: 0,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _busy ? null : () => _send(_input.text),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottom: PrimaryButton(
        label: _options.isEmpty ? '先聊几句再出方向' : '看几个方向',
        icon: Icons.auto_awesome_outlined,
        onPressed: _options.isEmpty
            ? null
            : () => context.push('/projects/${widget.projectId}/layouts', extra: _options),
      ),
    );
  }
}

class _Bubble {
  const _Bubble(this.mine, this.text);
  final bool mine;
  final String text;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.bubble, required this.onChip});
  final _Bubble bubble;
  final ValueChanged<String>? onChip;

  @override
  Widget build(BuildContext context) {
    final align = bubble.mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!bubble.mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF1B3F38), Color(0xFFC6A36A)]),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text('顾问', style: TextStyle(fontSize: 11, color: AppColors.muted.withValues(alpha: 0.95), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: bubble.mine
                  ? const LinearGradient(colors: [Color(0xFF24564C), Color(0xFF14352F)])
                  : null,
              color: bubble.mine ? null : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(bubble.mine ? 18 : 6),
                bottomRight: Radius.circular(bubble.mine ? 6 : 18),
              ),
              border: bubble.mine ? null : Border.all(color: const Color(0x14C6A36A)),
              boxShadow: const [BoxShadow(color: Color(0x0C0F1C18), blurRadius: 14, offset: Offset(0, 5))],
            ),
            child: Text(
              bubble.text,
              style: TextStyle(color: bubble.mine ? Colors.white : AppColors.text, height: 1.45, fontSize: 14),
            ),
          ),
          if (onChip != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in ['半开放厨房', '书房独立', '学习区放客厅'])
                  ActionChip(
                    label: Text(chip, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    backgroundColor: AppColors.primarySoft,
                    side: const BorderSide(color: AppColors.mint),
                    onPressed: () => onChip!(chip),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
