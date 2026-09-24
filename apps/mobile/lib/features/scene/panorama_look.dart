import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

/// 先把 JPEG 字节读进来再画。Chrome 上 Image.network 画跨域图经常只剩黑底。
/// 预览按视口铺满，避免宽屏下「一半绿底」。
class PanoramaLook extends StatefulWidget {
  const PanoramaLook({
    super.key,
    required this.url,
    this.onReady,
    this.onError,
  });

  final String url;
  final VoidCallback? onReady;
  final void Function(String message)? onError;

  @override
  State<PanoramaLook> createState() => _PanoramaLookState();
}

class _PanoramaLookState extends State<PanoramaLook> {
  final ScrollController _scroll = ScrollController();
  Uint8List? _bytes;
  String? _error;
  bool _centered = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PanoramaLook oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _centered = false;
      _bytes = null;
      _error = null;
      _loading = true;
      _load();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final response = await Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 20),
          validateStatus: (code) => code != null && code >= 200 && code < 500,
        ),
      ).get<List<int>>(widget.url);
      final status = response.statusCode ?? 0;
      if (status == 403) {
        throw Exception('图片链接已过期');
      }
      if (status == 404) {
        throw Exception('全景文件不存在');
      }
      if (status >= 400) {
        throw Exception('图片请求失败 ($status)');
      }
      final data = response.data;
      if (data == null || data.length < 800) {
        throw Exception('图片是空的');
      }
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(data);
        _error = null;
        _loading = false;
        _centered = false;
      });
      widget.onReady?.call();
    } catch (err) {
      final message = '$err'.replaceFirst('Exception: ', '');
      if (!mounted) return;
      setState(() {
        _error = message;
        _loading = false;
        _bytes = null;
      });
      widget.onError?.call(message);
    }
  }

  void _centerOnce(double contentW, double viewportW) {
    if (_centered || !_scroll.hasClients) return;
    _centered = true;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    // 滚到中间一带，左右都还能拖
    final target = math.min(max, math.max(0.0, (contentW - viewportW) / 2));
    _scroll.jumpTo(target.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF1A2420),
      child: _bytes == null
          ? Center(
              child: _loading
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white70),
                        SizedBox(height: 12),
                        Text('正在打开全景…', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image_not_supported_outlined, color: Colors.white70, size: 28),
                          const SizedBox(height: 10),
                          Text(
                            _error == null ? '全景暂时打不开' : '全景没有画出来\n$_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              _load();
                            },
                            child: const Text('再试一次', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final viewportW = constraints.maxWidth.isFinite && constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width;
                final viewportH = constraints.maxHeight.isFinite && constraints.maxHeight >= 80
                    ? constraints.maxHeight
                    : 320.0;
                // 等距柱状全景约 2:1；内容宽度至少铺满视口，避免宽屏露底
                final contentW = math.max(viewportW, viewportH * 2);
                WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnce(contentW, viewportW));
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(
                        width: contentW,
                        height: viewportH,
                        child: Image.memory(
                          _bytes!,
                          width: contentW,
                          height: viewportH,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 10,
                      bottom: 10,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xCC14352F),
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text('左右拖动环视', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
