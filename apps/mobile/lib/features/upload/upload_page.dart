import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../core/design_widgets.dart';
import '../../core/floor_plan_pick.dart';
import '../../core/page_chrome.dart';

/// 上传户型：干净三入口，传完直接去 AI 识别。
class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key, required this.projectId, this.styleName});
  final String projectId;
  final String? styleName;

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final _files = <_FileRow>[];
  String? _error;
  bool _busy = false;

  Future<void> _pick([String? prefer]) async {
    if (_busy) return;
    final picked = await pickFloorPlan(context, prefer: prefer);
    if (picked == null || !mounted) return;

    final row = _FileRow(picked.name, 0.05, status: '上传中');
    setState(() {
      _error = null;
      _busy = true;
      _files.insert(0, row);
    });

    try {
      final client = ApiClient(token: ref.read(authProvider).token);
      final assetId = await client.uploadImage(
        widget.projectId,
        filename: picked.name,
        contentType: picked.contentType,
        bytes: picked.bytes,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => row.progress = value);
        },
      );
      if (!mounted) return;
      setState(() {
        row.progress = 1;
        row.status = '已完成';
        row.assetId = assetId;
        _busy = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        row.status = '失败';
        row.progress = 0;
        _error = err.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        row.status = '失败';
        row.progress = 0;
        _error = '上传失败，请重试';
        _busy = false;
      });
    }
  }

  Future<void> _retry(_FileRow row) async {
    if (_busy || row.status != '失败') return;
    setState(() {
      _files.remove(row);
      _error = null;
    });
    await _pick();
  }

  void _goAnalyze() {
    final ready = _files.where((f) => f.assetId != null).toList();
    if (ready.isEmpty) {
      setState(() => _error = '请先放上一张户型图');
      return;
    }
    context.push('/projects/${widget.projectId}/analysis?assetId=${ready.first.assetId}');
  }

  @override
  Widget build(BuildContext context) {
    final canAnalyze = _files.any((f) => f.assetId != null) && !_busy;
    final styleHint = widget.styleName == null || widget.styleName!.isEmpty
        ? '相册、拍照或文件都行，一张清晰图即可。'
        : '按「${widget.styleName}」来做。先放户型，AI 会读房间。';

    return Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 16, 0),
                child: Row(
                  children: [
                    CircleBackButton(),
                    Expanded(child: Text('放户型图', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                    AiMark(size: 40),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    PageHeroTitle(title: '把户型给我', subtitle: styleHint),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(child: _SourceTile(icon: Icons.photo_library_outlined, label: '相册', onTap: _busy ? null : () => _pick('gallery'))),
                        const SizedBox(width: 10),
                        Expanded(child: _SourceTile(icon: Icons.photo_camera_outlined, label: '拍照', onTap: _busy ? null : () => _pick('camera'))),
                        const SizedBox(width: 10),
                        Expanded(child: _SourceTile(icon: Icons.folder_open_outlined, label: '文件', onTap: _busy ? null : () => _pick('file'))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _busy ? '上传中…' : '支持 JPG / PNG · 读完可一键采用，不必逐间确认',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    if (_files.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      for (final file in _files)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.line),
                              boxShadow: AppColors.shadow,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  file.status == '失败'
                                      ? Icons.error_outline
                                      : file.status == '已完成'
                                          ? Icons.check_circle_outline
                                          : Icons.insert_drive_file_outlined,
                                  color: file.status == '失败'
                                      ? AppColors.danger
                                      : file.status == '已完成'
                                          ? AppColors.primary
                                          : AppColors.muted,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        file.status,
                                        style: TextStyle(fontSize: 12, color: file.status == '失败' ? AppColors.danger : AppColors.muted),
                                      ),
                                      if (file.progress > 0 && file.progress < 1) ...[
                                        const SizedBox(height: 8),
                                        LinearProgressIndicator(
                                          value: file.progress,
                                          minHeight: 3,
                                          color: AppColors.primary,
                                          backgroundColor: AppColors.chip,
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (file.status == '失败') TextButton(onPressed: () => _retry(file), child: const Text('重试')),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              SoftBottomBar(
                child: PrimaryButton(
                  label: canAnalyze ? '开始识别' : (_busy ? '上传中…' : '先选一张图'),
                  onPressed: canAnalyze ? _goAnalyze : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: onTap == null ? AppColors.muted : AppColors.primary, size: 22),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: onTap == null ? AppColors.muted : AppColors.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileRow {
  _FileRow(this.name, this.progress, {this.status = '待上传'});
  final String name;
  double progress;
  String status;
  String? assetId;
}
