def test_default_rooms_scale_with_area():
    from house_design.usecases import default_rooms_for_area

    rooms = default_rooms_for_area(89)
    assert len(rooms) == 6
    assert rooms[0]["name"] == "客厅"
    bigger = default_rooms_for_area(178)
    assert bigger[0]["area_sqm"] == round(rooms[0]["area_sqm"] * 2, 1)


def test_rooms_match_photo_by_kind():
    from house_design.panorama import build_scene_panorama

    used: set[str] = set()
    cases = [
        ("主卧", "cream · AI 方案", "cream", "主卧"),
        ("卫浴", "现代简约", "blush", "卫浴"),
        ("阳台", "地中海", "sea", "阳台"),
        ("书房/小卧室", "法式轻奢", "french", "书房"),
        ("餐厅", "夜色", "night", "餐厅"),
    ]
    for name, style, expect_style, expect_kind in cases:
        _, meta = build_scene_panorama(name, 12, style, used)
        assert meta["visual"] == "photo", name
        assert meta["style_id"] == expect_style, (name, meta)
        assert meta["room_kind"] == expect_kind, (name, meta)
        assert meta["match"] == "room_kind", (name, meta)
