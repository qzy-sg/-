"""Make portrait style covers from equirect panoramas (for UI cards, not VR)."""

from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PANO = ROOT / "webview-vr" / "panoramas"
ASSETS = ROOT / "apps" / "mobile" / "assets" / "styles"

# Match existing good covers (modern / wood).
COVER_W, COVER_H = 864, 1152


def is_equirect(path: Path) -> bool:
    with Image.open(path) as im:
        w, h = im.size
    return abs(w / h - 2.0) < 0.08 and w >= 2000


def make_cover(src: Path, dest: Path) -> None:
    with Image.open(src) as im:
        im = im.convert("RGB")
        w, h = im.size
        # Avoid zenith/nadir; keep middle band where rooms read clearly.
        y0 = int(h * 0.20)
        y1 = int(h * 0.78)
        band_h = y1 - y0
        band_w = max(1, int(band_h * COVER_W / COVER_H))
        x0 = max(0, (w - band_w) // 2)
        x1 = min(w, x0 + band_w)
        crop = im.crop((x0, y0, x1, y1))
        cover = crop.resize((COVER_W, COVER_H), Image.Resampling.LANCZOS)
    dest.parent.mkdir(parents=True, exist_ok=True)
    cover.save(dest, format="JPEG", quality=88, optimize=True)
    print(f"  cover {dest.name} <- {src.name} ({cover.size[0]}x{cover.size[1]}, {dest.stat().st_size} bytes)")


def main() -> None:
    fixed = 0
    for pano in sorted(PANO.glob("style-*.jpg")):
        dest = ASSETS / pano.name
        need = (not dest.is_file()) or is_equirect(dest) or dest.stat().st_size < 20_000
        if not need:
            continue
        make_cover(pano, dest)
        fixed += 1
    print(f"updated covers: {fixed}")


if __name__ == "__main__":
    main()
