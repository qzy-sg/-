from house_design.errors import AppError
from house_design.usecases import evaluate_floor_plan_quality


def test_floor_plan_quality_accepts_complete_layout():
    ok, message, summary = evaluate_floor_plan_quality(
        [
            {"name": "客厅", "area_sqm": 22, "confidence": 0.8},
            {"name": "主卧", "area_sqm": 14, "confidence": 0.76},
            {"name": "次卧", "area_sqm": 10, "confidence": 0.7},
            {"name": "厨房", "area_sqm": 6, "confidence": 0.72},
            {"name": "卫生间", "area_sqm": 4, "confidence": 0.7},
        ]
    )
    assert ok is True
    assert message == ""
    assert summary["room_count"] == 5
    assert summary["total_area_sqm"] == 56.0
    assert "5 个空间" in summary["headline"]


def test_floor_plan_quality_rejects_sparse_layout():
    ok, message, _ = evaluate_floor_plan_quality(
        [
            {"name": "厨房", "area_sqm": 6, "confidence": 0.9},
            {"name": "卫生间", "area_sqm": 4, "confidence": 0.9},
        ]
    )
    assert ok is False
    assert message


def test_adopt_analysis_api_flow(client):
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "demo@local.test", "password": "demo-password"},
    )
    assert login.status_code == 200, login.text
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

    created = client.post("/api/v1/projects", headers=headers, json={"name": "识图预览"})
    assert created.status_code == 201, created.text
    project_id = created.json()["id"]

    from house_design.database import session_scope
    from house_design.models import GenerationTask
    from house_design.security import new_id, utcnow

    task_id = new_id("tsk")
    with session_scope() as db:
        from house_design.models import Project

        project = db.get(Project, project_id)
        assert project is not None
        db.add(
            GenerationTask(
                id=task_id,
                project_id=project_id,
                user_id=project.user_id,
                task_type="floor_plan_analysis",
                status="succeeded",
                idempotency_key=new_id("idem"),
                progress=100,
                input_json={},
                result_json={
                    "rooms": [
                        {"name": "客厅", "area_sqm": 22, "confidence": 0.8},
                        {"name": "主卧", "area_sqm": 14, "confidence": 0.76},
                        {"name": "次卧", "area_sqm": 10, "confidence": 0.7},
                        {"name": "厨房", "area_sqm": 6, "confidence": 0.72},
                        {"name": "卫生间", "area_sqm": 4, "confidence": 0.7},
                    ]
                },
                cost_units=0,
                created_at=utcnow(),
                updated_at=utcnow(),
            )
        )

    adopted = client.post(f"/api/v1/projects/{project_id}/analysis-tasks/{task_id}/adopt", headers=headers)
    assert adopted.status_code == 200, adopted.text
    body = adopted.json()
    assert body["adopted"] is True
    assert body["preview"]["room_count"] == 5
    assert len(body["rooms"]) == 5


def test_adopt_analysis_rejects_unclear_api(client):
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "demo@local.test", "password": "demo-password"},
    )
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    created = client.post("/api/v1/projects", headers=headers, json={"name": "模糊户型"})
    project_id = created.json()["id"]

    from house_design.database import session_scope
    from house_design.models import GenerationTask, Project
    from house_design.security import new_id, utcnow

    task_id = new_id("tsk")
    with session_scope() as db:
        project = db.get(Project, project_id)
        db.add(
            GenerationTask(
                id=task_id,
                project_id=project_id,
                user_id=project.user_id,
                task_type="floor_plan_analysis",
                status="succeeded",
                idempotency_key=new_id("idem"),
                progress=100,
                input_json={},
                result_json={"rooms": [{"name": "阳台", "area_sqm": 3, "confidence": 0.9}]},
                cost_units=0,
                created_at=utcnow(),
                updated_at=utcnow(),
            )
        )

    response = client.post(f"/api/v1/projects/{project_id}/analysis-tasks/{task_id}/adopt", headers=headers)
    assert response.status_code == 422, response.text
    assert response.json()["code"] == "FLOOR_PLAN_UNCLEAR"
