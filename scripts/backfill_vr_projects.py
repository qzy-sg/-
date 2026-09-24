"""一次性补全：缺资料/房间的项目补上，并生成 VR 全景。"""

from __future__ import annotations

from house_design.config import get_settings
from house_design.database import Session, delete, get_store, select
from house_design.models import Project, PropertyProfile, Room, SceneVersion, User
from house_design.runtime import run_scene_build
from house_design.security import new_id, utcnow
from house_design.usecases import _new_task

DEFAULT_ROOMS = [
    ("客厅", 28.0),
    ("主卧", 16.0),
    ("厨房", 8.0),
    ("卫生间", 5.0),
]


def main() -> None:
    get_settings.cache_clear()
    store = get_store()
    store.load()
    db = Session()

    projects = list(db.scalars(select(Project)))
    print("projects", len(projects))

    for project in projects:
        rooms = list(db.scalars(select(Room).where(Room.project_id == project.id)))
        confirmed = [r for r in rooms if r.confirmation_status == "confirmed"]
        profile = db.get(PropertyProfile, project.id)

        if profile is None:
            db.add(
                PropertyProfile(
                    project_id=project.id,
                    house_type="三室两厅",
                    area_sqm=98.0,
                    orientation="南北",
                    city=project.city or "杭州",
                    budget=300000,
                    household_notes="本地补全, 可直接生成 VR 全景",
                    updated_at=utcnow(),
                )
            )
            print("+profile", project.id, project.name)
        else:
            if not profile.house_type:
                profile.house_type = "三室两厅"
            if not profile.area_sqm:
                profile.area_sqm = 98.0
            if not profile.city:
                profile.city = project.city or "杭州"
            profile.updated_at = utcnow()

        if not confirmed:
            db.execute(delete(Room).where(Room.project_id == project.id))
            for name, area in DEFAULT_ROOMS:
                db.add(
                    Room(
                        id=new_id("rom"),
                        project_id=project.id,
                        name=name,
                        area_sqm=area,
                        source="backfill",
                        confirmation_status="confirmed",
                        confidence=0.95,
                        created_at=utcnow(),
                    )
                )
            print("+rooms", project.id, project.name, len(DEFAULT_ROOMS))
        else:
            print("rooms-ok", project.id, project.name, len(confirmed))

    db.commit()

    scenes = list(db.scalars(select(SceneVersion)))
    for project in projects:
        has_vr = False
        for scene in scenes:
            if scene.project_id != project.id:
                continue
            manifest = scene.manifest if isinstance(scene.manifest, dict) else {}
            if manifest.get("mode") == "vr_panorama" and (manifest.get("panoramas") or []):
                has_vr = True
                break
        if has_vr:
            print("vr-ok", project.id, project.name)
            continue

        user = db.get(User, project.user_id)
        if user is None:
            print("skip-no-user", project.id)
            continue

        task = _new_task(
            db,
            user,
            project,
            "scene_build",
            None,
            {
                "design_version_id": None,
                "source": "procedural_panorama",
                "mode": "vr_panorama",
                "backfill": True,
            },
        )
        print("task", task.id, project.name)
        run_scene_build(task.id)
        db.refresh(task)
        print(" ", task.status, (task.result_json or {}).get("scene_version_id"))

    scenes = list(db.scalars(select(SceneVersion)))
    for project in projects:
        rooms = list(db.scalars(select(Room).where(Room.project_id == project.id)))
        conf = sum(1 for room in rooms if room.confirmation_status == "confirmed")
        vr = 0
        for scene in scenes:
            if scene.project_id != project.id:
                continue
            manifest = scene.manifest if isinstance(scene.manifest, dict) else {}
            if manifest.get("mode") == "vr_panorama" and (manifest.get("panoramas") or []):
                vr += 1
        print("DONE", project.name, "confirmed", conf, "vr", vr)


if __name__ == "__main__":
    main()
