# 依赖版本

| 组件 | 版本 |
| --- | --- |
| Flutter | 3.47.2 |
| Dart | 3.13.2 |
| Python | 3.11 |
| API | FastAPI 0.115.x、Uvicorn 0.34.x |
| 业务存储 | 本地 JSON 文件（`DATA_DIR`）；无 SQLAlchemy / Alembic |
| 队列 | Redis 7、ARQ 0.26.x |
| 对象存储 | MinIO（S3 API）、boto3 |
| 客户端 | Riverpod 3、go_router 18、Dio 5、flutter_secure_storage、webview_flutter、image_picker |
| VR 全景查看 | Three.js 0.170（`webview-vr/`，WebView 页面按需从 CDN 加载；等距柱状 JPEG 球体贴图） |

精确 Python 约束见 `services/requirements.txt`。未安装 Docker 时，用 `DATA_DIR` 环境变量做本地冒烟。产品需求文档仍记载 MySQL 8.x 为可选/目标主库方向；当前本地实现以文件存储为准。
