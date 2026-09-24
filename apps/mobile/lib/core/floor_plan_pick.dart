import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_theme.dart';

class PickedFloorPlan {
  const PickedFloorPlan({required this.bytes, required this.name, required this.contentType});

  final Uint8List bytes;
  final String name;
  final String contentType;
}

String floorPlanContentType(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}

/// 相册 / 拍照 / 文件。传 [prefer] 可跳过选择菜单。
Future<PickedFloorPlan?> pickFloorPlan(BuildContext context, {String? prefer}) async {
  final choice = prefer ??
      await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(999))),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('怎么放户型图', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('相册、拍照或从文件里选一张都可以', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                  const SizedBox(height: 12),
                  _PickTile(
                    icon: Icons.photo_library_outlined,
                    title: '相册',
                    hint: '从手机或电脑相册选',
                    onTap: () => Navigator.pop(context, 'gallery'),
                  ),
                  const SizedBox(height: 8),
                  _PickTile(
                    icon: Icons.photo_camera_outlined,
                    title: '拍照',
                    hint: '对着图纸或屏幕拍一张',
                    onTap: () => Navigator.pop(context, 'camera'),
                  ),
                  const SizedBox(height: 8),
                  _PickTile(
                    icon: Icons.folder_open_outlined,
                    title: '文件',
                    hint: '本地 JPG / PNG 等图片',
                    onTap: () => Navigator.pop(context, 'file'),
                  ),
                ],
              ),
            ),
          );
        },
      );
  if (choice == null) return null;

  if (choice == 'file') {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final name = file.name.trim().isEmpty ? 'floorplan.jpg' : file.name;
    return PickedFloorPlan(bytes: bytes, name: name, contentType: floorPlanContentType(name));
  }

  final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
  try {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    final name = file.name.trim().isEmpty ? 'floorplan.jpg' : file.name;
    return PickedFloorPlan(bytes: bytes, name: name, contentType: floorPlanContentType(name));
  } catch (_) {
    return null;
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.chip,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(hint, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
