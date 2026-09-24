"""事件、归属、存储、预算、队列与 Worker 任务。"""

import json
import logging
from pathlib import Path

from house_design.config import get_settings
from house_design.database import Session, func, select, session_scope
from house_design.errors import AppError
from house_design.models import (
    Asset,
    DomainEvent,
    GenerationTask,
    OutboxMessage,
    Project,
    SceneVersion,
    User,
)
from house_design.security import iso, new_id, utcnow

logger = logging.getLogger(__name__)

IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def write_audit(db: Session, user_id: str | None, action: str, target_type: str, target_id: str) -> None:
    from house_design.models import AuditLog

    db.add(
        AuditLog(
            id=new_id("aud"),
            user_id=user_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            created_at=utcnow(),
        )
    )


def get_owned_project(db: Session, user: User, project_id: str) -> Project:
    project = db.get(Project, project_id)
    if project is None or project.user_id != user.id or project.status == "deleted":
        raise AppError(404, "NOT_FOUND", "项目不存在")
    return project


def get_owned_asset(db: Session, user: User, project_id: str, asset_id: str) -> Asset:
    project = get_owned_project(db, user, project_id)
    asset = db.get(Asset, asset_id)
    if asset is None or asset.project_id != project.id or asset.user_id != user.id or asset.status == "deleted":
        raise AppError(404, "NOT_FOUND", "文件不存在")
    return asset


def append_event(
    db: Session,
    stream_id: str,
    event_type: str,
    data: dict,
    task_id: str | None = None,
) -> DomainEvent:
    current = db.scalar(select(func.max(DomainEvent.sequence)).where(DomainEvent.stream_id == stream_id))
    event = DomainEvent(
        id=new_id("evt"),
        stream_id=stream_id,
        task_id=task_id,
        sequence=(current or 0) + 1,
        event_type=event_type,
        payload=data,
        created_at=utcnow(),
    )
    db.add(event)
    db.flush()
    return event


def event_envelope(event: DomainEvent) -> dict:
    return {
        "id": event.id,
        "type": event.event_type,
        "task_id": event.task_id,
        "sequence": event.sequence,
        "created_at": iso(event.created_at),
        "data": event.payload or {},
    }


def list_events(db: Session, stream_id: str, after_sequence: int = 0) -> list[dict]:
    rows = db.scalars(
        select(DomainEvent)
        .where(DomainEvent.stream_id == stream_id, DomainEvent.sequence > after_sequence)
        .order_by(DomainEvent.sequence.asc())
    )
    return [event_envelope(row) for row in rows]


def assert_budget(db: Session, user_id: str, project_id: str, units: int) -> None:
    settings = get_settings()
    if units > settings.budget_task:
        raise AppError(409, "BUDGET_EXCEEDED", "超过单任务额度")
    project_sum = db.scalar(
        select(func.coalesce(func.sum(GenerationTask.cost_units), 0)).where(GenerationTask.project_id == project_id)
    )
    if int(project_sum or 0) + units > settings.budget_project:
        raise AppError(409, "BUDGET_EXCEEDED", "超过项目额度")
    start = utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    daily = db.scalar(
        select(func.coalesce(func.sum(GenerationTask.cost_units), 0)).where(
            GenerationTask.user_id == user_id,
            GenerationTask.created_at >= start,
        )
    )
    if int(daily or 0) + units > settings.budget_user_daily:
        raise AppError(409, "BUDGET_EXCEEDED", "超过今日额度")


def _object_key(project_id: str, asset_id: str, filename: str) -> str:
    safe = filename.replace("\\", "/").split("/")[-1] or "file"
    return f"projects/{project_id}/{asset_id}/{safe}"


def presign_put(object_key: str, content_type: str) -> str:
    settings = get_settings()
    if settings.use_mock_storage:
        return f"http://mock-storage.local/{settings.s3_bucket}/{object_key}"
    import boto3

    client = boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        region_name=settings.s3_region,
    )
    return client.generate_presigned_url(
        "put_object",
        Params={"Bucket": settings.s3_bucket, "Key": object_key, "ContentType": content_type},
        ExpiresIn=settings.signed_url_seconds,
    )


def presign_get(object_key: str) -> str:
    settings = get_settings()
    if settings.use_mock_storage:
        return f"http://mock-storage.local/{settings.s3_bucket}/{object_key}?expires={settings.signed_url_seconds}"
    import boto3

    client = boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        region_name=settings.s3_region,
    )
    return client.generate_presigned_url(
        "get_object",
        Params={"Bucket": settings.s3_bucket, "Key": object_key},
        ExpiresIn=settings.signed_url_seconds,
    )


def prepare_upload(project_id: str, filename: str, content_type: str, kind: str) -> tuple[str, str, str]:
    settings = get_settings()
    if kind != "image" or content_type not in IMAGE_TYPES:
        raise AppError(400, "VALIDATION_ERROR", "仅支持上传图片")
    asset_id = new_id("ast")
    key = _object_key(project_id, asset_id, filename)
    url = presign_put(key, content_type)
    _ = settings
    return asset_id, key, url


def _mark_failed(task_id: str, message: str) -> None:
    with session_scope() as db:
        task = db.get(GenerationTask, task_id)
        if task is None:
            return
        task.status = "failed"
        task.error_message = message[:500]
        task.updated_at = utcnow()
        append_event(db, task.id, "task.failed", {"message": task.error_message}, task_id=task.id)


def run_analyze(task_id: str) -> None:
    from house_design.ai import get_provider
    from house_design.models import Room

    try:
        with session_scope() as db:
            task = db.get(GenerationTask, task_id)
            if task is None or task.status == "canceled":
                return
            task.status = "running"
            task.progress = 20
            task.updated_at = utcnow()
            append_event(db, task.id, "phase.started", {"phase": "analyze"}, task_id=task.id)
            asset_id = (task.input_json or {}).get("asset_id")
            result = get_provider().analyze_floor_plan(asset_id)
            for item in result["rooms"]:
                db.add(
                    Room(
                        id=new_id("rom"),
                        project_id=task.project_id,
                        name=item["name"],
                        area_sqm=item.get("area_sqm"),
                        source="ai",
                        confirmation_status="candidate",
                        confidence=item.get("confidence"),
                        created_at=utcnow(),
                    )
                )
            task.status = "succeeded"
            task.progress = 100
            task.result_json = result
            task.updated_at = utcnow()
            append_event(db, task.id, "task.completed", {"disclaimer": result.get("disclaimer")}, task_id=task.id)
    except Exception:
        logger.exception("analyze failed")
        _mark_failed(task_id, "户型分析失败，可重试")


def run_render(task_id: str) -> None:
    try:
        from house_design.media import store_local_asset
        from house_design.models import Room
        from house_design.panorama import build_room_still, panoramas_from_rooms

        with session_scope() as db:
            task = db.get(GenerationTask, task_id)
            if task is None or task.status == "canceled":
                return
            task.status = "running"
            task.updated_at = utcnow()
            append_event(db, task.id, "task.progress", {"progress": 40}, task_id=task.id)
            rooms = list(
                db.scalars(
                    select(Room).where(Room.project_id == task.project_id, Room.confirmation_status == "confirmed")
                )
            )
            specs = panoramas_from_rooms(rooms)
            design_style = _design_style(db, task)
            used_styles: set[str] = set()
            shots = []
            photo_count = 0
            for spec in specs:
                jpeg, visual = build_room_still(spec["name"], spec.get("area_sqm"), design_style, used_styles)
                if visual.get("visual") == "photo":
                    photo_count += 1
                relative = f"renders/{task_id}/shots/{spec['room_id']}.jpg"
                store_local_asset(relative, jpeg)
                shots.append(
                    {
                        "room_id": spec["room_id"],
                        "name": spec["name"],
                        "area_sqm": spec.get("area_sqm"),
                        "byte_length": len(jpeg),
                        **visual,
                    }
                )
            result = {
                "kind": "render",
                "is_panorama": False,
                "shots": shots,
                "source": "panorama_still",
                "note": "按房间从环视画面取出的正面效果图，仅供看气氛，不是施工图，也不保证真实尺寸。",
                "model": "panorama-still",
                "photo_count": photo_count,
            }
            task.status = "succeeded"
            task.progress = 100
            task.result_json = result
            task.cost_units = get_settings().render_cost_units
            task.updated_at = utcnow()
            append_event(
                db,
                task.id,
                "task.completed",
                {"kind": "render", "shots": len(shots)},
                task_id=task.id,
            )
    except Exception:
        logger.exception("render failed")
        _mark_failed(task_id, "效果图生成失败，可重试")


def _design_style(db, task) -> str | None:
    from house_design.models import DesignVersion

    version_id = (task.input_json or {}).get("design_version_id")
    if not version_id:
        return None
    version = db.get(DesignVersion, version_id)
    if version is None:
        return None
    bits = [version.title or "", version.summary or ""]
    payload = version.payload if isinstance(version.payload, dict) else {}
    style_id = payload.get("style_id")
    if style_id:
        bits.append(str(style_id))
    for item in payload.get("options") or []:
        if isinstance(item, dict):
            bits.append(str(item.get("name") or ""))
            bits.append(str(item.get("title") or ""))
            bits.append(str(item.get("summary") or ""))
    text = " ".join(bits).strip()
    return text or None


def run_scene_build(task_id: str) -> None:
    try:
        import hashlib

        from house_design.media import store_local_asset
        from house_design.models import Room
        from house_design.panorama import build_scene_panorama, panoramas_from_rooms

        with session_scope() as db:
            task = db.get(GenerationTask, task_id)
            if task is None or task.status == "canceled":
                return
            task.status = "running"
            rooms = list(
                db.scalars(
                    select(Room).where(Room.project_id == task.project_id, Room.confirmation_status == "confirmed")
                )
            )
            specs = panoramas_from_rooms(rooms)
            scene_id = new_id("scn")
            panoramas = []
            total_bytes = 0
            design_style = _design_style(db, task)
            used_styles: set[str] = set()
            photo_count = 0
            for spec in specs:
                jpeg, visual = build_scene_panorama(spec["name"], spec.get("area_sqm"), design_style, used_styles)
                if visual.get("visual") == "photo":
                    photo_count += 1
                digest = hashlib.sha256(jpeg).hexdigest()
                relative = f"scenes/{scene_id}/panoramas/{spec['room_id']}.jpg"
                store_local_asset(relative, jpeg)
                total_bytes += len(jpeg)
                panoramas.append(
                    {
                        **spec,
                        **visual,
                        "url": f"/api/v1/scenes/{scene_id}/panoramas/{spec['room_id']}.jpg",
                        "sha256": digest,
                        "byte_length": len(jpeg),
                        "projection": "equirectangular",
                    }
                )
            default_room = panoramas[0]["room_id"]
            photo_scene = photo_count > 0
            manifest = {
                "scene_version_id": scene_id,
                "mode": "vr_panorama",
                "readonly": True,
                "viewer_url": "/viewer/",
                "rooms": [item["room_id"] for item in panoramas],
                "default_room": default_room,
                "panoramas": panoramas,
                "camera_presets": [item["room_id"] for item in panoramas],
                "floor_plan": {
                    "based_on": "confirmed_rooms",
                    "rooms": [
                        {
                            "room_id": item["room_id"],
                            "name": item["name"],
                            "area_sqm": item.get("area_sqm"),
                            "room_kind": item.get("room_kind"),
                            "scene_label": item.get("scene_label"),
                            "match": item.get("match"),
                        }
                        for item in panoramas
                    ],
                },
                "license_note": (
                    "按房间类型匹配的实景环视（客厅/卧室/厨房等），只供方案演示。不是你家实测扫描，也不是 BIM。"
                    if photo_scene
                    else "VR 全景示意，只供环视灵感。不是实测扫描，也不是 BIM / 施工模型。"
                ),
                "byte_length": total_bytes,
                "source": "floorplan_photo" if photo_scene else "procedural_panorama",
            }
            db.add(
                SceneVersion(
                    id=scene_id,
                    project_id=task.project_id,
                    design_version_id=(task.input_json or {}).get("design_version_id"),
                    status="draft",
                    manifest=manifest,
                    created_at=utcnow(),
                )
            )
            task.status = "succeeded"
            task.progress = 100
            task.result_json = {
                "scene_version_id": scene_id,
                "readonly": True,
                "mode": "vr_panorama",
                "viewer_url": "/viewer/",
                "rooms": [item["room_id"] for item in panoramas],
                "byte_length": total_bytes,
            }
            task.updated_at = utcnow()
            append_event(
                db,
                task.id,
                "task.completed",
                {"scene_version_id": scene_id, "mode": "vr_panorama", "rooms": len(panoramas)},
                task_id=task.id,
            )
    except Exception:
        logger.exception("scene build failed")
        _mark_failed(task_id, "全景生成失败，可降级到效果图")


def run_cleanup(task_id: str) -> None:
    try:
        with session_scope() as db:
            task = db.get(GenerationTask, task_id)
            if task is None:
                return
            assets = db.scalars(select(Asset).where(Asset.project_id == task.project_id))
            for asset in assets:
                asset.status = "deleted"
            task.status = "succeeded"
            task.progress = 100
            task.updated_at = utcnow()
            append_event(db, task.id, "task.completed", {"cleanup": True}, task_id=task.id)
    except Exception:
        logger.exception("cleanup failed")
        _mark_failed(task_id, "文件清理失败")


SYNC_JOBS = {
    "analyze_floor_plan": run_analyze,
    "create_render": run_render,
    "scene_build": run_scene_build,
    "asset_cleanup": run_cleanup,
}


def record_outbox(topic: str, payload: dict, published: bool) -> None:
    with session_scope() as db:
        db.add(
            OutboxMessage(
                id=new_id("obx"),
                topic=topic,
                payload=payload,
                created_at=utcnow(),
                published_at=utcnow() if published else None,
            )
        )


def dispatch(job_name: str, *args: str) -> None:
    """同步入口。内联执行时不跨线程使用调用方的 Session。"""
    import asyncio

    settings = get_settings()
    record_outbox(job_name, {"args": list(args)}, published=settings.task_inline)
    if settings.task_inline:
        SYNC_JOBS[job_name](*args)
        return

    async def _enqueue() -> None:
        from arq import create_pool
        from arq.connections import RedisSettings

        redis = await create_pool(RedisSettings.from_dsn(settings.redis_url))
        try:
            await redis.enqueue_job(job_name, *args)
        finally:
            await redis.close()

    asyncio.run(_enqueue())


def ensure_bucket() -> None:
    settings = get_settings()
    if settings.use_mock_storage:
        return
    try:
        import boto3

        client = boto3.client(
            "s3",
            endpoint_url=settings.s3_endpoint,
            aws_access_key_id=settings.s3_access_key,
            aws_secret_access_key=settings.s3_secret_key,
            region_name=settings.s3_region,
        )
        names = [item["Name"] for item in client.list_buckets().get("Buckets", [])]
        if settings.s3_bucket not in names:
            client.create_bucket(Bucket=settings.s3_bucket)
    except Exception:
        logger.warning("对象存储桶未就绪，上传前请确认 MinIO")


def seed_demo() -> None:
    from house_design.security import hash_password

    settings = get_settings()
    if not settings.seed_demo:
        return
    email = settings.demo_email.strip().lower()
    with session_scope() as db:
        existing = db.scalar(select(User).where(User.email == email))
        if existing is not None:
            return
        db.add(
            User(
                id=new_id("usr"),
                email=email,
                password_hash=hash_password(settings.demo_password),
                created_at=utcnow(),
            )
        )
