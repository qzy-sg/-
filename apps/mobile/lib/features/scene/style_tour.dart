import '../discover/style_catalog.dart';

class StyleTour {
  const StyleTour({
    required this.id,
    required this.name,
    required this.file,
    required this.roomName,
    required this.credit,
  });

  final String id;
  final String name;
  final String file;
  final String roomName;
  final String credit;
}

/// 风格页「看 VR」用的实景环视。文件在 webview-vr/panoramas，由 API 的 /viewer 提供。
const styleTours = [
  StyleTour(id: 'modern', name: '现代简约', file: 'style-modern.jpg', roomName: '客厅', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'wood', name: '日式原木', file: 'style-wood.jpg', roomName: '木色起居', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'cream', name: '奶油风', file: 'style-cream.jpg', roomName: '暖色客房', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'green', name: '中古绿', file: 'style-green.jpg', roomName: '绿色客厅', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'white', name: '极简白', file: 'style-white.jpg', roomName: '通透厅', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'night', name: '夜色客厅', file: 'style-night.jpg', roomName: '夜色空间', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'french', name: '法式轻奢', file: 'style-french.jpg', roomName: '会客厅', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'loft', name: '工业风', file: 'style-loft.jpg', roomName: '工业空间', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'luxe', name: '轻奢意式', file: 'style-luxe.jpg', roomName: '精致厅', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'sea', name: '地中海', file: 'style-sea.jpg', roomName: '通透厅', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'wabi', name: '侘寂风', file: 'style-wabi.jpg', roomName: '素色空间', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
  StyleTour(id: 'blush', name: '柔粉现代', file: 'style-blush.jpg', roomName: '柔和空间', credit: '实景环视，拖动可以看四周。画面来自 Poly Haven，可免费使用。'),
];

HouseStyle? _houseStyleFor(String key) {
  final byId = styleById(key);
  if (byId != null) return byId;
  for (final style in houseStyles) {
    if (style.name == key) return style;
  }
  return null;
}

StyleTour? styleTourFor(String? raw) {
  if (raw == null) return null;
  final key = raw.trim();
  if (key.isEmpty) return null;
  for (final item in styleTours) {
    if (item.id == key || item.name == key) return item;
  }
  final style = _houseStyleFor(key);
  if (style == null) return null;
  final file = style.image.split('/').last;
  return StyleTour(
    id: style.id,
    name: style.name,
    file: file,
    roomName: style.gallery.first.room,
    credit: '实景环视，可切换多个房间。画面来自 Poly Haven，可免费使用。',
  );
}

/// 风格页 gallery → VR 多房间全景列表（同一风格多实景可切换）。
List<Map<String, dynamic>> stylePreviewPanoramas(String? styleKey, String apiBase) {
  final key = styleKey?.trim() ?? '';
  final style = key.isEmpty ? null : _houseStyleFor(key);
  final tour = styleTourFor(key.isEmpty ? null : key);
  final gallery = style?.gallery ?? const <StyleScene>[];

  if (gallery.isEmpty) {
    if (tour == null) return const [];
    return [
      {
        'room_id': 'room_0',
        'name': tour.roomName,
        'url': '$apiBase/viewer/panoramas/${tour.file}',
      },
    ];
  }

  final items = <Map<String, dynamic>>[];
  for (var i = 0; i < gallery.length; i++) {
    final scene = gallery[i];
    final file = scene.image.split('/').last;
    if (file.isEmpty) continue;
    items.add({
      'room_id': 'room_$i',
      'name': scene.room,
      'url': '$apiBase/viewer/panoramas/$file',
    });
  }
  return items;
}
