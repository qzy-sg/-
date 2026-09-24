import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/design_widgets.dart';
import '../../core/page_chrome.dart';

class VersionsPage extends ConsumerStatefulWidget {
  const VersionsPage({super.key, required this.projectId});
  final String projectId;

  @override
  ConsumerState<VersionsPage> createState() => _VersionsPageState();
}

class _VersionsPageState extends ConsumerState<VersionsPage> {
  List<Map<String, dynamic>> _items = const [];
  String? _currentId;
  bool _loading = true;
  bool _busy = false;
  bool _older = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      final items = await client.listVersions(widget.projectId);
      if (!mounted) return;
      final mapped = [
        for (final item in items)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
      setState(() {
        _items = mapped;
        _currentId = mapped.isEmpty ? null : '${mapped.first['id']}';
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '加载版本失败';
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    if (_currentId == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      await client.confirmVersion(widget.projectId, _currentId!);
      if (!mounted) return;
      context.push('/projects/${widget.projectId}/renders?versionId=$_currentId');
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '确认失败，请重试';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _items.isEmpty ? null : _items.first;
    final older = _items.length > 1 ? _items.sublist(1) : const <Map<String, dynamic>>[];
    return WizardScaffold(
      title: '这一版可以吗',
      subtitle: current == null ? '还没有设计版本' : '${current['title'] ?? '当前草案'}',
      step: 6,
      trailing: const AiMark(size: 40),
      body: _loading
          ? const AiBusy(message: '整理设计版本…')
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                  TextButton(onPressed: _load, child: const Text('重试')),
                  const SizedBox(height: 8),
                ],
                if (current == null)
                  const Text('请先在布局页保存一版草案。', style: TextStyle(color: AppColors.muted))
                else
                  SoftCard(
                    borderColor: AppColors.primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前 · ${current['title'] ?? '草案'}',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text('${current['summary'] ?? '已保存的设计方向'}'),
                        const SizedBox(height: 10),
                        const Text('这是草案，不构成结构、施工结论。', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                if (older.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _older = !_older),
                    child: Text(_older ? '收起更早的版本' : '看更早的版本'),
                  ),
                if (_older)
                  for (final item in older) ...[
                    SoftCard(
                      child: Text('${item['title'] ?? '旧版本'}：${item['summary'] ?? ''}'),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
      bottom: PrimaryButton(
        label: _busy ? '确认中…' : '就用这版，看效果图',
        onPressed: current == null || _busy ? null : _confirm,
      ),
    );
  }
}
