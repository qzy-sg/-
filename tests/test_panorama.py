def test_panorama_jpeg_is_valid():
    from io import BytesIO
    import time

    from PIL import Image

    from house_design.panorama import (
        MAX_PANORAMA_ROOMS,
        build_panorama_jpeg,
        panoramas_from_rooms,
        sign_panorama_url,
        verify_panorama_url,
    )

    rooms = panoramas_from_rooms(
        [
            {"name": "客厅", "area_sqm": 18},
            {"name": "主卧", "area_sqm": 12},
            {"name": "厨房", "area_sqm": 8},
            {"name": "卫生间", "area_sqm": 4},
            {"name": "书房", "area_sqm": 9},
            {"name": "阳台", "area_sqm": 5},
            {"name": "次卧", "area_sqm": 10},
        ]
    )
    assert len(rooms) == MAX_PANORAMA_ROOMS
    for room in rooms[:3]:
        data = build_panorama_jpeg(room["name"], room.get("area_sqm"), style="奶油暖调")
        assert data[:3] == b"\xff\xd8\xff"
        assert len(data) > 1000
        image = Image.open(BytesIO(data))
        assert image.size[0] / image.size[1] == 2
        sample = image.convert("RGB").resize((64, 32))
        pixels = list(sample.getdata())
        luma = sum(0.2126 * r + 0.7152 * g + 0.0722 * b for r, g, b in pixels) / len(pixels)
        assert luma >= 48, (room["name"], luma)
    url, expires = sign_panorama_url("scn_demo", "rom_demo")
    assert "sig=" in url
    assert expires - time.time() > 3500
    sig = url.split("sig=", 1)[1]
    assert verify_panorama_url("scn_demo", "rom_demo", expires, sig)
    assert not verify_panorama_url("scn_demo", "rom_other", expires, sig)


def test_floorplan_scene_uses_distinct_real_photos():
    from house_design.panorama import build_scene_panorama

    used: set[str] = set()
    kinds = []
    styles = []
    for name, area in (("客厅", 22.0), ("主卧", 14.0), ("厨房", 6.0)):
        data, meta = build_scene_panorama(name, area, "奶油暖调 · 快速方案", used)
        assert data[:3] == b"\xff\xd8\xff"
        assert meta["visual"] == "photo"
        kinds.append(meta["visual"])
        styles.append(meta["style_id"])
    assert len(set(styles)) == 3


def test_scene_files_usable_rejects_dark(tmp_path, monkeypatch):
    from PIL import Image

    from house_design import panorama as panorama_mod
    import house_design.runtime as runtime

    scene_id = "scn_darktest"
    room_id = "rom_1"
    folder = tmp_path / ".local-assets" / "scenes" / scene_id / "panoramas"
    folder.mkdir(parents=True)
    Image.new("RGB", (64, 32), (8, 8, 8)).save(folder / f"{room_id}.jpg", format="JPEG", quality=80)

    monkeypatch.setattr(runtime, "repo_root", lambda: tmp_path)
    assert panorama_mod.jpeg_mean_luma(folder / f"{room_id}.jpg") < 48
    assert not panorama_mod.scene_files_usable(scene_id, [{"room_id": room_id}])

    Image.new("RGB", (64, 32), (200, 190, 170)).save(folder / f"{room_id}.jpg", format="JPEG", quality=80)
    assert panorama_mod.scene_files_usable(scene_id, [{"room_id": room_id}])
