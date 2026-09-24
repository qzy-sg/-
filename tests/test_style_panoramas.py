from pathlib import Path

from PIL import Image

from house_design.panorama import jpeg_mean_luma


ROOT = Path(__file__).resolve().parents[1]
PANO_DIR = ROOT / "webview-vr" / "panoramas"
EXPECTED = {
    "modern",
    "wood",
    "cream",
    "green",
    "white",
    "night",
    "french",
    "loft",
    "luxe",
    "sea",
    "wabi",
    "blush",
}


def test_style_tours_are_bright_equirectangular():
    missing = []
    for style_id in EXPECTED:
        path = PANO_DIR / f"style-{style_id}.jpg"
        if not path.is_file() or path.stat().st_size < 20_000:
            missing.append(style_id)
            continue
        with Image.open(path) as image:
            width, height = image.size
        assert width == height * 2, f"{style_id} should be 2:1, got {width}x{height}"
        luma = jpeg_mean_luma(path)
        assert luma is not None and luma >= 48, f"{style_id} too dark: {luma}"
    assert not missing, f"missing panoramas: {missing}"
