"""Download extra Poly Haven indoor panoramas (CC0) and shrink to 4k equirect JPG."""

from __future__ import annotations

import json
from pathlib import Path

import httpx
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "webview-vr" / "panoramas"
ASSETS = ROOT / "apps" / "mobile" / "assets" / "styles"

# style_id, display name, room label, room_kinds, slug, author
NEW = [
    ("bath", "现代卫浴", "明亮卫浴", ["卫浴"], "modern_bathroom", "Adrian Kubasa"),
    ("spa", "简约卫浴", "干净卫浴", ["卫浴"], "bathroom", "Andreas Mischok"),
    ("sofa", "暖光起居", "沙发厅", ["客厅", "餐厅"], "lythwood_lounge", "Greg Zaal"),
    ("suite", "海景套房", "明亮卧室", ["主卧", "次卧", "阳台"], "relax_inn_seaview_suite", "Sergej Majboroda"),
    ("hearth", "壁炉暖厅", "夜色起居", ["客厅", "餐厅"], "fireplace", "Andreas Mischok"),
    ("dining", "日光餐厅", "餐厅空间", ["餐厅", "厨房", "客厅"], "warm_restaurant", "Andreas Mischok"),
    ("atelier", "艺术书房", "创作间", ["书房", "客厅"], "art_studio", "Sergej Majboroda"),
    ("air", "留白小间", "通透空房", ["次卧", "儿童", "书房"], "small_empty_room_1", "Andreas Mischok"),
    ("quiet", "静谧小室", "安静房间", ["次卧", "主卧", "书房"], "small_empty_room_3", "Andreas Mischok"),
    ("foyer", "玄关厅", "进门空间", ["客厅", "阳台"], "entrance_hall", "Andreas Mischok"),
    ("walk", "走廊阳台", "通行廊道", ["阳台", "客厅"], "old_apartments_walkway", "Andreas Mischok"),
    ("glass", "玻璃花房", "绿意阳台", ["阳台", "客厅"], "glasshouse_interior", "Andreas Mischok"),
    ("amber", "暮色内厅", "暖色客厅", ["客厅", "餐厅"], "kiara_interior", "Greg Zaal"),
    ("aft", "休闲厅", "轻松起居", ["客厅", "书房"], "aft_lounge", "Andreas Mischok"),
    ("kominka", "和式木作", "木色空间", ["客厅", "书房", "主卧"], "studio_kominka_01", "Jarod Guest"),
]


def fetch_tonemap(slug: str) -> bytes:
    meta = httpx.get(
        f"https://api.polyhaven.com/files/{slug}",
        timeout=60,
        headers={"User-Agent": "zui-house-design"},
    )
    meta.raise_for_status()
    url = meta.json()["tonemapped"]["url"]
    print(f"  download {slug}")
    with httpx.stream("GET", url, timeout=180, headers={"User-Agent": "zui-house-design"}, follow_redirects=True) as resp:
        resp.raise_for_status()
        return b"".join(resp.iter_bytes())


COVER_W, COVER_H = 864, 1152


def save_jpg(raw: bytes, path: Path) -> None:
    from io import BytesIO

    im = Image.open(BytesIO(raw)).convert("RGB")
    # Keep 2:1 equirect; match existing assets (~4k wide).
    w, h = im.size
    target_w = 4096
    target_h = 2048
    if w != target_w or h != target_h:
        im = im.resize((target_w, target_h), Image.Resampling.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, format="JPEG", quality=86, optimize=True)
    print(f"  saved {path.name} {path.stat().st_size}")


def save_cover(pano: Path, cover: Path) -> None:
    """Portrait crop from equirect for Flutter style cards (not for VR)."""
    with Image.open(pano) as im:
        im = im.convert("RGB")
        w, h = im.size
        y0 = int(h * 0.20)
        y1 = int(h * 0.78)
        band_h = y1 - y0
        band_w = max(1, int(band_h * COVER_W / COVER_H))
        x0 = max(0, (w - band_w) // 2)
        crop = im.crop((x0, y0, min(w, x0 + band_w), y1))
        out = crop.resize((COVER_W, COVER_H), Image.Resampling.LANCZOS)
    cover.parent.mkdir(parents=True, exist_ok=True)
    out.save(cover, format="JPEG", quality=88, optimize=True)
    print(f"  cover -> {cover.name} ({COVER_W}x{COVER_H})")


def _cover_is_raw_equirect(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size < 20_000:
        return True
    with Image.open(path) as im:
        w, h = im.size
    return abs(w / h - 2.0) < 0.08 and w >= 2000


def main() -> None:
    catalog_path = OUT / "catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    by_id = {str(item.get("style_id")): item for item in catalog}

    for style_id, name, room, kinds, slug, author in NEW:
        file_name = f"style-{style_id}.jpg"
        dest = OUT / file_name
        if not dest.is_file() or dest.stat().st_size < 50_000:
            raw = fetch_tonemap(slug)
            save_jpg(raw, dest)
        cover = ASSETS / file_name
        if _cover_is_raw_equirect(cover):
            save_cover(dest, cover)

        by_id[style_id] = {
            "style_id": style_id,
            "name": name,
            "room": room,
            "room_kinds": kinds,
            "file": file_name,
            "source": "Poly Haven",
            "source_slug": slug,
            "author": author,
            "license": "CC0",
            "url": f"https://polyhaven.com/a/{slug}",
        }

    # Enrich room_kinds on older entries so kitchen/children get more hits.
    enrich = {
        "night": ["餐厅", "厨房", "客厅"],
        "white": ["客厅", "阳台", "厨房", "次卧"],
        "wood": ["客厅", "书房", "餐厅", "厨房"],
        "modern": ["主卧", "次卧", "儿童", "客厅"],
        "cream": ["主卧", "次卧", "儿童", "客厅"],
        "blush": ["卫浴", "主卧"],
        "sea": ["阳台", "客厅", "主卧"],
    }
    for sid, kinds in enrich.items():
        if sid in by_id:
            by_id[sid]["room_kinds"] = kinds

    ordered = list(by_id.values())
    catalog_path.write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"catalog entries: {len(ordered)}")


if __name__ == "__main__":
    main()
