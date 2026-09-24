"""业务用例。路由只做鉴权、参数和响应映射。"""

import json

from house_design.database import Session, delete, select

from house_design.agent import build_model_messages, invoke_tool, layout_options, next_state
from house_design.ai import get_provider
from house_design.config import get_settings
from house_design.errors import AppError
from house_design.models import (
    AgentRun,
    Approval,
    Asset,
    Constraint,
    Conversation,
    DesignArtifact,
    DesignVersion,
    GenerationTask,
    Message,
    Project,
    PropertyProfile,
    Room,
    SceneVersion,
    User,
)
from house_design.runtime import (
    append_event,
    assert_budget,
    get_owned_asset,
    get_owned_project,
    list_events,
    prepare_upload,
    presign_get,
    write_audit,
)
from house_design.security import DISCLAIMER, create_access_token, hash_password, iso, new_id, utcnow, verify_password
from house_design.sms_auth import consume_code
from house_design.wechat_auth import consume_state, normalize_subject


def user_out(user: User) -> dict:
    email = user.email or ""
    phone = None
    if email.endswith("@phone.local"):
        digits = email.split("@", 1)[0]
        if len(digits) == 11:
            phone = f"{digits[:3]}****{digits[-4:]}"
    return {
        "id": user.id,
        "display_name": user.display_name or "",
        "city": user.city or "",
        "bio": user.bio or "",
        "avatar_id": user.avatar_id or "orb",
        "provider": user.auth_provider or "password",
        "phone_masked": phone,
        "created_at": iso(user.created_at),
    }


def get_account(user: User) -> dict:
    return user_out(user)


def update_account(db: Session, user: User, data: dict) -> dict:
    if "display_name" in data and data["display_name"] is not None:
        name = str(data["display_name"]).strip()
        if not name or len(name) > 20:
            raise AppError(422, "VALIDATION_ERROR", "称呼请控制在 1 到 20 个字")
        user.display_name = name
    if "city" in data and data["city"] is not None:
        city = str(data["city"]).strip()
        if len(city) > 20:
            raise AppError(422, "VALIDATION_ERROR", "城市太长了")
        user.city = city
    if "bio" in data and data["bio"] is not None:
        bio = str(data["bio"]).strip()
        if len(bio) > 80:
            raise AppError(422, "VALIDATION_ERROR", "简介请控制在 80 字以内")
        user.bio = bio
    if "avatar_id" in data and data["avatar_id"] is not None:
        avatar = str(data["avatar_id"]).strip()
        allowed = {"orb", "brass", "mint", "ink", "glow", "plant", "custom"}
        if avatar not in allowed:
            raise AppError(422, "VALIDATION_ERROR", "头像样式不可用")
        user.avatar_id = avatar
    write_audit(db, user.id, "account.update", "user", user.id)
    db.commit()
    return user_out(user)


def _issue_token(db: Session, user: User) -> dict:
    write_audit(db, user.id, "auth.login", "user", user.id)
    token, expires = create_access_token(user.id)
    return {"access_token": token, "token_type": "bearer", "expires_in": expires}


def _phone_email(phone: str) -> str:
    digits = "".join(ch for ch in phone if ch.isdigit())
    if len(digits) != 11 or not digits.startswith("1"):
        raise AppError(422, "VALIDATION_ERROR", "请输入 11 位手机号")
    return f"{digits}@phone.local"


def _ensure_user(db: Session, email: str) -> User:
    user = db.scalar(select(User).where(User.email == email))
    if user is not None:
        return user
    user = User(id=new_id("usr"), email=email, password_hash=hash_password(new_id("pw")), created_at=utcnow())
    db.add(user)
    db.flush()
    return user


def login(db: Session, email: str, password: str) -> dict:
    normalized = email.strip().lower()
    user = db.scalar(select(User).where(User.email == normalized))
    if user is None or not verify_password(password, user.password_hash):
        raise AppError(401, "UNAUTHORIZED", "邮箱或密码错误")
    return _issue_token(db, user)


def register_account(db: Session, phone: str, code: str, password: str) -> dict:
    if len(password) < 6:
        raise AppError(422, "VALIDATION_ERROR", "密码至少 6 位")
    email = _phone_email(phone)
    if db.scalar(select(User).where(User.email == email)) is not None:
        raise AppError(409, "CONFLICT", "这个手机号已经注册")
    consume_code(phone, code)
    user = User(
        id=new_id("usr"),
        email=email,
        password_hash=hash_password(password),
        auth_provider="phone",
        created_at=utcnow(),
    )
    db.add(user)
    db.flush()
    return _issue_token(db, user)


def login_phone(db: Session, phone: str, code: str) -> dict:
    email = _phone_email(phone)
    user = db.scalar(select(User).where(User.email == email))
    if user is None:
        raise AppError(404, "NOT_FOUND", "还没有注册，请先注册")
    consume_code(phone, code)
    return _issue_token(db, user)


def login_wechat(db: Session, state: str, subject: str) -> dict:
    consume_state(state)
    identity = normalize_subject(subject)
    user = _ensure_user(db, f"{identity}@wechat.local")
    if not user.display_name:
        user.display_name = f"微信用户{identity[-4:].upper()}"
    user.auth_provider = "wechat"
    user.openid = identity
    payload = _issue_token(db, user)
    payload["user"] = {"id": user.id, "display_name": user.display_name, "provider": "wechat"}
    return payload


def ai_consult(db: Session, user: User, content: str) -> dict:
    text = content.strip()
    if not text:
        raise AppError(400, "VALIDATION_ERROR", "消息不能为空")
    provider = get_provider()
    chat = provider.chat(build_model_messages(text))
    write_audit(db, user.id, "ai.consult", "user", user.id)
    reply = str(chat.get("text") or "").strip() or "已收到。"
    return {
        "reply": reply,
        "model": chat.get("model"),
        "provider": provider.name,
        "disclaimer": DISCLAIMER,
        "input_tokens": int(chat.get("input_tokens") or 0),
        "output_tokens": int(chat.get("output_tokens") or 0),
    }


def ai_consult_stream(db: Session, user: User, content: str):
    """SSE：assistant.delta 增量 + task.completed 终态。"""
    text = content.strip()
    if not text:
        raise AppError(400, "VALIDATION_ERROR", "消息不能为空")
    provider = get_provider()
    write_audit(db, user.id, "ai.consult.stream", "user", user.id)
    sequence = 0
    created = utcnow().isoformat().replace("+00:00", "Z")

    def emit(event_type: str, data: dict) -> str:
        nonlocal sequence
        sequence += 1
        envelope = {
            "id": f"evt_{sequence}",
            "type": event_type,
            "sequence": sequence,
            "created_at": created,
            "data": data,
        }
        return f"id: {sequence}\nevent: {event_type}\ndata: {json.dumps(envelope, ensure_ascii=False)}\n\n"

    yield emit("phase.started", {"phase": "consult", "provider": provider.name})
    collected: list[str] = []
    try:
        for piece in provider.chat_stream(build_model_messages(text)):
            if not piece:
                continue
            collected.append(piece)
            yield emit("assistant.delta", {"text": piece, "done": False})
        reply = "".join(collected).strip() or "已收到。这是设计灵感，不构成结构、施工结论。"
        yield emit(
            "task.completed",
            {
                "reply": reply,
                "model": getattr(provider, "_model", provider.name),
                "provider": provider.name,
                "disclaimer": DISCLAIMER,
                "streamed": True,
            },
        )
    except AppError as exc:
        yield emit("task.failed", {"message": exc.message, "code": exc.code})
    except Exception:
        yield emit("task.failed", {"message": "流式回复失败，请重试", "code": "AI_STREAM_FAILED"})


def project_out(project: Project) -> dict:
    return {
        "id": project.id,
        "name": project.name,
        "city": project.city,
        "status": project.status,
        "current_design_version_id": project.current_design_version_id,
        "created_at": iso(project.created_at),
        "updated_at": iso(project.updated_at),
    }


def list_projects(db: Session, user: User) -> dict:
    rows = db.scalars(
        select(Project)
        .where(Project.user_id == user.id, Project.status != "deleted")
        .order_by(Project.created_at.desc())
    )
    return {"items": [project_out(row) for row in rows], "next_cursor": None}


def create_project(db: Session, user: User, name: str, city: str | None) -> dict:
    now = utcnow()
    project = Project(
        id=new_id("prj"),
        user_id=user.id,
        name=name.strip(),
        city=city,
        status="active",
        created_at=now,
        updated_at=now,
    )
    db.add(project)
    db.commit()
    return project_out(project)


def update_project(db: Session, user: User, project_id: str, name: str | None, city: str | None, status: str | None) -> dict:
    project = get_owned_project(db, user, project_id)
    if name:
        project.name = name.strip()
    if city is not None:
        project.city = city
    if status is not None:
        if status not in {"active", "archived"}:
            raise AppError(400, "VALIDATION_ERROR", "状态只能是 active 或 archived")
        project.status = status
    project.updated_at = utcnow()
    db.commit()
    return project_out(project)


def delete_project(db: Session, user: User, project_id: str) -> str:
    project = get_owned_project(db, user, project_id)
    project.status = "deleted"
    project.updated_at = utcnow()
    task = GenerationTask(
        id=new_id("tsk"),
        project_id=project.id,
        user_id=user.id,
        task_type="asset_cleanup",
        status="queued",
        idempotency_key=new_id("idem"),
        progress=0,
        created_at=utcnow(),
        updated_at=utcnow(),
    )
    db.add(task)
    write_audit(db, user.id, "project.delete", "project", project.id)
    db.commit()
    return task.id


def profile_out(project_id: str, profile: PropertyProfile | None, constraints: list[Constraint]) -> dict:
    return {
        "project_id": project_id,
        "house_type": None if profile is None else profile.house_type,
        "area_sqm": None if profile is None else profile.area_sqm,
        "orientation": None if profile is None else profile.orientation,
        "city": None if profile is None else profile.city,
        "budget": None if profile is None else profile.budget,
        "household_notes": None if profile is None else profile.household_notes,
        "constraints": [item.content for item in constraints],
    }


def get_profile(db: Session, user: User, project_id: str) -> dict:
    project = get_owned_project(db, user, project_id)
    profile = db.get(PropertyProfile, project.id)
    constraints = list(db.scalars(select(Constraint).where(Constraint.project_id == project.id)))
    return profile_out(project.id, profile, constraints)


def save_profile(db: Session, user: User, project_id: str, data: dict) -> dict:
    project = get_owned_project(db, user, project_id)
    profile = db.get(PropertyProfile, project.id)
    now = utcnow()
    if profile is None:
        profile = PropertyProfile(project_id=project.id, updated_at=now)
        db.add(profile)
    for field in ("house_type", "area_sqm", "orientation", "city", "budget", "household_notes"):
        if field in data:
            setattr(profile, field, data[field])
    profile.updated_at = now
    db.execute(delete(Constraint).where(Constraint.project_id == project.id))
    for content in data.get("constraints") or []:
        text = str(content).strip()
        if text:
            db.add(Constraint(id=new_id("cst"), project_id=project.id, content=text[:500], created_at=now))
    db.commit()
    constraints = list(db.scalars(select(Constraint).where(Constraint.project_id == project.id)))
    return profile_out(project.id, profile, constraints)


def create_upload(db: Session, user: User, project_id: str, filename: str, content_type: str, size_bytes: int, kind: str) -> dict:
    settings = get_settings()
    project = get_owned_project(db, user, project_id)
    if size_bytes > settings.file_max_bytes:
        raise AppError(400, "VALIDATION_ERROR", "文件超过大小限制")
    asset_id, key, url = prepare_upload(project.id, filename, content_type, kind)
    db.add(
        Asset(
            id=asset_id,
            project_id=project.id,
            user_id=user.id,
            kind=kind,
            object_key=key,
            filename=filename,
            content_type=content_type,
            size_bytes=size_bytes,
            status="pending",
            exif_stripped=False,
            created_at=utcnow(),
        )
    )
    db.commit()
    return {
        "asset_id": asset_id,
        "upload_url": url,
        "method": "PUT",
        "headers": {"Content-Type": content_type},
        "expires_in": settings.signed_url_seconds,
    }


def complete_upload(db: Session, user: User, project_id: str, asset_id: str) -> dict:
    asset = get_owned_asset(db, user, project_id, asset_id)
    asset.status = "ready"
    if not asset.exif_stripped:
        asset.exif_stripped = True
    db.commit()
    return {"asset_id": asset.id, "status": asset.status, "exif_stripped": True}


def ingest_asset_bytes(db: Session, user: User, project_id: str, asset_id: str, data: bytes, content_type: str | None) -> dict:
    """本地 Mock / 直传兜底：接收字节并清理 EXIF，不落原图日志。"""
    from house_design.media import strip_exif_bytes, store_local_asset

    settings = get_settings()
    asset = get_owned_asset(db, user, project_id, asset_id)
    if len(data) > settings.file_max_bytes:
        raise AppError(400, "VALIDATION_ERROR", "文件超过大小限制")
    cleaned, stripped = strip_exif_bytes(data, content_type or asset.content_type)
    store_local_asset(asset.object_key, cleaned)
    asset.size_bytes = len(cleaned)
    asset.status = "ready"
    asset.exif_stripped = stripped or True
    if content_type:
        asset.content_type = content_type
    db.commit()
    return {"asset_id": asset.id, "status": asset.status, "exif_stripped": asset.exif_stripped, "size_bytes": asset.size_bytes}


def download_url(db: Session, user: User, project_id: str, asset_id: str) -> dict:
    asset = get_owned_asset(db, user, project_id, asset_id)
    if asset.status != "ready":
        raise AppError(409, "INVALID_STATE", "文件尚未上传完成")
    settings = get_settings()
    return {"url": presign_get(asset.object_key), "expires_in": settings.signed_url_seconds}


def task_out(task: GenerationTask) -> dict:
    result = task.result_json
    if task.task_type == "render" and isinstance(result, dict) and result.get("shots"):
        from house_design.panorama import present_render

        result = present_render(task.id, result)
    return {
        "id": task.id,
        "project_id": task.project_id,
        "task_type": task.task_type,
        "status": task.status,
        "progress": task.progress,
        "result": result,
        "error_message": task.error_message,
        "disclaimer": DISCLAIMER,
        "created_at": iso(task.created_at),
        "updated_at": iso(task.updated_at),
    }


def _new_task(db: Session, user: User, project: Project, task_type: str, idempotency_key: str | None, payload: dict, cost: int = 0) -> GenerationTask:
    key = idempotency_key or new_id("idem")
    existing = db.scalar(
        select(GenerationTask).where(
            GenerationTask.project_id == project.id,
            GenerationTask.task_type == task_type,
            GenerationTask.idempotency_key == key,
        )
    )
    if existing is not None:
        return existing
    if cost:
        assert_budget(db, user.id, project.id, cost)
    now = utcnow()
    task = GenerationTask(
        id=new_id("tsk"),
        project_id=project.id,
        user_id=user.id,
        task_type=task_type,
        status="queued",
        idempotency_key=key,
        progress=0,
        input_json=payload,
        cost_units=0,
        created_at=now,
        updated_at=now,
    )
    db.add(task)
    append_event(db, task.id, "task.created", {"task_type": task_type}, task_id=task.id)
    db.commit()
    return task


def create_analysis_task(db: Session, user: User, project_id: str, asset_id: str | None, idempotency_key: str | None) -> GenerationTask:
    project = get_owned_project(db, user, project_id)
    if asset_id:
        asset = get_owned_asset(db, user, project.id, asset_id)
    else:
        asset = db.scalar(
            select(Asset).where(Asset.project_id == project.id, Asset.kind == "image", Asset.status == "ready")
        )
    if asset is None or asset.status != "ready":
        raise AppError(409, "NO_ASSET", "请先上传户型图")
    return _new_task(db, user, project, "floor_plan_analysis", idempotency_key, {"asset_id": asset.id})


def get_task(db: Session, user: User, task_id: str) -> GenerationTask:
    task = db.get(GenerationTask, task_id)
    if task is None:
        raise AppError(404, "NOT_FOUND", "任务不存在")
    get_owned_project(db, user, task.project_id)
    return task


def retry_task(db: Session, user: User, task_id: str) -> GenerationTask:
    task = get_task(db, user, task_id)
    if task.status not in {"failed", "canceled"}:
        raise AppError(409, "INVALID_STATE", "只有失败或已取消的任务可以重试")
    task.status = "queued"
    task.error_message = None
    task.progress = 0
    task.updated_at = utcnow()
    db.commit()
    return task


def cancel_task(db: Session, user: User, task_id: str) -> GenerationTask:
    task = get_task(db, user, task_id)
    if task.status in {"succeeded", "failed", "canceled"}:
        raise AppError(409, "INVALID_STATE", "任务已结束，不能取消")
    task.status = "canceled"
    task.updated_at = utcnow()
    append_event(db, task.id, "task.failed", {"message": "用户取消"}, task_id=task.id)
    db.commit()
    return task


def confirm_analysis(db: Session, user: User, project_id: str, task_id: str, rooms: list[dict], accept: bool) -> dict:
    project = get_owned_project(db, user, project_id)
    task = get_task(db, user, task_id)
    if task.project_id != project.id or task.task_type != "floor_plan_analysis":
        raise AppError(404, "NOT_FOUND", "分析任务不存在")
    if task.status != "succeeded":
        raise AppError(409, "INVALID_STATE", "分析尚未完成")
    if not accept:
        raise AppError(409, "CONFIRMATION_REQUIRED", "请确认或修正识别结果后再进入设计")
    return _write_confirmed_rooms(db, project, rooms)


def evaluate_floor_plan_quality(rooms: list) -> tuple[bool, str, dict]:
    """方案 B：不靠人手确认，用质量门决定能不能直接采用。"""
    cleaned: list[dict] = []
    for item in rooms or []:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip()
        if not name:
            continue
        area = item.get("area_sqm")
        if not isinstance(area, (int, float)) or float(area) <= 0:
            continue
        conf = item.get("confidence")
        cleaned.append(
            {
                "name": name[:40],
                "area_sqm": round(float(area), 1),
                "confidence": float(conf) if isinstance(conf, (int, float)) else None,
            }
        )
    if len(cleaned) < 3:
        return False, "房间认得太少，请换一张更清晰、带房间标注的户型图", {"rooms": cleaned}
    total = sum(float(item["area_sqm"]) for item in cleaned)
    if total < 25 or total > 480:
        return False, "从图上读到的面积不合理，请换一张标注清楚的户型图", {"rooms": cleaned, "total_area_sqm": round(total, 1)}
    names = "".join(item["name"] for item in cleaned)
    if not any(key in names for key in ("客厅", "起居", "主卧", "卧室")):
        return False, "没认出主要居住空间，请换一张完整户型图", {"rooms": cleaned, "total_area_sqm": round(total, 1)}
    scored = [item["confidence"] for item in cleaned if isinstance(item.get("confidence"), (int, float))]
    if scored and (sum(scored) / len(scored)) < 0.55:
        return False, "识别把握不够，请换一张更清楚的户型图", {"rooms": cleaned, "total_area_sqm": round(total, 1)}
    summary = {
        "rooms": cleaned,
        "room_count": len(cleaned),
        "total_area_sqm": round(total, 1),
        "headline": f"{len(cleaned)} 个空间 · 约 {round(total, 1)}㎡",
    }
    return True, "", summary


def adopt_analysis(db: Session, user: User, project_id: str, task_id: str) -> dict:
    """自动采用识别结果：过质量门就写入，不过就要求换图。不提供手改确认。"""
    project = get_owned_project(db, user, project_id)
    task = get_task(db, user, task_id)
    if task.project_id != project.id or task.task_type != "floor_plan_analysis":
        raise AppError(404, "NOT_FOUND", "分析任务不存在")
    if task.status != "succeeded":
        raise AppError(409, "INVALID_STATE", "分析尚未完成")
    result = task.result_json if isinstance(task.result_json, dict) else {}
    rooms = result.get("rooms") if isinstance(result.get("rooms"), list) else []
    ok, message, summary = evaluate_floor_plan_quality(rooms)
    if not ok:
        raise AppError(422, "FLOOR_PLAN_UNCLEAR", message)
    written = _write_confirmed_rooms(db, project, summary["rooms"])
    return {
        **written,
        "preview": summary,
        "adopted": True,
        "note": "已按户型图自动提取，无需再确认。若不对，请换图重识。",
    }


def default_rooms_for_area(area_sqm: float | None) -> list[dict]:
    """无户型图时，按面积自动铺一套常见商品房房间，供快速出 VR。"""
    total = float(area_sqm) if isinstance(area_sqm, (int, float)) and area_sqm > 0 else 89.0
    scale = total / 89.0
    template = [
        ("客厅", 22.0),
        ("主卧", 14.0),
        ("次卧", 10.0),
        ("厨房", 6.5),
        ("卫生间", 4.5),
        ("阳台", 4.0),
    ]
    return [{"name": name, "area_sqm": round(area * scale, 1)} for name, area in template]


def seed_confirmed_rooms(db: Session, user: User, project_id: str, rooms: list[dict] | None, area_sqm: float | None) -> dict:
    """快速设计：自动写入已确认房间，跳过逐步核对。"""
    project = get_owned_project(db, user, project_id)
    payload = rooms if rooms else default_rooms_for_area(area_sqm)
    return _write_confirmed_rooms(db, project, payload)


def _write_confirmed_rooms(db: Session, project: Project, rooms: list[dict]) -> dict:
    if not rooms:
        raise AppError(400, "VALIDATION_ERROR", "至少确认一个房间")
    db.execute(delete(Room).where(Room.project_id == project.id))
    now = utcnow()
    for item in rooms:
        name = str(item.get("name") or "").strip()
        if not name:
            continue
        db.add(
            Room(
                id=new_id("rom"),
                project_id=project.id,
                name=name,
                area_sqm=item.get("area_sqm"),
                source="user",
                confirmation_status="confirmed",
                confidence=1,
                created_at=now,
            )
        )
    db.commit()
    saved = list(db.scalars(select(Room).where(Room.project_id == project.id)))
    if not saved:
        raise AppError(400, "VALIDATION_ERROR", "至少确认一个房间")
    return {
        "project_id": project.id,
        "rooms": [
            {"id": room.id, "name": room.name, "area_sqm": room.area_sqm, "confirmation_status": room.confirmation_status}
            for room in saved
        ],
        "disclaimer": DISCLAIMER,
    }


def _conversation(db: Session, project: Project) -> Conversation:
    row = db.scalar(select(Conversation).where(Conversation.project_id == project.id).order_by(Conversation.created_at.desc()))
    if row is not None:
        return row
    now = utcnow()
    row = Conversation(id=new_id("cnv"), project_id=project.id, state="INTAKE", step_count=0, created_at=now, updated_at=now)
    db.add(row)
    db.flush()
    return row


def post_message(db: Session, user: User, project_id: str, content: str) -> dict:
    settings = get_settings()
    project = get_owned_project(db, user, project_id)
    text = content.strip()
    if not text:
        raise AppError(400, "VALIDATION_ERROR", "消息不能为空")
    conversation = _conversation(db, project)
    conversation.step_count += 1
    if conversation.step_count > settings.agent_max_steps:
        raise AppError(409, "LIMIT_EXCEEDED", "已达到本轮 Agent 步数上限")
    # 隔离：用户原文只作为 user 消息，系统提示保持常量。
    _messages = build_model_messages(text)
    db.add(Message(id=new_id("msg"), conversation_id=conversation.id, role="user", content=text, created_at=utcnow()))
    rooms = list(db.scalars(select(Room).where(Room.project_id == project.id)))
    state = next_state(rooms, conversation.step_count)
    conversation.state = state
    conversation.updated_at = utcnow()
    provider = get_provider()
    chat = provider.chat(_messages)
    options = None
    tool_name = "list_uncertainties" if state == "WAIT_USER_CONFIRMATION" else "get_project_context"
    if state == "PRESENT_DESIGN_DRAFT":
        tool_name = "generate_layout_options"
        options = invoke_tool(db, user, project, tool_name, {})["options"]
        conversation.draft_json = {"options": options}
    elif state == "NEED_CLARIFICATION":
        tool_name = "get_project_context"
        invoke_tool(db, user, project, tool_name, {})
    else:
        invoke_tool(db, user, project, tool_name, {})
    append_event(db, conversation.id, "tool.started", {"tool": tool_name})
    append_event(db, conversation.id, "tool.completed", {"tool": tool_name})
    reply = str(chat.get("text") or "").strip() or "已收到。"
    if state == "WAIT_USER_CONFIRMATION":
        reply = f"{reply}\n\n识别结果里还有未确认项。请先确认房间，我不会把猜测写成事实。"
        append_event(db, conversation.id, "approval.required", {"action": "confirm_analysis"})
    elif state == "NEED_CLARIFICATION":
        reply = f"{reply}\n\n还没有已确认的房间。请上传户型图并完成分析确认。"
    elif options is not None:
        reply = f"{reply}\n\n基于已确认房间，给出 3 个布局方向。它们是假设，不是施工结论。"
        append_event(db, conversation.id, "approval.required", {"action": "save_design_draft"})
    append_event(db, conversation.id, "assistant.delta", {"text": reply})
    db.add(
        Message(
            id=new_id("msg"),
            conversation_id=conversation.id,
            role="assistant",
            content=reply,
            payload={"options": options, "state": state, "disclaimer": DISCLAIMER},
            created_at=utcnow(),
        )
    )
    db.add(
        AgentRun(
            id=new_id("run"),
            project_id=project.id,
            conversation_id=conversation.id,
            provider=provider.name,
            model=str(chat.get("model")),
            prompt_version=settings.prompt_version,
            tool_version=settings.tool_version,
            input_tokens=int(chat.get("input_tokens") or 0),
            output_tokens=int(chat.get("output_tokens") or 0),
            latency_ms=1,
            status="succeeded",
            created_at=utcnow(),
        )
    )
    db.commit()
    return {
        "conversation_id": conversation.id,
        "state": state,
        "reply": reply,
        "options": options or layout_options() if state == "PRESENT_DESIGN_DRAFT" else options,
        "disclaimer": DISCLAIMER,
        "events": list_events(db, conversation.id),
    }


def version_out(version: DesignVersion) -> dict:
    return {
        "id": version.id,
        "project_id": version.project_id,
        "parent_id": version.parent_id,
        "title": version.title,
        "summary": version.summary,
        "status": version.status,
        "payload": version.payload,
        "created_at": iso(version.created_at),
    }


def list_versions(db: Session, user: User, project_id: str) -> dict:
    project = get_owned_project(db, user, project_id)
    rows = db.scalars(select(DesignVersion).where(DesignVersion.project_id == project.id).order_by(DesignVersion.created_at.desc()))
    return {"items": [version_out(row) for row in rows], "current_design_version_id": project.current_design_version_id}


def save_design_draft(
    db: Session,
    user: User,
    project_id: str,
    title: str,
    summary: str,
    options: list,
    confirmed: bool,
    style_id: str | None = None,
) -> dict:
    project = get_owned_project(db, user, project_id)
    if not confirmed:
        raise AppError(409, "APPROVAL_REQUIRED", "保存设计草案需要用户确认")
    invoke_tool(db, user, project, "save_design_draft", {"title": title, "confirmed": True})
    rooms = list(db.scalars(select(Room).where(Room.project_id == project.id)))
    if not rooms or any(room.confirmation_status != "confirmed" for room in rooms):
        raise AppError(409, "CONFIRMATION_REQUIRED", "户型识别尚未确认，不能写入设计版本")
    payload = {"options": options, "disclaimer": DISCLAIMER}
    if style_id:
        payload["style_id"] = style_id
    version = DesignVersion(
        id=new_id("ver"),
        project_id=project.id,
        parent_id=project.current_design_version_id,
        title=title.strip(),
        summary=summary,
        status="saved",
        payload=payload,
        created_at=utcnow(),
    )
    db.add(version)
    db.flush()
    db.add(
        DesignArtifact(
            id=new_id("art"),
            version_id=version.id,
            artifact_type="layout_draft",
            payload={"options": options},
            created_at=utcnow(),
        )
    )
    db.add(
        Approval(
            id=new_id("apv"),
            project_id=project.id,
            user_id=user.id,
            action="save_design_draft",
            status="approved",
            payload={"version_id": version.id},
            created_at=utcnow(),
        )
    )
    db.commit()
    return version_out(version)


def confirm_version(db: Session, user: User, project_id: str, version_id: str) -> dict:
    project = get_owned_project(db, user, project_id)
    version = db.get(DesignVersion, version_id)
    if version is None or version.project_id != project.id:
        raise AppError(404, "NOT_FOUND", "设计版本不存在")
    version.status = "confirmed"
    project.current_design_version_id = version.id
    project.updated_at = utcnow()
    db.commit()
    return version_out(version)


def rollback_version(db: Session, user: User, project_id: str, version_id: str) -> dict:
    project = get_owned_project(db, user, project_id)
    version = db.get(DesignVersion, version_id)
    if version is None or version.project_id != project.id:
        raise AppError(404, "NOT_FOUND", "设计版本不存在")
    project.current_design_version_id = version.id
    project.updated_at = utcnow()
    write_audit(db, user.id, "design.rollback", "design_version", version.id)
    db.commit()
    return version_out(version)


def create_render_task(db: Session, user: User, project_id: str, design_version_id: str, confirmed: bool, idempotency_key: str | None) -> GenerationTask:
    settings = get_settings()
    project = get_owned_project(db, user, project_id)
    if not confirmed:
        raise AppError(409, "APPROVAL_REQUIRED", "效果图生成需要用户确认")
    version = db.get(DesignVersion, design_version_id)
    if version is None or version.project_id != project.id:
        raise AppError(404, "NOT_FOUND", "设计版本不存在")
    invoke_tool(
        db,
        user,
        project,
        "create_render_task",
        {"design_version_id": design_version_id, "confirmed": True},
    )
    db.add(
        Approval(
            id=new_id("apv"),
            project_id=project.id,
            user_id=user.id,
            action="create_render_task",
            status="approved",
            payload={"design_version_id": design_version_id},
            created_at=utcnow(),
        )
    )
    return _new_task(
        db,
        user,
        project,
        "render",
        idempotency_key,
        {"design_version_id": design_version_id},
        cost=settings.render_cost_units,
    )


def create_scene_task(db: Session, user: User, project_id: str, design_version_id: str | None, confirmed: bool, idempotency_key: str | None) -> GenerationTask:
    project = get_owned_project(db, user, project_id)
    if not confirmed:
        raise AppError(409, "APPROVAL_REQUIRED", "创建 VR 全景需要用户确认")
    rooms = list(db.scalars(select(Room).where(Room.project_id == project.id)))
    # 还没有房间时（风格预览 / 演示）允许用默认客厅生成示意全景。
    if rooms and any(room.confirmation_status != "confirmed" for room in rooms):
        raise AppError(409, "CONFIRMATION_REQUIRED", "请先确认户型后再生成全景")
    return _new_task(
        db,
        user,
        project,
        "scene_build",
        idempotency_key,
        {"design_version_id": design_version_id, "source": "floorplan_photo", "mode": "vr_panorama"},
    )


def get_manifest(db: Session, user: User, project_id: str, version_id: str) -> dict:
    from house_design.panorama import scene_files_usable, sign_panorama_url

    project = get_owned_project(db, user, project_id)
    scene = db.get(SceneVersion, version_id)
    if scene is None or scene.project_id != project.id or not scene.manifest:
        raise AppError(404, "NOT_FOUND", "场景不存在")
    manifest = dict(scene.manifest)
    manifest["design_version_id"] = scene.design_version_id
    if manifest.get("mode") != "vr_panorama" or not (manifest.get("panoramas") or []):
        raise AppError(404, "NOT_FOUND", "该场景没有 VR 全景，请重新生成")
    if not scene_files_usable(scene.id, list(manifest.get("panoramas") or [])):
        raise AppError(404, "NOT_FOUND", "这一版全景过暗或文件缺失，请重新生成")
    signed = []
    for item in manifest.get("panoramas") or []:
        row = dict(item)
        room_id = str(row.get("room_id") or "")
        if room_id:
            url, expires = sign_panorama_url(scene.id, room_id)
            row["url"] = url
            row["expires_at"] = expires
        signed.append(row)
    if not signed:
        raise AppError(404, "NOT_FOUND", "该场景没有 VR 全景，请重新生成")
    manifest["panoramas"] = signed
    manifest["initial_heading"] = manifest.get("initial_heading", 0)
    render = db.scalar(
        select(GenerationTask)
        .where(
            GenerationTask.project_id == project.id,
            GenerationTask.task_type == "render",
            GenerationTask.status == "succeeded",
        )
        .order_by(GenerationTask.created_at.desc())
    )
    if render is not None and render.result_json:
        from house_design.panorama import present_render

        result = present_render(render.id, render.result_json) if isinstance(render.result_json, dict) else render.result_json
        shots = result.get("shots") if isinstance(result, dict) else None
        first_url = None
        if isinstance(shots, list) and shots:
            first_url = shots[0].get("url")
        if not first_url and isinstance(result, dict):
            first_url = result.get("url")
        manifest["fallback_render"] = {
            "task_id": render.id,
            "url": first_url,
            "note": result.get("note") if isinstance(result, dict) else None,
            "shots": shots if isinstance(shots, list) else [],
        }
    manifest["disclaimer"] = DISCLAIMER
    manifest["readonly"] = True
    return manifest


def latest_scene(db: Session, user: User, project_id: str) -> dict:
    from house_design.panorama import scene_files_usable

    project = get_owned_project(db, user, project_id)
    scenes = list(
        db.scalars(
            select(SceneVersion)
            .where(SceneVersion.project_id == project.id, SceneVersion.status != "rolled_back")
            .order_by(SceneVersion.created_at.desc())
        )
    )
    for scene in scenes:
        manifest = scene.manifest if isinstance(scene.manifest, dict) else {}
        panoramas = manifest.get("panoramas")
        if manifest.get("mode") != "vr_panorama" or not isinstance(panoramas, list) or not panoramas:
            continue
        if not scene_files_usable(scene.id, list(panoramas)):
            # 过暗的旧图直接作废，避免反复打开黑屏。
            scene.status = "rolled_back"
            db.commit()
            continue
        return get_manifest(db, user, project_id, scene.id)
    raise AppError(404, "NOT_FOUND", "还没有可用的 VR 全景")


def confirm_scene(db: Session, user: User, project_id: str, version_id: str) -> dict:
    project = get_owned_project(db, user, project_id)
    scene = db.get(SceneVersion, version_id)
    if scene is None or scene.project_id != project.id:
        raise AppError(404, "NOT_FOUND", "场景不存在")
    scene.status = "confirmed"
    db.commit()
    return {"id": scene.id, "status": scene.status, "readonly": True, "disclaimer": DISCLAIMER}


def rollback_scene(db: Session, user: User, project_id: str, version_id: str) -> dict:
    project = get_owned_project(db, user, project_id)
    scene = db.get(SceneVersion, version_id)
    if scene is None or scene.project_id != project.id:
        raise AppError(404, "NOT_FOUND", "场景不存在")
    scene.status = "rolled_back"
    previous = db.scalar(
        select(SceneVersion)
        .where(SceneVersion.project_id == project.id, SceneVersion.id != scene.id)
        .order_by(SceneVersion.created_at.desc())
    )
    restored = None
    if previous is not None:
        previous.status = "confirmed"
        restored = previous.id
    write_audit(db, user.id, "scene.rollback", "scene_version", scene.id)
    db.commit()
    return {"id": scene.id, "status": scene.status, "restored_id": restored, "readonly": True}


def delete_asset(db: Session, user: User, project_id: str, asset_id: str) -> None:
    asset = get_owned_asset(db, user, project_id, asset_id)
    invoke_tool(db, user, get_owned_project(db, user, project_id), "delete_project_assets", {"user_action": True, "confirmed": True})
    asset.status = "deleted"
    write_audit(db, user.id, "asset.delete", "asset", asset.id)
    db.commit()
