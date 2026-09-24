/// 布局方向默认文案。与服务端 layout_options 对齐，打开页时即使没有对话结果也能先看。
const defaultLayoutDirections = <Map<String, dynamic>>[
  {
    'id': 'opt_open',
    'title': '通透会客',
    'vibe': '把光线留给客厅，家具轻轻分区',
    'summary': '不动未知承重，用沙发与餐桌划出会客和用餐，空间显得更开敞。',
    'tags': ['通透', '会客', '少隔断'],
    'highlights': ['客厅做视觉中心', '客餐轻微分区', '动线短而顺'],
  },
  {
    'id': 'opt_storage',
    'title': '整墙收纳',
    'vibe': '东西有处可放，家里才显干净',
    'summary': '沿墙做柜体，不改门窗位置，把杂物收进看不见的地方。',
    'tags': ['收纳', '干净', '耐住'],
    'highlights': ['玄关与客厅一体收纳', '卧室柜体顺墙', '台面尽量留空'],
  },
  {
    'id': 'opt_quiet',
    'title': '安静睡区',
    'vibe': '热闹留在前场，卧室留给休息',
    'summary': '卧室远离入户热闹动线，灯光偏暖，风格只作氛围参考。',
    'tags': ['安静', '卧室', '柔光'],
    'highlights': ['动静分区更清楚', '主卧少打扰', '夜间光线更柔'],
  },
];

List<Map<String, dynamic>> normalizeLayoutOptions(List<Map<String, dynamic>> raw) {
  if (raw.isEmpty) return List<Map<String, dynamic>>.from(defaultLayoutDirections);
  return [
    for (final item in raw)
      {
        ...item,
        'title': '${item['title'] ?? item['name'] ?? '住法'}',
        'vibe': '${item['vibe'] ?? item['hint'] ?? ''}',
        'summary': '${item['summary'] ?? ''}',
        'tags': item['tags'] is List ? item['tags'] : const <String>[],
        'highlights': item['highlights'] is List ? item['highlights'] : const <String>[],
      },
  ];
}
