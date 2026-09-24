from io import BytesIO

from PIL import Image


def test_still_from_equirect_is_normal_photo():
    from house_design.panorama import build_panorama_jpeg, still_from_equirect

    pano = build_panorama_jpeg("客厅", 22.0, style="奶油")
    still = still_from_equirect(pano, width=640, height=360)
    assert still[:3] == b"\xff\xd8\xff"
    image = Image.open(BytesIO(still))
    assert image.size == (640, 360)
    assert abs(image.size[0] / image.size[1] - 16 / 9) < 0.05


def test_build_room_still_uses_photo_when_available():
    from house_design.panorama import build_room_still, present_render, verify_render_url

    used: set[str] = set()
    jpeg, meta = build_room_still("客厅", 22.0, "cream · 我的房子", used)
    assert jpeg[:3] == b"\xff\xd8\xff"
    assert meta["visual"] == "photo"
    assert "style_id" in meta
    image = Image.open(BytesIO(jpeg))
    assert image.size[0] > image.size[1]
    assert image.size[0] / image.size[1] != 2

    presented = present_render(
        "tsk_demo",
        {
            "shots": [{"room_id": "rom_1", "name": "客厅"}],
            "note": "demo",
        },
    )
    url = presented["shots"][0]["url"]
    assert "/api/v1/renders/tsk_demo/shots/rom_1.jpg" in url
    expires = presented["shots"][0]["expires_at"]
    sig = url.split("sig=", 1)[1]
    assert verify_render_url("tsk_demo", "rom_1", expires, sig)
    assert not verify_render_url("tsk_demo", "rom_2", expires, sig)
