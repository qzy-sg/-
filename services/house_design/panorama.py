"""等距柱状全景图（2:1）。先用本地 procedural 图，不依赖外部图像模型。"""

from __future__ import annotations

import hashlib
import hmac
import math
import time
from io import BytesIO

from PIL import Image, ImageDraw

from house_design.config import get_settings


# 房间底色保持偏亮，球面环视时不会发黑。
ROOM_STYLES = {
    "客厅": {"wall": (214, 198, 178), "floor": (186, 154, 118), "accent": (156, 112, 82), "light": (255, 248, 236), "fabric": (168, 118, 92), "wood": (138, 98, 68)},
    "主卧": {"wall": (206, 198, 190), "floor": (176, 156, 138), "accent": (150, 122, 108), "light": (250, 244, 236), "fabric": (176, 150, 142), "wood": (128, 96, 78)},
    "次卧": {"wall": (198, 206, 204), "floor": (170, 162, 150), "accent": (132, 148, 146), "light": (246, 250, 248), "fabric": (154, 168, 166), "wood": (120, 108, 96)},
    "儿童": {"wall": (214, 206, 188), "floor": (190, 168, 136), "accent": (196, 154, 112), "light": (255, 248, 230), "fabric": (186, 146, 118), "wood": (150, 112, 78)},
    "厨房": {"wall": (214, 220, 214), "floor": (168, 176, 170), "accent": (112, 146, 136), "light": (244, 252, 246), "fabric": (150, 170, 160), "wood": (120, 132, 124)},
    "餐厅": {"wall": (210, 196, 176), "floor": (178, 148, 112), "accent": (146, 104, 74), "light": (255, 244, 226), "fabric": (160, 118, 90), "wood": (132, 92, 62)},
    "卫生间": {"wall": (214, 220, 222), "floor": (176, 186, 188), "accent": (140, 164, 168), "light": (246, 252, 252), "fabric": (180, 196, 198), "wood": (150, 160, 162)},
    "卫浴": {"wall": (214, 220, 222), "floor": (176, 186, 188), "accent": (140, 164, 168), "light": (246, 252, 252), "fabric": (180, 196, 198), "wood": (150, 160, 162)},
    "书房": {"wall": (196, 188, 172), "floor": (150, 122, 92), "accent": (108, 86, 64), "light": (248, 240, 224), "fabric": (140, 116, 96), "wood": (102, 76, 54)},
    "阳台": {"wall": (198, 210, 204), "floor": (168, 176, 164), "accent": (120, 150, 128), "light": (236, 248, 242), "fabric": (150, 176, 154), "wood": (130, 118, 96)},
    "default": {"wall": (206, 198, 186), "floor": (178, 162, 142), "accent": (150, 124, 98), "light": (252, 246, 236), "fabric": (164, 136, 112), "wood": (132, 102, 76)},
}

STYLE_OVERLAYS = {
    "奶油": {"wall": (226, 210, 190), "floor": (204, 176, 142), "fabric": (186, 150, 122), "light": (255, 250, 240)},
    "木质": {"wall": (188, 164, 140), "floor": (124, 88, 60), "fabric": (118, 84, 62), "wood": (96, 68, 46), "light": (255, 236, 210)},
    "原木": {"wall": (188, 164, 140), "floor": (124, 88, 60), "fabric": (118, 84, 62), "wood": (96, 68, 46), "light": (255, 236, 210)},
    "通透": {"wall": (236, 234, 228), "floor": (214, 210, 202), "fabric": (206, 208, 204), "light": (255, 255, 252)},
    "白色": {"wall": (236, 234, 228), "floor": (214, 210, 202), "fabric": (206, 208, 204), "light": (255, 255, 252)},
}

MAX_PANORAMA_ROOMS = 6


def _style_for(name: str, style: str | None = None) -> dict:
    palette = dict(ROOM_STYLES["default"])
    for key, colors in ROOM_STYLES.items():
        if key != "default" and key in name:
            palette = dict(colors)
            break
    hint = style or ""
    for key, overlay in STYLE_OVERLAYS.items():
        if key in hint or key in name:
            palette.update(overlay)
            break
    return palette


def _mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(a[0] + (b[0] - a[0]) * t),
        int(a[1] + (b[1] - a[1]) * t),
        int(a[2] + (b[2] - a[2]) * t),
    )


def _kind(name: str) -> str:
    text = str(name or "")
    # 复合名优先：书房/小卧室、客餐厅 等。
    rules = (
        ("卫浴", ("卫生间", "卫浴", "厕所", "浴室")),
        ("厨房", ("厨房", "厨")),
        ("餐厅", ("餐厅", "饭厅", "客餐厅")),
        ("书房", ("书房", "工作室", "衣帽")),
        ("阳台", ("阳台", "露台")),
        ("儿童", ("儿童", "小孩")),
        ("次卧", ("次卧", "小卧", "客卧")),
        ("主卧", ("主卧", "卧室")),
        ("客厅", ("客厅", "起居", "大厅")),
    )
    for kind, words in rules:
        if any(word in text for word in words):
            return kind
    if "卫" in text:
        return "卫浴"
    if "卧" in text:
        return "次卧"
    return "客厅"


def _area_scale(area_sqm: float | None) -> float:
    if not isinstance(area_sqm, (int, float)) or area_sqm <= 0:
        return 1.0
    return max(0.82, min(1.22, float(area_sqm) / 16.0))


def build_panorama_jpeg(
    room_name: str,
    area_sqm: float | None = None,
    width: int = 1920,
    height: int = 960,
    style: str | None = None,
) -> bytes:
    """按房型画一张可环视的室内示意全景。颜色必须够亮，避免看起来像黑屏。"""
    palette = _style_for(room_name, style)
    wall = palette["wall"]
    floor = palette["floor"]
    light = palette["light"]
    accent = palette["accent"]
    fabric = palette["fabric"]
    wood = palette["wood"]
    scale = _area_scale(area_sqm)
    kind = _kind(room_name)

    image = Image.new("RGB", (width, height), wall)
    draw = ImageDraw.Draw(image)
    horizon = int(height * 0.58)
    ceil = int(height * 0.2)
    panel = width // 4

    draw.rectangle([0, 0, width, int(height * 0.08)], fill=_mix(light, (255, 255, 255), 0.35))
    draw.rectangle([0, int(height * 0.08), width, ceil], fill=_mix(light, wall, 0.22))
    draw.rectangle([0, ceil, width, horizon], fill=wall)
    draw.rectangle([0, horizon - 14, width, horizon], fill=_mix(wood, accent, 0.35))
    draw.rectangle([0, horizon, width, int(height * 0.78)], fill=floor)
    draw.rectangle([0, int(height * 0.78), width, height], fill=_mix(floor, wood, 0.28))

    for i in range(4):
        x0 = i * panel + 18
        x1 = (i + 1) * panel - 18
        shade = _mix(wall, light, 0.08 if i % 2 == 0 else 0.2)
        draw.rectangle([x0, ceil + 16, x1, horizon - 22], fill=shade)

    _window(draw, panel + 70, int(height * 0.26), panel + int(280 * scale), horizon - 70, light)
    _ceiling_lights(draw, width, int(height * 0.1), light)
    _furnish(draw, kind, width, height, horizon, panel, scale, fabric, wood, accent, light, wall)

    font = _label_font(36)
    label = f"{room_name} · 室内示意"
    if isinstance(area_sqm, (int, float)) and area_sqm > 0:
        label = f"{room_name} · {area_sqm:g}㎡ · 室内示意"
    draw.rounded_rectangle([28, 22, 28 + 520, 78], radius=14, fill=(20, 40, 36))
    draw.text((46, 34), label, fill=(255, 248, 236), font=font)

    out = BytesIO()
    image.save(out, format="JPEG", quality=88)
    return out.getvalue()


def _window(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, light: tuple[int, int, int]) -> None:
    glass = (176, 208, 220)
    draw.rectangle([x0 - 16, y0 - 10, x1 + 16, y1 + 8], fill=_mix(light, (255, 255, 255), 0.2))
    draw.rectangle([x0, y0, x1, y1], fill=glass)
    mid_x = (x0 + x1) // 2
    mid_y = (y0 + y1) // 2
    draw.line([(mid_x, y0), (mid_x, y1)], fill=(255, 255, 255), width=6)
    draw.line([(x0, mid_y), (x1, mid_y)], fill=(255, 255, 255), width=6)
    draw.rectangle([x0, y0, x1, y1], outline=(255, 255, 255), width=8)
    # 窗帘
    draw.rectangle([x0 - 28, y0 - 18, x0 + 18, y1 + 20], fill=(232, 220, 204))
    draw.rectangle([x1 - 18, y0 - 18, x1 + 28, y1 + 20], fill=(232, 220, 204))


def _ceiling_lights(draw: ImageDraw.ImageDraw, width: int, y: int, light: tuple[int, int, int]) -> None:
    for cx in (width // 4, width // 2, 3 * width // 4):
        draw.line([(cx, 8), (cx, y - 18)], fill=(220, 210, 190), width=3)
        draw.ellipse([cx - 46, y - 18, cx + 46, y + 16], fill=light)
        draw.ellipse([cx - 16, y - 6, cx + 16, y + 8], fill=(255, 255, 255))


def _furnish(draw, kind, width, height, horizon, panel, scale, fabric, wood, accent, light, wall) -> None:
    if kind == "厨房":
        _kitchen(draw, width, height, horizon, panel, scale, wood, accent, light, wall)
    elif kind == "卫浴":
        _bath(draw, width, height, horizon, panel, scale, wood, accent, light, wall)
    elif kind == "书房":
        _study(draw, width, height, horizon, panel, scale, fabric, wood, accent, light)
    elif kind == "餐厅":
        _dining(draw, width, height, horizon, panel, scale, fabric, wood, accent)
    elif kind == "阳台":
        _balcony(draw, width, height, horizon, panel, scale, fabric, wood, accent, light)
    elif kind in {"主卧", "次卧", "儿童"}:
        _bedroom(draw, width, height, horizon, panel, scale, fabric, wood, accent, light, small=kind != "主卧")
    else:
        _living(draw, width, height, horizon, panel, scale, fabric, wood, accent, light)


def _living(draw, width, height, horizon, panel, scale, fabric, wood, accent, light) -> None:
    sofa_w = int(panel * 0.72 * scale)
    sofa_h = int(height * 0.2)
    x = int(panel * 0.14)
    y = horizon - int(sofa_h * 0.42)
    draw.rounded_rectangle([x, y, x + sofa_w, y + sofa_h], radius=22, fill=fabric)
    draw.rounded_rectangle([x + 18, y - int(36 * scale), x + sofa_w - 18, y + 28], radius=16, fill=_mix(fabric, (40, 28, 20), 0.22))
    draw.rounded_rectangle([x + 28, y + 8, x + int(sofa_w * 0.38), y + 48], radius=10, fill=_mix(light, fabric, 0.35))
    # 茶几 + 地毯
    rug = [int(panel * 0.08), horizon + 18, int(panel * 0.92), horizon + int(height * 0.16)]
    draw.rounded_rectangle(rug, radius=18, fill=_mix(accent, light, 0.25))
    table = [x + 40, horizon + 8, x + sofa_w - 20, horizon + int(70 * scale)]
    draw.rounded_rectangle(table, radius=12, fill=wood)
    # 电视墙
    tv_x = panel * 2 + int(panel * 0.18)
    tv_w = int(panel * 0.62)
    tv_top = int(height * 0.28)
    draw.rectangle([tv_x - 16, horizon - 28, tv_x + tv_w + 16, horizon + 8], fill=wood)
    draw.rounded_rectangle([tv_x, tv_top, tv_x + tv_w, horizon - 48], radius=8, fill=(46, 58, 56))
    draw.rectangle([tv_x + 18, tv_top + 16, tv_x + tv_w - 18, horizon - 78], fill=(120, 156, 150))
    # 绿植
    _plant(draw, panel * 3 + int(panel * 0.55), horizon, int(70 * scale), accent)


def _bedroom(draw, width, height, horizon, panel, scale, fabric, wood, accent, light, small: bool) -> None:
    bed_w = int(panel * (0.62 if small else 0.78) * scale)
    bed_h = int(height * 0.18)
    x = int(panel * 0.12)
    y = horizon - int(bed_h * 0.2)
    draw.rectangle([x - 10, y - int(90 * scale), x + bed_w + 10, y + 8], fill=wood)
    draw.rounded_rectangle([x, y, x + bed_w, y + bed_h], radius=16, fill=(236, 230, 220))
    draw.rounded_rectangle([x + 16, y + 10, x + int(bed_w * 0.42), y + 52], radius=12, fill=fabric)
    draw.rounded_rectangle([x + int(bed_w * 0.5), y + 10, x + bed_w - 16, y + 52], radius=12, fill=_mix(fabric, light, 0.3))
    # 床头柜
    stand_w = int(70 * scale)
    draw.rectangle([x + bed_w + 16, y + 10, x + bed_w + 16 + stand_w, horizon + 6], fill=wood)
    draw.ellipse([x + bed_w + 28, y - 8, x + bed_w + stand_w, y + 28], fill=light)
    # 衣柜
    wx = panel * 2 + 40
    draw.rectangle([wx, int(height * 0.26), wx + int(panel * 0.55), horizon - 16], fill=wood)
    draw.line([(wx + int(panel * 0.27), int(height * 0.26)), (wx + int(panel * 0.27), horizon - 16)], fill=_mix(wood, (255, 255, 255), 0.35), width=4)
    draw.rounded_rectangle([panel * 3 + 50, horizon + 20, panel * 3 + int(panel * 0.7), horizon + int(90 * scale)], radius=14, fill=accent)


def _kitchen(draw, width, height, horizon, panel, scale, wood, accent, light, wall) -> None:
    top = int(height * 0.3)
    counter = horizon - int(36 * scale)
    draw.rectangle([24, top, panel - 24, counter], fill=_mix(wall, (255, 255, 255), 0.35))
    draw.rectangle([24, counter, panel - 24, horizon + 10], fill=wood)
    draw.rectangle([40, top + 12, panel // 2 - 10, counter - 16], fill=accent)
    draw.rectangle([panel // 2 + 8, top + 12, panel - 40, counter - 16], fill=_mix(accent, light, 0.25))
    # 岛台
    draw.rounded_rectangle([panel * 2 + 50, horizon - 10, panel * 2 + int(panel * 0.7), horizon + int(80 * scale)], radius=12, fill=wood)
    draw.ellipse([panel * 2 + 80, horizon + 8, panel * 2 + 150, horizon + 48], fill=(210, 214, 208))
    _plant(draw, panel * 3 + int(panel * 0.62), horizon, int(56 * scale), accent)


def _dining(draw, width, height, horizon, panel, scale, fabric, wood, accent) -> None:
    cx = panel // 2
    cy = horizon + int(36 * scale)
    rw = int(panel * 0.28 * scale)
    rh = int(height * 0.07)
    draw.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=wood)
    for dx, dy in ((-rw - 10, 0), (rw - 20, 0), (0, -rh - 8), (0, rh - 8)):
        draw.rounded_rectangle([cx + dx - 16, cy + dy - 18, cx + dx + 22, cy + dy + 22], radius=8, fill=fabric)
    draw.rectangle([panel * 2 + 36, int(height * 0.32), panel * 2 + int(panel * 0.62), horizon - 20], fill=wood)
    draw.rectangle([panel * 3 + 40, horizon + 16, panel * 3 + int(panel * 0.55), horizon + 70], fill=accent)


def _bath(draw, width, height, horizon, panel, scale, wood, accent, light, wall) -> None:
    draw.rectangle([30, int(height * 0.34), panel - 30, horizon + 8], fill=_mix(wall, (255, 255, 255), 0.45))
    draw.rectangle([48, horizon - 20, panel - 48, horizon + 16], fill=wood)
    draw.ellipse([panel // 2 - 36, horizon - 8, panel // 2 + 36, horizon + 28], fill=(210, 224, 226))
    draw.rounded_rectangle([panel // 2 - 70, int(height * 0.28), panel // 2 + 70, int(height * 0.46)], radius=8, fill=(186, 206, 210))
    # 淋浴隔断
    sx = panel * 2 + 40
    draw.rectangle([sx, int(height * 0.24), sx + int(panel * 0.5), horizon - 12], fill=(196, 220, 224))
    draw.rectangle([sx, int(height * 0.24), sx + int(panel * 0.5), horizon - 12], outline=(255, 255, 255), width=6)
    draw.rectangle([panel * 3 + 36, int(height * 0.36), panel * 3 + int(panel * 0.7), horizon - 24], fill=accent)


def _study(draw, width, height, horizon, panel, scale, fabric, wood, accent, light) -> None:
    draw.rectangle([36, horizon - int(70 * scale), int(panel * 0.78), horizon + 12], fill=wood)
    draw.rounded_rectangle([int(panel * 0.28), horizon - int(20 * scale), int(panel * 0.55), horizon + int(80 * scale)], radius=10, fill=fabric)
    draw.ellipse([int(panel * 0.48), horizon - int(110 * scale), int(panel * 0.7), horizon - int(70 * scale)], fill=light)
    bx = panel * 2 + 28
    shelf_top = int(height * 0.24)
    draw.rectangle([bx, shelf_top, bx + int(panel * 0.62), horizon - 18], fill=wood)
    for i in range(4):
        y = shelf_top + 16 + i * int((horizon - 18 - shelf_top) / 4)
        draw.line([(bx + 8, y), (bx + int(panel * 0.62) - 8, y)], fill=_mix(wood, light, 0.4), width=3)
        draw.rectangle([bx + 16, y + 6, bx + 70, y + 28], fill=accent)
        draw.rectangle([bx + 84, y + 8, bx + 150, y + 26], fill=_mix(accent, light, 0.3))
    _plant(draw, panel * 3 + int(panel * 0.6), horizon, int(60 * scale), accent)


def _balcony(draw, width, height, horizon, panel, scale, fabric, wood, accent, light) -> None:
    rail_y = horizon - int(20 * scale)
    draw.rectangle([20, rail_y, panel - 20, rail_y + 16], fill=(210, 214, 208))
    for x in range(36, panel - 36, 28):
        draw.rectangle([x, int(height * 0.34), x + 8, rail_y], fill=(220, 224, 218))
    draw.rounded_rectangle([panel * 2 + 40, horizon - int(30 * scale), panel * 2 + int(panel * 0.42), horizon + int(70 * scale)], radius=14, fill=fabric)
    _plant(draw, int(panel * 0.2), horizon, int(80 * scale), accent)
    _plant(draw, panel * 3 + int(panel * 0.35), horizon, int(90 * scale), _mix(accent, (80, 120, 90), 0.2))
    _plant(draw, panel * 3 + int(panel * 0.62), horizon, int(64 * scale), accent)


def _plant(draw: ImageDraw.ImageDraw, cx: int, horizon: int, size: int, green: tuple[int, int, int]) -> None:
    draw.rectangle([cx - 14, horizon - 8, cx + 14, horizon + 28], fill=(150, 118, 86))
    draw.ellipse([cx - size, horizon - size - 20, cx + size // 3, horizon - 6], fill=green)
    draw.ellipse([cx - size // 3, horizon - int(size * 1.15) - 10, cx + size, horizon - 10], fill=_mix(green, (255, 255, 255), 0.18))


PHOTO_STYLES = {
    "modern": ("现代", "简约", "通透客厅"),
    "wood": ("原木", "木质", "收纳", "日式"),
    "cream": ("奶油", "暖", "安静"),
    "green": ("中古", "绿"),
    "white": ("极简", "白色", "通透", "留白"),
    "night": ("夜色", "夜"),
    "french": ("法式", "仪式"),
    "loft": ("工业", "砖墙"),
    "luxe": ("意式", "石材"),
    "sea": ("地中海", "度假"),
    "wabi": ("侘寂", "素雅"),
    "blush": ("柔粉", "粉色"),
    "bath": ("卫浴", "浴室"),
    "spa": ("卫浴", "简约卫浴"),
    "sofa": ("起居", "沙发"),
    "suite": ("套房", "海景", "卧室"),
    "hearth": ("壁炉", "暖厅"),
    "dining": ("餐厅", "用餐"),
    "atelier": ("书房", "艺术"),
    "air": ("留白", "空房"),
    "quiet": ("静谧", "小室"),
    "foyer": ("玄关", "进门"),
    "walk": ("走廊", "阳台"),
    "glass": ("花房", "绿意"),
    "amber": ("暮色", "暖色客厅"),
    "aft": ("休闲", "起居"),
    "kominka": ("和式", "木作", "原木"),
}

# 选中某风格后，同气质实景可轮换，避免整套 VR 锁死一张封面。
STYLE_FAMILIES = {
    "modern": ("modern", "white", "air", "quiet", "bath", "spa"),
    "wood": ("wood", "kominka", "wabi", "sofa", "atelier"),
    "cream": ("cream", "sofa", "suite", "quiet", "dining"),
    "green": ("green", "aft", "dining", "amber", "sofa"),
    "white": ("white", "air", "foyer", "spa", "modern"),
    "night": ("night", "hearth", "amber", "dining"),
    "french": ("french", "luxe", "sofa", "atelier"),
    "loft": ("loft", "atelier", "walk", "foyer"),
    "luxe": ("luxe", "french", "dining", "suite"),
    "sea": ("sea", "suite", "glass", "walk"),
    "wabi": ("wabi", "kominka", "wood", "quiet"),
    "blush": ("blush", "cream", "spa", "suite"),
    "suite": ("suite", "sea", "cream", "glass"),
    "dining": ("dining", "night", "sofa", "hearth"),
    "bath": ("bath", "spa", "blush", "white"),
    "glass": ("glass", "sea", "walk", "foyer"),
    "kominka": ("kominka", "wood", "wabi", "quiet"),
    "sofa": ("sofa", "aft", "amber", "dining"),
    "atelier": ("atelier", "french", "loft", "quiet"),
    "hearth": ("hearth", "night", "amber", "aft"),
}

# 房型默认偏好：先同类实景，再按风格排序。
ROOM_STYLE_PREFERENCE = {
    "客厅": ["sofa", "amber", "aft", "wood", "green", "hearth", "white", "luxe", "kominka", "foyer", "modern", "wabi", "night"],
    "主卧": ["suite", "cream", "quiet", "modern", "wabi", "wood", "kominka", "white"],
    "次卧": ["air", "quiet", "modern", "cream", "suite", "wood", "white"],
    "儿童": ["air", "cream", "modern", "quiet", "white", "wood"],
    "厨房": ["dining", "night", "white", "wood", "modern", "sofa"],
    "餐厅": ["dining", "night", "sofa", "wood", "green", "luxe", "hearth", "cream"],
    "卫浴": ["bath", "spa", "blush", "white", "modern", "cream"],
    "书房": ["atelier", "french", "loft", "wood", "quiet", "air", "wabi", "kominka", "green"],
    "阳台": ["glass", "walk", "sea", "suite", "white", "foyer", "loft", "modern"],
}


def reference_panorama_dir():
    from house_design.runtime import repo_root

    return repo_root() / "webview-vr" / "panoramas"


def load_photo_catalog() -> list[dict]:
    path = reference_panorama_dir() / "catalog.json"
    if not path.is_file():
        return []
    try:
        import json

        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, list) else []
    except Exception:
        return []


def _style_boost_score(style_id: str, design_style: str | None) -> int:
    hint = (design_style or "").lower()
    if not hint:
        return 0
    score = 0
    # 精确命中仍加分，但不要压过「未用过 + 同房型」。
    if style_id in hint:
        score += 28
    words = PHOTO_STYLES.get(style_id, ())
    if any(word in (design_style or "") for word in words):
        score += 18
    # 同气质家族：选了 modern 时 white/air 也可轮换。
    for root, family in STYLE_FAMILIES.items():
        if root in hint or any(word in (design_style or "") for word in PHOTO_STYLES.get(root, ())):
            if style_id in family:
                score += 22
            break
    return score


def pick_reference_style(room_name: str, design_style: str | None, used: set[str]) -> tuple[str | None, dict]:
    """按房间类型认图：先匹配房型，再贴近所选风格家族，尽量不重复。"""
    folder = reference_panorama_dir()
    kind = _kind(room_name)
    catalog = load_photo_catalog()
    available: list[dict] = []
    for item in catalog:
        style_id = str(item.get("style_id") or "")
        file_name = str(item.get("file") or f"style-{style_id}.jpg")
        path = folder / file_name
        if not style_id or not path.is_file() or path.stat().st_size < 20_000:
            continue
        kinds = [str(k) for k in (item.get("room_kinds") or [])]
        available.append({**item, "style_id": style_id, "file": file_name, "room_kinds": kinds, "path": path})

    if not available:
        return None, {"matched_kind": kind, "match": "none"}

    same_kind = [item for item in available if kind in item["room_kinds"]]
    pool = same_kind or available
    preferred = ROOM_STYLE_PREFERENCE.get(kind, [])

    def rank(item: dict) -> tuple:
        style_id = item["style_id"]
        unused = 0 if style_id in used else 1
        style_hit = _style_boost_score(style_id, design_style)
        kind_hit = 1 if kind in item["room_kinds"] else 0
        pref = len(preferred) - preferred.index(style_id) if style_id in preferred else 0
        # 未用过优先，再房型，再气质，最后默认偏好。
        return (unused, kind_hit, style_hit, pref)

    pool.sort(key=rank, reverse=True)
    best = pool[0]
    return best["style_id"], {
        "matched_kind": kind,
        "match": "room_kind" if same_kind else "fallback_style",
        "scene_label": str(best.get("room") or best["style_id"]),
        "source_slug": str(best.get("source_slug") or ""),
    }


def load_reference_jpeg(style_id: str) -> bytes | None:
    folder = reference_panorama_dir()
    path = folder / f"style-{style_id}.jpg"
    if not path.is_file() or path.stat().st_size < 20_000:
        for item in load_photo_catalog():
            if str(item.get("style_id")) == style_id:
                alt = folder / str(item.get("file") or "")
                if alt.is_file() and alt.stat().st_size >= 20_000:
                    return alt.read_bytes()
        return None
    return path.read_bytes()


def build_scene_panorama(
    room_name: str,
    area_sqm: float | None = None,
    style: str | None = None,
    used: set[str] | None = None,
) -> tuple[bytes, dict]:
    """按已确认房间类型匹配实景等距柱状图；没有合适照片时退回程序示意。"""
    taken = used if used is not None else set()
    style_id, match = pick_reference_style(room_name, style, taken)
    photo = load_reference_jpeg(style_id) if style_id else None
    if photo and style_id:
        taken.add(style_id)
        return photo, {
            "visual": "photo",
            "style_id": style_id,
            "room_kind": match.get("matched_kind"),
            "scene_label": match.get("scene_label"),
            "match": match.get("match"),
            "license": "CC0",
            "credit": "Poly Haven",
        }
    return build_panorama_jpeg(room_name, area_sqm, style=style), {
        "visual": "sketch",
        "room_kind": _kind(room_name),
        "match": "sketch",
    }


def still_from_equirect(data: bytes, width: int = 800, height: int = 450, fov_deg: float = 70) -> bytes:
    """从等距柱状全景取出正前方一帧，存成普通横图，不是全景。"""
    image = Image.open(BytesIO(data)).convert("RGB")
    src_w, src_h = image.size
    if src_w > 2048:
        src_h = max(2, int(src_h * 2048 / src_w))
        src_w = 2048
        image = image.resize((src_w, src_h), Image.Resampling.BILINEAR)
    src = image.load()
    out = Image.new("RGB", (width, height))
    dest = out.load()
    tan_half = math.tan(math.radians(fov_deg) / 2)
    aspect = width / height
    for y in range(height):
        ny = (0.5 - (y + 0.5) / height) * 2 * tan_half
        for x in range(width):
            nx = ((x + 0.5) / width - 0.5) * 2 * tan_half * aspect
            length = math.sqrt(nx * nx + ny * ny + 1.0)
            vx = nx / length
            vy = ny / length
            vz = 1.0 / length
            lon = math.atan2(vx, vz)
            lat = math.asin(max(-1.0, min(1.0, vy)))
            sx = int((lon / (2 * math.pi) + 0.5) * src_w) % src_w
            sy = min(src_h - 1, max(0, int((0.5 - lat / math.pi) * src_h)))
            dest[x, y] = src[sx, sy]
    buf = BytesIO()
    out.save(buf, format="JPEG", quality=86, optimize=True)
    return buf.getvalue()


def build_room_still(
    room_name: str,
    area_sqm: float | None = None,
    style: str | None = None,
    used: set[str] | None = None,
) -> tuple[bytes, dict]:
    """每个房间一张正面效果图。优先抽实景全景，没有照片时用示意全景再抽一帧。"""
    taken = used if used is not None else set()
    style_id, match = pick_reference_style(room_name, style, taken)
    photo = load_reference_jpeg(style_id) if style_id else None
    if photo and style_id:
        taken.add(style_id)
        return still_from_equirect(photo), {
            "visual": "photo",
            "style_id": style_id,
            "room_kind": match.get("matched_kind"),
            "scene_label": match.get("scene_label"),
            "match": match.get("match"),
            "license": "CC0",
            "credit": "Poly Haven",
        }
    return still_from_equirect(build_panorama_jpeg(room_name, area_sqm, style=style)), {
        "visual": "sketch",
        "room_kind": _kind(room_name),
        "match": "sketch",
    }


def sign_render_url(task_id: str, room_id: str) -> tuple[str, int]:
    settings = get_settings()
    expires = int(time.time()) + int(settings.panorama_url_seconds)
    sig = _render_sig(task_id, room_id, expires)
    return f"/api/v1/renders/{task_id}/shots/{room_id}.jpg?exp={expires}&sig={sig}", expires


def verify_render_url(task_id: str, room_id: str, expires: int, signature: str) -> bool:
    if not signature or expires < int(time.time()):
        return False
    expected = _render_sig(task_id, room_id, expires)
    return hmac.compare_digest(expected, signature)


def _render_sig(task_id: str, room_id: str, expires: int) -> str:
    message = f"render.{task_id}.{room_id}.{expires}".encode()
    secret = get_settings().jwt_secret.encode()
    return hmac.new(secret, message, hashlib.sha256).hexdigest()


def present_render(task_id: str, result: dict) -> dict:
    """给效果图补上短期可打开的地址。结果里不保存过期链接。"""
    shots = []
    for item in result.get("shots") or []:
        if not isinstance(item, dict):
            continue
        row = dict(item)
        room_id = str(row.get("room_id") or "")
        if room_id and all(ch not in room_id for ch in "/\\."):
            url, expires = sign_render_url(task_id, room_id)
            row["url"] = url
            row["expires_at"] = expires
        shots.append(row)
    presented = dict(result)
    presented["shots"] = shots
    presented["is_panorama"] = False
    if shots and shots[0].get("url"):
        presented["url"] = shots[0]["url"]
    return presented


def _label_font(size: int):
    from PIL import ImageFont

    for path in (
        r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\msyhbd.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def panoramas_from_rooms(rooms: list) -> list[dict]:
    """从已确认房间生成全景清单。主要空间最多 6 间。"""
    items: list[dict] = []
    for room in rooms:
        name = getattr(room, "name", None) or (room.get("name") if isinstance(room, dict) else "房间")
        area = getattr(room, "area_sqm", None)
        if area is None and isinstance(room, dict):
            area = room.get("area_sqm")
        rid = getattr(room, "id", None) or (room.get("id") if isinstance(room, dict) else None)
        items.append(
            {
                "room_id": str(rid or f"room_{len(items)+1}"),
                "name": str(name)[:40],
                "area_sqm": float(area) if isinstance(area, (int, float)) else None,
            }
        )
        if len(items) >= MAX_PANORAMA_ROOMS:
            break
    if not items:
        items = [{"room_id": "room_living", "name": "客厅", "area_sqm": 18.0}]
    return items


def sign_panorama_url(scene_id: str, room_id: str) -> tuple[str, int]:
    settings = get_settings()
    expires = int(time.time()) + int(settings.panorama_url_seconds)
    sig = _panorama_sig(scene_id, room_id, expires)
    return f"/api/v1/scenes/{scene_id}/panoramas/{room_id}.jpg?exp={expires}&sig={sig}", expires


def verify_panorama_url(scene_id: str, room_id: str, expires: int, signature: str) -> bool:
    if not signature or expires < int(time.time()):
        return False
    expected = _panorama_sig(scene_id, room_id, expires)
    return hmac.compare_digest(expected, signature)


def _panorama_sig(scene_id: str, room_id: str, expires: int) -> str:
    message = f"{scene_id}.{room_id}.{expires}".encode()
    secret = get_settings().jwt_secret.encode()
    return hmac.new(secret, message, hashlib.sha256).hexdigest()


def jpeg_mean_luma(path) -> float | None:
    """返回 JPEG 平均亮度 0-255。文件坏了就返回 None。"""
    try:
        with Image.open(path) as image:
            rgb = image.convert("RGB")
            # 抽样，避免大图扫全像素太慢
            sample = rgb.resize((64, 32))
            pixels = list(sample.getdata())
        if not pixels:
            return None
        return sum(0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in pixels) / len(pixels)
    except Exception:
        return None


def scene_files_usable(scene_id: str, panoramas: list, *, min_luma: float = 48.0) -> bool:
    """旧版过暗 / 缺文件的全景视为不可用，让客户端重新生成。"""
    from pathlib import Path

    from house_design.runtime import repo_root

    folder = repo_root() / ".local-assets" / "scenes" / scene_id / "panoramas"
    if not panoramas:
        return False
    for item in panoramas:
        room_id = str((item or {}).get("room_id") or "")
        if not room_id or any(ch in room_id for ch in "/\\."):
            return False
        path = folder / f"{room_id}.jpg"
        if not path.is_file() or path.stat().st_size < 200:
            return False
        luma = jpeg_mean_luma(path)
        if luma is None or luma < min_luma:
            return False
    return True