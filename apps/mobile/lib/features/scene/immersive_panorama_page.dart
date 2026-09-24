import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../core/app_theme.dart';
import 'panorama_look.dart';
import 'vr_host.dart';

/// 当前路由内全屏环视：可切换房间、重置视角，不新开网页。
class ImmersivePanoramaPage extends StatefulWidget {
  const ImmersivePanoramaPage({
    super.key,
    required this.viewerUrl,
    required this.payload,
    required this.panoramas,
    required this.initialRoom,
  });

  final String viewerUrl;
  final Map<String, dynamic> payload;
  final List<Map<String, dynamic>> panoramas;
  final String initialRoom;

  @override
  State<ImmersivePanoramaPage> createState() => _ImmersivePanoramaPageState();
}

class _ImmersivePanoramaPageState extends State<ImmersivePanoramaPage> {
  late String _room;
  VrHostController? _vr;
  String? _error;
  bool _useSphere = false;
  bool _chromeVisible = true;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _useSphere = VrHost.supportedOnThisPlatform;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _vr?.disposeViewer();
    super.dispose();
  }

  /// 统一用 Flutter 房间条；Web 上靠 PointerInterceptor 穿透 iframe。
  Map<String, dynamic> get _payload => {
        ...widget.payload,
        'default_room': _room,
        'showBack': false,
        'hideNativeRooms': true,
      };

  Widget _chromeShell(Widget child) {
    if (!kIsWeb) return child;
    return PointerInterceptor(child: child);
  }

  Widget _topBar(String? area) {
    return _chromeShell(
      Row(
        children: [
          _ChromeButton(icon: Icons.arrow_back_ios_new, label: '返回', onTap: _close),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x99000000),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      area == null ? _nameFor(_room) : '${_nameFor(_room)} · $area',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${_index + 1}/${widget.panoramas.length}',
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (_useSphere) ...[
            const SizedBox(width: 8),
            _IconChip(icon: Icons.center_focus_strong_outlined, tooltip: '复位视角', onTap: _resetLook),
          ],
        ],
      ),
    );
  }

  Widget _roomBar() {
    return _chromeShell(
      Row(
        children: [
          _IconChip(icon: Icons.chevron_left, tooltip: '上一间', onTap: () => _stepRoom(-1)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final item in widget.panoramas)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${item['name'] ?? item['room_id']}'),
                        selected: _room == '${item['room_id']}',
                        selectedColor: AppColors.brass,
                        labelStyle: TextStyle(
                          color: _room == '${item['room_id']}' ? AppColors.ink : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: const Color(0x9914352F),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
                        onSelected: (_) => _setRoom('${item['room_id']}'),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IconChip(icon: Icons.chevron_right, tooltip: '下一间', onTap: () => _stepRoom(1)),
        ],
      ),
    );
  }

  String? _urlFor(String roomId) {
    for (final item in widget.panoramas) {
      if ('${item['room_id']}' == roomId) {
        final url = '${item['url'] ?? ''}';
        return url.isEmpty ? null : url;
      }
    }
    if (widget.panoramas.isEmpty) return null;
    final url = '${widget.panoramas.first['url'] ?? ''}';
    return url.isEmpty ? null : url;
  }

  String _nameFor(String roomId) {
    for (final item in widget.panoramas) {
      if ('${item['room_id']}' == roomId) {
        final name = '${item['name'] ?? item['room_id']}';
        final scene = '${item['scene_label'] ?? ''}'.trim();
        final kind = '${item['room_kind'] ?? ''}'.trim();
        if (scene.isNotEmpty && scene != name) return '$name · $scene';
        if (kind.isNotEmpty) return '$name · $kind实景';
        return name;
      }
    }
    return roomId;
  }

  String? _areaFor(String roomId) {
    for (final item in widget.panoramas) {
      if ('${item['room_id']}' == roomId) {
        final area = item['area_sqm'];
        if (area is num && area > 0) {
          return '${area.toStringAsFixed(area % 1 == 0 ? 0 : 1)}㎡';
        }
      }
    }
    return null;
  }

  int get _index {
    for (var i = 0; i < widget.panoramas.length; i++) {
      if ('${widget.panoramas[i]['room_id']}' == _room) return i;
    }
    return 0;
  }

  void _setRoom(String roomId) {
    if (roomId.isEmpty || roomId == _room) return;
    setState(() {
      _room = roomId;
      _error = null;
      _chromeVisible = true;
    });
    _vr?.setRoom(roomId);
  }

  void _stepRoom(int delta) {
    if (widget.panoramas.isEmpty) return;
    final next = (_index + delta) % widget.panoramas.length;
    final safe = next < 0 ? widget.panoramas.length - 1 : next;
    _setRoom('${widget.panoramas[safe]['room_id']}');
  }

  void _resetLook() {
    _vr?.resetLook();
    setState(() => _chromeVisible = true);
  }

  void _onReady(VrHostController controller) {
    _vr = controller;
    controller.loadScene(_payload);
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = '${event['type'] ?? ''}';
    if (type == 'scene.error') {
      setState(() {
        _error = '${event['message'] ?? '全景打不开'}';
        _useSphere = false;
      });
    } else if (type == 'scene.room.switch' || type == 'scene.camera.set') {
      final room = '${event['room'] ?? event['camera'] ?? ''}';
      if (room.isNotEmpty && room != _room) setState(() => _room = room);
    } else if (type == 'scene.close') {
      _close();
    } else if (type == 'scene.loaded') {
      setState(() => _error = null);
    }
  }

  void _close() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(_room);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _urlFor(_room);
    final area = _areaFor(_room);
    final multi = widget.panoramas.length > 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF101614),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_useSphere)
              VrHost(viewerUrl: widget.viewerUrl, onEvent: _onEvent, onReady: _onReady)
            else if (url != null)
              GestureDetector(
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                child: PanoramaLook(
                  key: ValueKey(url),
                  url: url,
                  onError: (message) {
                    if (!mounted) return;
                    setState(() => _error = message);
                  },
                ),
              )
            else
              const Center(child: Text('没有可环视的全景', style: TextStyle(color: Colors.white70))),
            AnimatedOpacity(
              opacity: _chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !_chromeVisible,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Column(
                      children: [
                        _topBar(area),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          _chromeShell(
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.dangerBg.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (multi)
                          _roomBar()
                        else
                          const Text('轻点画面可隐藏控件', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11)),
                      ],
                    ),
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

class _ChromeButton extends StatelessWidget {
  const _ChromeButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0x99000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: const Color(0x99000000),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
