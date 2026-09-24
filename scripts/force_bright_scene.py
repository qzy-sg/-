from pathlib import Path

from PIL import Image

from house_design.config import get_settings
from house_design.database import Session, get_store, select
from house_design.models import Project, User
from house_design.runtime import run_scene_build
from house_design.usecases import _new_task


def main() -> None:
    get_settings.cache_clear()
    get_store().load()
    db = Session()
    project = db.scalar(select(Project).where(Project.id == "prj_6c877e0c8b084b42"))
    assert project is not None
    user = db.get(User, project.user_id)
    assert user is not None
    task = _new_task(db, user, project, "scene_build", None, {"mode": "vr_panorama", "source": "force_bright"})
    print("task", task.id)
    run_scene_build(task.id)
    db.refresh(task)
    scn = task.result_json["scene_version_id"]
    print("scene", scn)
    folder = Path(".local-assets/scenes") / scn / "panoramas"
    for path in folder.glob("*.jpg"):
        image = Image.open(path)
        pixels = list(image.getdata())
        avg = tuple(sum(channel[i] for channel in pixels) // len(pixels) for i in range(3))
        print(path.name, avg, path.stat().st_size)


if __name__ == "__main__":
    main()
