def test_latest_scene_roundtrip(client):
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "demo@local.test", "password": "demo-password"},
    )
    assert login.status_code == 200, login.text
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    created = client.post("/api/v1/projects", headers=headers, json={"name": "全景测试房", "city": "杭州"})
    assert created.status_code == 201, created.text
    project_id = created.json()["id"]

    from house_design.database import session_scope
    from house_design.models import Room
    from house_design.security import new_id, utcnow

    with session_scope() as db:
        for name, area in (("客厅", 28.0), ("主卧", 16.0)):
            db.add(
                Room(
                    id=new_id("rm"),
                    project_id=project_id,
                    name=name,
                    area_sqm=area,
                    confirmation_status="confirmed",
                    created_at=utcnow(),
                )
            )
        db.commit()

    missing = client.get(f"/api/v1/projects/{project_id}/scene-versions/latest", headers=headers)
    assert missing.status_code == 404

    task = client.post(
        f"/api/v1/projects/{project_id}/scene-tasks",
        headers=headers,
        json={"confirmed": True},
    )
    assert task.status_code == 201, task.text
    scene_id = task.json()["result"]["scene_version_id"]

    latest = client.get(f"/api/v1/projects/{project_id}/scene-versions/latest", headers=headers)
    assert latest.status_code == 200, latest.text
    body = latest.json()
    assert body["scene_version_id"] == scene_id
    assert len(body["panoramas"]) >= 1
    assert "exp=" in body["panoramas"][0]["url"]
