import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class AvatarPreset {
  const AvatarPreset(this.id, this.label, this.colors, this.icon);
  final String id;
  final String label;
  final List<Color> colors;
  final IconData icon;
}

const avatarPresets = [
  AvatarPreset('orb', '顾问光', [Color(0xFFC6A36A), Color(0xFFE8D5B0)], Icons.auto_awesome),
  AvatarPreset('brass', '黄铜', [Color(0xFF8B6914), Color(0xFFD4AF37)], Icons.lightbulb_outline),
  AvatarPreset('mint', '薄荷', [Color(0xFF24564C), Color(0xFF7CB8A8)], Icons.spa_outlined),
  AvatarPreset('ink', '墨色', [Color(0xFF101614), Color(0xFF3E6258)], Icons.nightlight_round),
  AvatarPreset('glow', '暖光', [Color(0xFFC56A1A), Color(0xFFF0D7A4)], Icons.wb_sunny_outlined),
  AvatarPreset('plant', '绿意', [Color(0xFF14352F), Color(0xFF6FBF73)], Icons.eco_outlined),
];

AvatarPreset presetById(String? id) {
  for (final item in avatarPresets) {
    if (item.id == id) return item;
  }
  return avatarPresets.first;
}

class AiAvatar extends StatelessWidget {
  const AiAvatar({
    super.key,
    required this.size,
    this.avatarId = 'orb',
    this.initial = '主',
    this.customBytes,
    this.onTap,
    this.showCameraBadge = false,
  });

  final double size;
  final String avatarId;
  final String initial;
  final Uint8List? customBytes;
  final VoidCallback? onTap;
  final bool showCameraBadge;

  @override
  Widget build(BuildContext context) {
    final preset = presetById(avatarId);
    final useCustom = avatarId == 'custom' && customBytes != null && customBytes!.isNotEmpty;
    final child = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: useCustom ? null : LinearGradient(colors: preset.colors),
        image: useCustom ? DecorationImage(image: MemoryImage(customBytes!), fit: BoxFit.cover) : null,
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 16, offset: Offset(0, 6))],
        border: Border.all(color: const Color(0x66FFFFFF), width: 2),
      ),
      child: useCustom
          ? null
          : Center(
              child: size >= 56
                  ? Icon(preset.icon, color: Colors.white.withValues(alpha: 0.92), size: size * 0.38)
                  : Text(
                      initial,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.38,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
    );

    final stacked = Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (showCameraBadge)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
            ),
          ),
      ],
    );

    if (onTap == null) return stacked;
    return GestureDetector(onTap: onTap, child: stacked);
  }
}

String? encodeAvatarBytes(Uint8List? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  return base64Encode(bytes);
}

Uint8List? decodeAvatarBytes(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}
