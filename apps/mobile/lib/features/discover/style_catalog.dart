class StyleScene {
  const StyleScene({required this.image, required this.room});

  final String image;
  final String room;
}

class HouseStyle {
  const HouseStyle({
    required this.id,
    required this.name,
    required this.hint,
    required this.image,
    required this.vibe,
    required this.tags,
    this.scenes = const [],
  });

  final String id;
  final String name;
  final String hint;
  final String image;
  final String vibe;
  final List<String> tags;
  /// 同气质多张实景，风格页可左右滑。
  final List<StyleScene> scenes;

  List<StyleScene> get gallery {
    if (scenes.isNotEmpty) return scenes;
    return [StyleScene(image: image, room: name)];
  }
}

const houseStyles = [
  HouseStyle(
    id: 'modern',
    name: '现代简约',
    hint: '少家具，多光线',
    vibe: '干净利落，把空间留给生活本身',
    image: 'assets/styles/style-modern.jpg',
    tags: ['明亮', '少物', '通透'],
    scenes: [
      StyleScene(image: 'assets/styles/style-modern.jpg', room: '卧室'),
      StyleScene(image: 'assets/styles/style-white.jpg', room: '客厅'),
      StyleScene(image: 'assets/styles/style-air.jpg', room: '留白小间'),
      StyleScene(image: 'assets/styles/style-bath.jpg', room: '卫浴'),
      StyleScene(image: 'assets/styles/style-quiet.jpg', room: '静室'),
    ],
  ),
  HouseStyle(
    id: 'wood',
    name: '日式原木',
    hint: '整墙收纳，安静',
    vibe: '木头和收纳一起安静下来',
    image: 'assets/styles/style-wood.jpg',
    tags: ['原木', '收纳', '安静'],
    scenes: [
      StyleScene(image: 'assets/styles/style-wood.jpg', room: '起居'),
      StyleScene(image: 'assets/styles/style-kominka.jpg', room: '木作'),
      StyleScene(image: 'assets/styles/style-wabi.jpg', room: '素色厅'),
      StyleScene(image: 'assets/styles/style-sofa.jpg', room: '沙发区'),
      StyleScene(image: 'assets/styles/style-atelier.jpg', room: '书房'),
    ],
  ),
  HouseStyle(
    id: 'cream',
    name: '奶油风',
    hint: '低对比，软材质',
    vibe: '柔和的颜色，摸起来也舒服',
    image: 'assets/styles/style-cream.jpg',
    tags: ['柔和', '暖调', '软装'],
    scenes: [
      StyleScene(image: 'assets/styles/style-cream.jpg', room: '客房'),
      StyleScene(image: 'assets/styles/style-sofa.jpg', room: '起居'),
      StyleScene(image: 'assets/styles/style-suite.jpg', room: '卧室'),
      StyleScene(image: 'assets/styles/style-dining.jpg', room: '餐厅'),
      StyleScene(image: 'assets/styles/style-quiet.jpg', room: '静室'),
    ],
  ),
  HouseStyle(
    id: 'green',
    name: '中古绿',
    hint: '深色柜，黄铜点缀',
    vibe: '一点绿意，一点旧物的质感',
    image: 'assets/styles/style-green.jpg',
    tags: ['墨绿', '质感', '点缀'],
    scenes: [
      StyleScene(image: 'assets/styles/style-green.jpg', room: '客厅'),
      StyleScene(image: 'assets/styles/style-aft.jpg', room: '休闲厅'),
      StyleScene(image: 'assets/styles/style-dining.jpg', room: '餐厅'),
      StyleScene(image: 'assets/styles/style-amber.jpg', room: '暮色厅'),
    ],
  ),
  HouseStyle(
    id: 'white',
    name: '极简白',
    hint: '留白当收纳',
    vibe: '白不是空，是把一切收进看不见的地方',
    image: 'assets/styles/style-white.jpg',
    tags: ['留白', '清爽', '轻盈'],
    scenes: [
      StyleScene(image: 'assets/styles/style-white.jpg', room: '通透厅'),
      StyleScene(image: 'assets/styles/style-air.jpg', room: '空房'),
      StyleScene(image: 'assets/styles/style-foyer.jpg', room: '玄关'),
      StyleScene(image: 'assets/styles/style-spa.jpg', room: '卫浴'),
    ],
  ),
  HouseStyle(
    id: 'night',
    name: '夜色客厅',
    hint: '暖光，投影代替电视墙',
    vibe: '夜里把灯调暗，空间就成了另一间房',
    image: 'assets/styles/style-night.jpg',
    tags: ['夜色', '暖光', '沉浸'],
    scenes: [
      StyleScene(image: 'assets/styles/style-night.jpg', room: '夜餐厅'),
      StyleScene(image: 'assets/styles/style-hearth.jpg', room: '壁炉厅'),
      StyleScene(image: 'assets/styles/style-amber.jpg', room: '暮色厅'),
      StyleScene(image: 'assets/styles/style-dining.jpg', room: '餐厅'),
    ],
  ),
  HouseStyle(
    id: 'french',
    name: '法式轻奢',
    hint: '线条柔和，家更有仪式感',
    vibe: '一点点装饰，让客厅也像会客厅',
    image: 'assets/styles/style-french.jpg',
    tags: ['柔和', '轻奢', '仪式感'],
    scenes: [
      StyleScene(image: 'assets/styles/style-french.jpg', room: '书房'),
      StyleScene(image: 'assets/styles/style-luxe.jpg', room: '精致厅'),
      StyleScene(image: 'assets/styles/style-sofa.jpg', room: '起居'),
      StyleScene(image: 'assets/styles/style-atelier.jpg', room: '创作间'),
    ],
  ),
  HouseStyle(
    id: 'loft',
    name: '工业风',
    hint: '砖墙与金属，空间更有态度',
    vibe: '把结构露出来，反而更真实',
    image: 'assets/styles/style-loft.jpg',
    tags: ['工业', '质感', '开放'],
    scenes: [
      StyleScene(image: 'assets/styles/style-loft.jpg', room: '工坊'),
      StyleScene(image: 'assets/styles/style-atelier.jpg', room: '工作室'),
      StyleScene(image: 'assets/styles/style-walk.jpg', room: '廊道'),
      StyleScene(image: 'assets/styles/style-foyer.jpg', room: '门厅'),
    ],
  ),
  HouseStyle(
    id: 'luxe',
    name: '轻奢意式',
    hint: '石材与金属，克制的高级感',
    vibe: '不堆金色，也能显出精致',
    image: 'assets/styles/style-luxe.jpg',
    tags: ['轻奢', '石材', '精致'],
    scenes: [
      StyleScene(image: 'assets/styles/style-luxe.jpg', room: '大厅'),
      StyleScene(image: 'assets/styles/style-french.jpg', room: '书房'),
      StyleScene(image: 'assets/styles/style-dining.jpg', room: '餐厅'),
      StyleScene(image: 'assets/styles/style-suite.jpg', room: '套房'),
    ],
  ),
  HouseStyle(
    id: 'sea',
    name: '地中海',
    hint: '白墙与蓝色，像度假一样通透',
    vibe: '把阳光和海风留在客厅里',
    image: 'assets/styles/style-sea.jpg',
    tags: ['明亮', '度假', '通透'],
    scenes: [
      StyleScene(image: 'assets/styles/style-sea.jpg', room: '阳台'),
      StyleScene(image: 'assets/styles/style-suite.jpg', room: '海景房'),
      StyleScene(image: 'assets/styles/style-glass.jpg', room: '花房'),
      StyleScene(image: 'assets/styles/style-walk.jpg', room: '廊道'),
    ],
  ),
  HouseStyle(
    id: 'wabi',
    name: '侘寂风',
    hint: '素土与旧物，慢慢住下来',
    vibe: '不追求完美，只要舒服和安静',
    image: 'assets/styles/style-wabi.jpg',
    tags: ['安静', '原木', '素雅'],
    scenes: [
      StyleScene(image: 'assets/styles/style-wabi.jpg', room: '素色厅'),
      StyleScene(image: 'assets/styles/style-kominka.jpg', room: '木作'),
      StyleScene(image: 'assets/styles/style-wood.jpg', room: '原木厅'),
      StyleScene(image: 'assets/styles/style-quiet.jpg', room: '静室'),
    ],
  ),
  HouseStyle(
    id: 'blush',
    name: '柔粉现代',
    hint: '淡粉色点缀，温柔但不甜腻',
    vibe: '一点点粉色，让空间更亲近人',
    image: 'assets/styles/style-blush.jpg',
    tags: ['柔和', '暖调', '轻盈'],
    scenes: [
      StyleScene(image: 'assets/styles/style-blush.jpg', room: '卫浴'),
      StyleScene(image: 'assets/styles/style-cream.jpg', room: '客房'),
      StyleScene(image: 'assets/styles/style-spa.jpg', room: '浴室'),
      StyleScene(image: 'assets/styles/style-suite.jpg', room: '卧室'),
    ],
  ),
  HouseStyle(
    id: 'suite',
    name: '海景套房',
    hint: '大窗采光，卧室也通透',
    vibe: '把外面的光留进卧室里',
    image: 'assets/styles/style-suite.jpg',
    tags: ['明亮', '卧室', '度假'],
    scenes: [
      StyleScene(image: 'assets/styles/style-suite.jpg', room: '套房'),
      StyleScene(image: 'assets/styles/style-sea.jpg', room: '阳台'),
      StyleScene(image: 'assets/styles/style-cream.jpg', room: '客房'),
      StyleScene(image: 'assets/styles/style-glass.jpg', room: '花房'),
    ],
  ),
  HouseStyle(
    id: 'dining',
    name: '日光餐厅',
    hint: '餐桌为中心，暖黄日光',
    vibe: '吃饭的地方，也该有一点仪式感',
    image: 'assets/styles/style-dining.jpg',
    tags: ['餐厅', '暖光', '生活'],
    scenes: [
      StyleScene(image: 'assets/styles/style-dining.jpg', room: '餐厅'),
      StyleScene(image: 'assets/styles/style-night.jpg', room: '夜餐厅'),
      StyleScene(image: 'assets/styles/style-sofa.jpg', room: '起居'),
      StyleScene(image: 'assets/styles/style-hearth.jpg', room: '暖厅'),
    ],
  ),
  HouseStyle(
    id: 'bath',
    name: '现代卫浴',
    hint: '干净瓷面，光线柔和',
    vibe: '洗澡也像进了一间小酒店',
    image: 'assets/styles/style-bath.jpg',
    tags: ['卫浴', '干净', '明亮'],
    scenes: [
      StyleScene(image: 'assets/styles/style-bath.jpg', room: '卫浴'),
      StyleScene(image: 'assets/styles/style-spa.jpg', room: '浴室'),
      StyleScene(image: 'assets/styles/style-blush.jpg', room: '柔粉卫浴'),
      StyleScene(image: 'assets/styles/style-white.jpg', room: '通透厅'),
    ],
  ),
  HouseStyle(
    id: 'glass',
    name: '玻璃花房',
    hint: '绿意与通透，适合阳台',
    vibe: '把一点植物和天空请进家里',
    image: 'assets/styles/style-glass.jpg',
    tags: ['阳台', '绿意', '通透'],
    scenes: [
      StyleScene(image: 'assets/styles/style-glass.jpg', room: '花房'),
      StyleScene(image: 'assets/styles/style-sea.jpg', room: '阳台'),
      StyleScene(image: 'assets/styles/style-walk.jpg', room: '廊道'),
      StyleScene(image: 'assets/styles/style-foyer.jpg', room: '门厅'),
    ],
  ),
  HouseStyle(
    id: 'kominka',
    name: '和式木作',
    hint: '木色细作，安静克制',
    vibe: '木头本身就是最好的装饰',
    image: 'assets/styles/style-kominka.jpg',
    tags: ['原木', '安静', '日式'],
    scenes: [
      StyleScene(image: 'assets/styles/style-kominka.jpg', room: '木作'),
      StyleScene(image: 'assets/styles/style-wood.jpg', room: '原木厅'),
      StyleScene(image: 'assets/styles/style-wabi.jpg', room: '素色厅'),
      StyleScene(image: 'assets/styles/style-quiet.jpg', room: '静室'),
    ],
  ),
  HouseStyle(
    id: 'sofa',
    name: '暖光起居',
    hint: '沙发区为主，适合会客',
    vibe: '先坐下来，空间才开始像家',
    image: 'assets/styles/style-sofa.jpg',
    tags: ['客厅', '暖光', '会客'],
    scenes: [
      StyleScene(image: 'assets/styles/style-sofa.jpg', room: '沙发厅'),
      StyleScene(image: 'assets/styles/style-aft.jpg', room: '休闲厅'),
      StyleScene(image: 'assets/styles/style-amber.jpg', room: '暮色厅'),
      StyleScene(image: 'assets/styles/style-dining.jpg', room: '餐厅'),
    ],
  ),
  HouseStyle(
    id: 'atelier',
    name: '艺术书房',
    hint: '墙面与光线留给创作',
    vibe: '书桌旁边，留一点看得到的空白',
    image: 'assets/styles/style-atelier.jpg',
    tags: ['书房', '创作', '光线'],
    scenes: [
      StyleScene(image: 'assets/styles/style-atelier.jpg', room: '工作室'),
      StyleScene(image: 'assets/styles/style-french.jpg', room: '书房'),
      StyleScene(image: 'assets/styles/style-loft.jpg', room: '工坊'),
      StyleScene(image: 'assets/styles/style-quiet.jpg', room: '静室'),
    ],
  ),
  HouseStyle(
    id: 'hearth',
    name: '壁炉暖厅',
    hint: '夜色与暖光，适合夜里',
    vibe: '灯暗下来，客厅就换了一种脾气',
    image: 'assets/styles/style-hearth.jpg',
    tags: ['夜色', '暖光', '沉浸'],
    scenes: [
      StyleScene(image: 'assets/styles/style-hearth.jpg', room: '壁炉厅'),
      StyleScene(image: 'assets/styles/style-night.jpg', room: '夜餐厅'),
      StyleScene(image: 'assets/styles/style-amber.jpg', room: '暮色厅'),
      StyleScene(image: 'assets/styles/style-aft.jpg', room: '休闲厅'),
    ],
  ),
];

HouseStyle? styleById(String id) {
  for (final style in houseStyles) {
    if (style.id == id) return style;
  }
  return null;
}

/// 与所选风格同气质的实景 id，供后端 VR 轮换。
const styleFamilies = <String, List<String>>{
  'modern': ['modern', 'white', 'air', 'quiet', 'bath', 'spa'],
  'wood': ['wood', 'kominka', 'wabi', 'sofa', 'atelier'],
  'cream': ['cream', 'sofa', 'suite', 'quiet', 'dining'],
  'green': ['green', 'aft', 'dining', 'amber', 'sofa'],
  'white': ['white', 'air', 'foyer', 'spa', 'modern'],
  'night': ['night', 'hearth', 'amber', 'dining'],
  'french': ['french', 'luxe', 'sofa', 'atelier'],
  'loft': ['loft', 'atelier', 'walk', 'foyer'],
  'luxe': ['luxe', 'french', 'dining', 'suite'],
  'sea': ['sea', 'suite', 'glass', 'walk'],
  'wabi': ['wabi', 'kominka', 'wood', 'quiet'],
  'blush': ['blush', 'cream', 'spa', 'suite'],
  'suite': ['suite', 'sea', 'cream', 'glass'],
  'dining': ['dining', 'night', 'sofa', 'hearth'],
  'bath': ['bath', 'spa', 'blush', 'white'],
  'glass': ['glass', 'sea', 'walk', 'foyer'],
  'kominka': ['kominka', 'wood', 'wabi', 'quiet'],
  'sofa': ['sofa', 'aft', 'amber', 'dining'],
  'atelier': ['atelier', 'french', 'loft', 'quiet'],
  'hearth': ['hearth', 'night', 'amber', 'aft'],
};
