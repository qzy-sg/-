import json

from fastapi import APIRouter, Query, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from api.deps import CurrentUser, DbSession
from house_design.models import GenerationTask
from house_design.runtime import dispatch, list_events
from house_design.sms_auth import issue_code
from house_design.wechat_auth import issue_state
from house_design.usecases import (
    ai_consult,
    ai_consult_stream,
    adopt_analysis,
    cancel_task,
    complete_upload,
    confirm_analysis,
    confirm_scene,
    confirm_version,
    create_analysis_task,
    create_project,
    create_render_task,
    create_scene_task,
    create_upload,
    delete_asset,
    delete_project,
    download_url,
    get_manifest,
    latest_scene,
    get_profile,
    get_task,
    ingest_asset_bytes,
    list_projects,
    list_versions,
    login,
    login_phone,
    login_wechat,
    post_message,
    get_account,
    update_account,
    project_out,
    retry_task,
    rollback_scene,
    rollback_version,
    save_design_draft,
    save_profile,
    seed_confirmed_rooms,
    task_out,
    update_project,
    register_account,
)
from house_design.runtime import get_owned_project

router = APIRouter()

JOB_FOR_TYPE = {
    "floor_plan_analysis": "analyze_floor_plan",
    "render": "create_render",
    "scene_build": "scene_build",
    "asset_cleanup": "asset_cleanup",
}


class LoginIn(BaseModel):
    email: str = Field(min_length=3, max_length=255)
    password: str = Field(min_length=1, max_length=200)


class PhoneIn(BaseModel):
    phone: str = Field(min_length=11, max_length=20)


class PhoneAuthIn(PhoneIn):
    code: str = Field(min_length=4, max_length=8)


class RegisterIn(PhoneAuthIn):
    password: str = Field(min_length=6, max_length=200)
    nickname: str | None = None


class AccountIn(BaseModel):
    display_name: str | None = Field(default=None, max_length=20)
    city: str | None = Field(default=None, max_length=20)
    bio: str | None = Field(default=None, max_length=80)
    avatar_id: str | None = Field(default=None, max_length=20)


class WechatAuthIn(BaseModel):
    state: str = Field(min_length=8, max_length=80)
    subject: str = Field(min_length=12, max_length=64)


class AiConsultIn(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class ProjectIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    city: str | None = None


class ProjectPatch(BaseModel):
    name: str | None = Field(default=None, max_length=80)
    city: str | None = None
    status: str | None = None


class ProfileIn(BaseModel):
    house_type: str | None = None
    area_sqm: float | None = None
    orientation: str | None = None
    city: str | None = None
    budget: float | None = None
    household_notes: str | None = None
    constraints: list[str] = []


class UploadIn(BaseModel):
    filename: str = Field(min_length=1, max_length=255)
    content_type: str
    size_bytes: int = Field(ge=0)
    kind: str = "image"


class AnalysisIn(BaseModel):
    asset_id: str | None = None
    idempotency_key: str | None = None


class ConfirmAnalysisIn(BaseModel):
    accept: bool
    rooms: list[dict] = []


class MessageIn(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class DraftIn(BaseModel):
    title: str = Field(min_length=1, max_length=120)
    summary: str = ""
    options: list = []
    confirmed: bool = False
    style_id: str | None = None


class SeedRoomsIn(BaseModel):
    rooms: list[dict] | None = None
    area_sqm: float | None = None


class RenderIn(BaseModel):
    design_version_id: str
    confirmed: bool = False
    idempotency_key: str | None = None


class SceneIn(BaseModel):
    design_version_id: str | None = None
    confirmed: bool = False
    idempotency_key: str | None = None


def _run(db: DbSession, task: GenerationTask) -> dict:
    if task.status == "queued":
        dispatch(JOB_FOR_TYPE[task.task_type], task.id)
        db.expire(task)
        db.refresh(task)
    return task_out(task)


def _sse(events: list[dict]):
    for event in events:
        payload = json.dumps(event, ensure_ascii=False)
        yield f"id: {event['sequence']}\nevent: {event['type']}\ndata: {payload}\n\n"


@router.post("/auth/login")
def auth_login(body: LoginIn, db: DbSession) -> dict:
    return login(db, body.email, body.password)


@router.post("/auth/sms/send")
def auth_sms_send(body: PhoneIn) -> dict:
    return issue_code(body.phone)


@router.post("/auth/register", status_code=201)
def auth_register(body: RegisterIn, db: DbSession) -> dict:
    return register_account(db, body.phone, body.code, body.password)


@router.post("/auth/phone")
def auth_phone(body: PhoneAuthIn, db: DbSession) -> dict:
    return login_phone(db, body.phone, body.code)


@router.post("/auth/wechat/challenge")
def auth_wechat_challenge() -> dict:
    return issue_state()


@router.post("/auth/wechat")
def auth_wechat(body: WechatAuthIn, db: DbSession) -> dict:
    return login_wechat(db, body.state, body.subject)


@router.post("/ai/consult")
def ai_consult_route(body: AiConsultIn, user: CurrentUser, db: DbSession) -> dict:
    return ai_consult(db, user, body.content)


@router.post("/ai/consult/stream")
def ai_consult_stream_route(body: AiConsultIn, user: CurrentUser, db: DbSession):
    return StreamingResponse(
        ai_consult_stream(db, user, body.content),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.get("/auth/me")
def auth_me(user: CurrentUser) -> dict:
    return get_account(user)


@router.patch("/auth/me")
def auth_me_patch(body: AccountIn, user: CurrentUser, db: DbSession) -> dict:
    return update_account(db, user, body.model_dump(exclude_unset=True))


@router.get("/projects")
def projects_list(user: CurrentUser, db: DbSession) -> dict:
    return list_projects(db, user)


@router.post("/projects", status_code=201)
def projects_create(body: ProjectIn, user: CurrentUser, db: DbSession) -> dict:
    return create_project(db, user, body.name, body.city)


@router.get("/projects/{project_id}")
def projects_get(project_id: str, user: CurrentUser, db: DbSession) -> dict:
    return project_out(get_owned_project(db, user, project_id))


@router.patch("/projects/{project_id}")
def projects_patch(project_id: str, body: ProjectPatch, user: CurrentUser, db: DbSession) -> dict:
    return update_project(db, user, project_id, body.name, body.city, body.status)


@router.delete("/projects/{project_id}")
def projects_delete(project_id: str, user: CurrentUser, db: DbSession) -> dict:
    task_id = delete_project(db, user, project_id)
    task = db.get(GenerationTask, task_id)
    if task is not None:
        _run(db, task)
    return {"deleted": True, "project_id": project_id}


@router.get("/projects/{project_id}/profile")
def profile_get(project_id: str, user: CurrentUser, db: DbSession) -> dict:
    return get_profile(db, user, project_id)


@router.put("/projects/{project_id}/profile")
def profile_put(project_id: str, body: ProfileIn, user: CurrentUser, db: DbSession) -> dict:
    return save_profile(db, user, project_id, body.model_dump())


@router.post("/projects/{project_id}/assets/upload-url")
def upload_url(project_id: str, body: UploadIn, user: CurrentUser, db: DbSession) -> dict:
    return create_upload(db, user, project_id, body.filename, body.content_type, body.size_bytes, body.kind)


@router.post("/projects/{project_id}/assets/{asset_id}/complete")
def upload_complete(project_id: str, asset_id: str, user: CurrentUser, db: DbSession) -> dict:
    return complete_upload(db, user, project_id, asset_id)


@router.put("/projects/{project_id}/assets/{asset_id}/bytes")
async def upload_bytes(project_id: str, asset_id: str, request: Request, user: CurrentUser, db: DbSession) -> dict:
    data = await request.body()
    content_type = request.headers.get("content-type")
    return ingest_asset_bytes(db, user, project_id, asset_id, data, content_type)


@router.get("/projects/{project_id}/assets/{asset_id}/download-url")
def asset_download(project_id: str, asset_id: str, user: CurrentUser, db: DbSession) -> dict:
    return download_url(db, user, project_id, asset_id)


@router.delete("/projects/{project_id}/assets/{asset_id}")
def asset_delete(project_id: str, asset_id: str, user: CurrentUser, db: DbSession) -> dict:
    delete_asset(db, user, project_id, asset_id)
    return {"deleted": True}


@router.post("/projects/{project_id}/analysis-tasks", status_code=201)
def analysis_create(project_id: str, body: AnalysisIn, user: CurrentUser, db: DbSession) -> dict:
    task = create_analysis_task(db, user, project_id, body.asset_id, body.idempotency_key)
    return _run(db, task)


@router.post("/projects/{project_id}/analysis-tasks/{task_id}/confirm")
def analysis_confirm(project_id: str, task_id: str, body: ConfirmAnalysisIn, user: CurrentUser, db: DbSession) -> dict:
    return confirm_analysis(db, user, project_id, task_id, body.rooms, body.accept)


@router.post("/projects/{project_id}/analysis-tasks/{task_id}/adopt")
def analysis_adopt(project_id: str, task_id: str, user: CurrentUser, db: DbSession) -> dict:
    return adopt_analysis(db, user, project_id, task_id)


@router.post("/projects/{project_id}/rooms/seed", status_code=201)
def rooms_seed(project_id: str, body: SeedRoomsIn, user: CurrentUser, db: DbSession) -> dict:
    return seed_confirmed_rooms(db, user, project_id, body.rooms, body.area_sqm)


@router.get("/tasks/{task_id}")
def tasks_get(task_id: str, user: CurrentUser, db: DbSession) -> dict:
    return task_out(get_task(db, user, task_id))


@router.post("/tasks/{task_id}/retry")
def tasks_retry(task_id: str, user: CurrentUser, db: DbSession) -> dict:
    task = retry_task(db, user, task_id)
    return _run(db, task)


@router.post("/tasks/{task_id}/cancel")
def tasks_cancel(task_id: str, user: CurrentUser, db: DbSession) -> dict:
    return task_out(cancel_task(db, user, task_id))


def _resume_after(request: Request, after_sequence: int) -> int:
    raw = request.headers.get("last-event-id")
    if raw and raw.isdigit():
        return max(after_sequence, int(raw))
    return after_sequence


@router.get("/tasks/{task_id}/events")
def tasks_events(task_id: str, request: Request, user: CurrentUser, db: DbSession, after_sequence: int = Query(default=0, ge=0)) -> dict:
    task = get_task(db, user, task_id)
    return {"items": list_events(db, task.id, _resume_after(request, after_sequence))}


@router.get("/tasks/{task_id}/events/stream")
def tasks_stream(task_id: str, request: Request, user: CurrentUser, db: DbSession, after_sequence: int = Query(default=0, ge=0)):
    task = get_task(db, user, task_id)
    events = list_events(db, task.id, _resume_after(request, after_sequence))
    return StreamingResponse(_sse(events), media_type="text/event-stream")


@router.post("/projects/{project_id}/messages")
def messages_post(project_id: str, body: MessageIn, user: CurrentUser, db: DbSession) -> dict:
    return post_message(db, user, project_id, body.content)


@router.get("/conversations/{conversation_id}/events")
def conversation_events(conversation_id: str, request: Request, user: CurrentUser, db: DbSession, after_sequence: int = Query(default=0, ge=0)) -> dict:
    from house_design.models import Conversation

    conversation = db.get(Conversation, conversation_id)
    if conversation is None:
        from house_design.errors import AppError

        raise AppError(404, "NOT_FOUND", "对话不存在")
    get_owned_project(db, user, conversation.project_id)
    return {"items": list_events(db, conversation.id, _resume_after(request, after_sequence))}


@router.get("/conversations/{conversation_id}/events/stream")
def conversation_stream(conversation_id: str, request: Request, user: CurrentUser, db: DbSession, after_sequence: int = Query(default=0, ge=0)):
    from house_design.errors import AppError
    from house_design.models import Conversation

    conversation = db.get(Conversation, conversation_id)
    if conversation is None:
        raise AppError(404, "NOT_FOUND", "对话不存在")
    get_owned_project(db, user, conversation.project_id)
    events = list_events(db, conversation.id, _resume_after(request, after_sequence))
    return StreamingResponse(_sse(events), media_type="text/event-stream")


@router.get("/projects/{project_id}/design-versions")
def versions_list(project_id: str, user: CurrentUser, db: DbSession) -> dict:
    return list_versions(db, user, project_id)


@router.post("/projects/{project_id}/design-versions", status_code=201)
def versions_save(project_id: str, body: DraftIn, user: CurrentUser, db: DbSession) -> dict:
    return save_design_draft(
        db,
        user,
        project_id,
        body.title,
        body.summary,
        body.options,
        body.confirmed,
        style_id=body.style_id,
    )


@router.post("/projects/{project_id}/design-versions/{version_id}/confirm")
def versions_confirm(project_id: str, version_id: str, user: CurrentUser, db: DbSession) -> dict:
    return confirm_version(db, user, project_id, version_id)


@router.post("/projects/{project_id}/design-versions/{version_id}/rollback")
def versions_rollback(project_id: str, version_id: str, user: CurrentUser, db: DbSession) -> dict:
    return rollback_version(db, user, project_id, version_id)


@router.post("/projects/{project_id}/render-tasks", status_code=201)
def renders_create(project_id: str, body: RenderIn, user: CurrentUser, db: DbSession) -> dict:
    task = create_render_task(db, user, project_id, body.design_version_id, body.confirmed, body.idempotency_key)
    return _run(db, task)


@router.post("/projects/{project_id}/scene-tasks", status_code=201)
def scenes_create(project_id: str, body: SceneIn, user: CurrentUser, db: DbSession) -> dict:
    task = create_scene_task(db, user, project_id, body.design_version_id, body.confirmed, body.idempotency_key)
    return _run(db, task)


@router.get("/projects/{project_id}/scene-versions/latest")
def scenes_latest(project_id: str, user: CurrentUser, db: DbSession) -> dict:
    return latest_scene(db, user, project_id)


@router.get("/projects/{project_id}/scene-versions/{version_id}/manifest")
def scenes_manifest(project_id: str, version_id: str, user: CurrentUser, db: DbSession) -> dict:
    return get_manifest(db, user, project_id, version_id)


@router.post("/projects/{project_id}/scene-versions/{version_id}/confirm")
def scenes_confirm(project_id: str, version_id: str, user: CurrentUser, db: DbSession) -> dict:
    return confirm_scene(db, user, project_id, version_id)


@router.post("/projects/{project_id}/scene-versions/{version_id}/rollback")
def scenes_rollback(project_id: str, version_id: str, user: CurrentUser, db: DbSession) -> dict:
    return rollback_scene(db, user, project_id, version_id)
