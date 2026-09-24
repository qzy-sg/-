# AI 房屋设计助手

本地框架：Flutter + FastAPI + Redis / MinIO。业务数据默认落在 **`DATA_DIR` JSON 文件存储**（本地冒烟与 Compose 均可用）。默认 `USE_MOCK_AI=true`，不调用外部模型。

## 目录

- `apps/mobile` Flutter 客户端
- `services/api` HTTP API
- `services/worker` ARQ Worker
- `services/house_design` 领域、Agent、任务
- `contracts` OpenAPI 与事件契约
- `webview-vr` Three.js VR 全景查看页（等距柱状 JPEG 球体贴图）
- `infra` Compose

## 无 Docker 冒烟

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\python -m pip install -r services\requirements.txt
$env:PYTHONPATH = "services"
$env:DATA_DIR = ".\data\store"
$env:USE_MOCK_AI = "true"
$env:USE_MOCK_STORAGE = "true"
$env:TASK_INLINE = "true"
.\.venv\Scripts\python -m uvicorn api.main:app --app-dir services --reload --port 8000
```

另开终端：

```powershell
.\.venv\Scripts\python -m pytest
cd apps\mobile
flutter run --dart-define=API_BASE=http://10.0.2.2:8000
```

模拟器访问宿主机用 `10.0.2.2`。演示账号：`demo@local.test` / `demo-password`。

## Docker Compose

安装 Docker 后：

```powershell
docker compose -f infra/docker-compose.yml up --build
```

此时 API 使用 Redis、MinIO 与挂载的 `DATA_DIR` 文件存储，任务由 Worker 执行。

开发环境也会在 API 启动时初始化本地存储。对象存储会话时区 UTC。
