import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.middleware.base import BaseHTTPMiddleware

from api.routers.v1 import router as v1_router
from house_design.config import get_settings
from house_design.database import init_db, ping_db
from house_design.errors import AppError
from house_design.runtime import ensure_bucket, repo_root, seed_demo
from house_design.security import new_id

logger = logging.getLogger("house_design")


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("x-request-id") or new_id("req")
        request.state.request_id = request_id
        response = await call_next(request)
        response.headers["x-request-id"] = request_id
        return response


def _request_id(request: Request) -> str:
    return getattr(request.state, "request_id", "req_unknown")


def _error_body(request: Request, code: str, message: str, details=None) -> dict:
    body = {"code": code, "message": message, "request_id": _request_id(request)}
    if details is not None:
        body["details"] = details
    return body


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logging.basicConfig(level=logging.INFO)
    init_db()
    seed_demo()
    ensure_bucket()
    yield


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(title=settings.app_name, version="0.1.0", lifespan=lifespan)
    app.add_middleware(RequestIdMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(AppError)
    async def handle_app_error(request: Request, exc: AppError):
        return JSONResponse(
            status_code=exc.status,
            content=_error_body(request, exc.code, exc.message, exc.details),
            headers={"x-request-id": _request_id(request)},
        )

    @app.exception_handler(RequestValidationError)
    async def handle_validation(request: Request, exc: RequestValidationError):
        details = []
        for item in exc.errors():
            details.append({key: value for key, value in item.items() if key != "input"})
        return JSONResponse(
            status_code=422,
            content=_error_body(request, "VALIDATION_ERROR", "请求参数不正确", details),
            headers={"x-request-id": _request_id(request)},
        )

    @app.exception_handler(Exception)
    async def handle_unexpected(request: Request, exc: Exception):
        logger.exception("unhandled error")
        return JSONResponse(
            status_code=500,
            content=_error_body(request, "INTERNAL", "服务器内部错误"),
            headers={"x-request-id": _request_id(request)},
        )

    @app.get("/health")
    @app.get("/api/v1/health")
    def health():
        current = get_settings()
        return {"status": "ok", "use_mock_ai": current.use_mock_ai}

    @app.get("/health/ready")
    def ready():
        ping_db()
        return {"status": "ready"}

    @app.get("/api/v1/scenes/{scene_id}/panoramas/{room_id}.jpg")
    def scene_panorama(scene_id: str, room_id: str, exp: int = Query(default=0), sig: str = Query(default="")):
        from house_design.panorama import verify_panorama_url

        if not scene_id.startswith("scn_"):
            raise HTTPException(status_code=404, detail="not found")
        if any(ch in scene_id for ch in "/\\.") or any(ch in room_id for ch in "/\\."):
            raise HTTPException(status_code=404, detail="not found")
        if not verify_panorama_url(scene_id, room_id, exp, sig):
            raise HTTPException(status_code=403, detail="签名无效或已过期")
        path = repo_root() / ".local-assets" / "scenes" / scene_id / "panoramas" / f"{room_id}.jpg"
        if not path.is_file():
            raise HTTPException(status_code=404, detail="not found")
        return FileResponse(
            path,
            media_type="image/jpeg",
            headers={
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "public, max-age=7200",
            },
        )

    @app.get("/api/v1/renders/{task_id}/shots/{room_id}.jpg")
    def render_shot(task_id: str, room_id: str, exp: int = Query(default=0), sig: str = Query(default="")):
        from house_design.panorama import verify_render_url

        if not task_id.startswith("tsk_"):
            raise HTTPException(status_code=404, detail="not found")
        if any(ch in task_id for ch in "/\\.") or any(ch in room_id for ch in "/\\."):
            raise HTTPException(status_code=404, detail="not found")
        if not verify_render_url(task_id, room_id, exp, sig):
            raise HTTPException(status_code=403, detail="签名无效或已过期")
        path = repo_root() / ".local-assets" / "renders" / task_id / "shots" / f"{room_id}.jpg"
        if not path.is_file():
            raise HTTPException(status_code=404, detail="not found")
        return FileResponse(
            path,
            media_type="image/jpeg",
            headers={
                "Access-Control-Allow-Origin": "*",
                "Cache-Control": "public, max-age=7200",
            },
        )

    # Register API routes before static mounts.
    app.include_router(v1_router, prefix="/api/v1")
    viewer = repo_root() / "webview-vr"
    if viewer.exists():
        app.mount("/viewer", StaticFiles(directory=str(viewer), html=True), name="viewer")
    return app


app = create_app()
