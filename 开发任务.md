# AI 房屋设计助手 — 开发任务清单

> **依据：** [REQUIREMENTS.md](./REQUIREMENTS.md) v1.3  
> **范围：** 本地落地（不上线）；阶段 6 仅保留可选本地质量项  
> **栈：** Flutter · FastAPI(P1) · MySQL 8 · Redis/ARQ · MinIO · SSE · Three.js(VR 全景)  
> **状态约定：** `待办` / `进行中` / `完成` / `阻塞` / `不做`  
> **版本：** v1.6 · 2026-09-19

---

## 0. 总览与顺序

```text
1B 契约与工程骨架
 → 2 地基（Auth / 项目 / 上传）
 → 3 户型分析确认
 → 4 Agent + SSE + 设计版本
 → 5 L0 效果图 + 费用守卫
 ↔ 5B VR 全景（可与 5 并行搭查看器；验收需 5 的降级路径）
 → 6* 本地质量（可选；不上线）
```

| 阶段 | 目标 | 依赖 | 建议优先级 |
| --- | --- | --- | --- |
| 1B | OpenAPI、依赖版本、Compose、仓库骨架 | 需求 v1.3 | P0 |
| 2 | 登录、项目、资料、上传删除 | 1B | P0 |
| 3 | 异步分析、置信度、确认门禁 | 2 | P0 |
| 4 | Agent、工具白名单、SSE、版本 | 3 | P0 |
| 5 | L0 效果图、预算、幂等取消 | 4 | P0 |
| 5B | 等距柱状 JPEG、WebView、manifest、房间切换 | 2+（依赖已确认布局）；降级依赖 5 | P0 |
| 6* | 测试加固、本地监控（不上线） | 5/5B | P2 |

**本地拓扑：** `mysql` + `redis` + `minio` + `api` + `worker` + Flutter（优先 Android）。

---

## 1B — 契约与工程骨架

| ID | 任务 | 产出 | 状态 |
| --- | --- | --- | --- |
| T-1B-01 | 初始化 monorepo / 双仓结构（`apps/mobile`、`services/api`、`services/worker`、`infra`） | 目录与 README 启动说明 | 完成 |
| T-1B-02 | Docker Compose：MySQL 8、Redis、MinIO、api、worker | `docker-compose.yml` 一键起依赖 | 完成 |
| T-1B-03 | 锁定 Python/Flutter 依赖版本（FastAPI、ARQ、boto3 等） | `requirements.txt` / `pyproject`、`pubspec.yaml` | 完成 |
| T-1B-04 | 起草 OpenAPI `/api/v1`（Auth、Projects、Assets、Tasks、Messages、DesignVersions、Render、Scene） | `openapi.yaml` | 完成 |
| T-1B-05 | 统一错误模型：`code` / `message` / `details` / `request_id` | 共享 schema | 完成 |
| T-1B-06 | 事件信封：`id` / `type` / `sequence` / `created_at` / `data` | 事件类型枚举文档 | 完成 |
| T-1B-07 | 环境变量模板：`USE_MOCK_AI`、DB、Redis、MinIO、预算上限 | `.env.example` | 完成 |
| T-1B-08 | AI Provider 抽象接口（chat / vision / image）+ Mock 实现骨架 | 可切换 mock 的接口 | 完成 |
| T-1B-09 | （可选）选定具体主 Provider 账号；未定时全程 Mock | 配置说明 | 完成 |

**退出标准：** Compose 可起；OpenAPI 评审通过；Flutter / API 空工程可编译连接健康检查。

---

## 2 — 地基（FR-01～04, FR-12～13 部分）

### 2.1 后端

| ID | 任务 | 关联 | 状态 |
| --- | --- | --- | --- |
| T-2-01 | User 表 + 登录/发令牌（本地 JWT 即可） | FR-01 | 完成 |
| T-2-02 | Project CRUD + 用户隔离（归属校验） | FR-02 | 完成 |
| T-2-03 | PropertyProfile 读写 API | FR-03 | 完成 |
| T-2-04 | Alembic 迁移基线（核心实体元数据） | §6 | 完成 |
| T-2-05 | Asset：申请 upload-url → 直传 MinIO → complete | FR-04 | 完成 |
| T-2-06 | download-url 短期签名；禁止长期密钥下发 | NFR-SEC-03 | 完成 |
| T-2-07 | 删除项目及关联对象（软删/清理任务可后置） | FR-12 | 完成 |
| T-2-08 | 请求日志 + `request_id` 中间件 | §12.1 | 完成 |
| T-2-09 | 权限/越权基础测试（不能读他人项目/文件） | NFR | 完成 |

### 2.2 Flutter

| ID | 任务 | 关联 | 状态 |
| --- | --- | --- | --- |
| T-2-10 | 工程骨架：Riverpod + go_router + Dio | D-FE-02 | 完成 |
| T-2-11 | 登录页 + Token 安全存储 | FR-01 | 完成 |
| T-2-12 | 项目列表 / 创建 / 详情导航 | FR-02 | 完成 |
| T-2-13 | 房屋资料表单页 | FR-03 | 完成 |
| T-2-14 | 图片选择、压缩、上传进度、预览、失败重试 | FR-04 | 完成 |
| T-2-15 | 全局状态：加载/空/失败/权限过期 | §4.2 | 完成 |
| T-2-16 | 关键页展示 AI 参考/专业复核提示 | FR-13 | 完成 |
| T-2-17 | 基于 OpenAPI 的契约/冒烟测试（至少关键路径） | §12.1 | 完成 |

**退出标准：** Android 上可登录 → 建项目 → 填资料 → 上传户型图 → 预览/删除；越权用例通过。

---

## 3 — 户型分析确认（FR-05～07）

| ID | 任务 | 关联 | 状态 |
| --- | --- | --- | --- |
| T-3-01 | GenerationTask 状态机（created/running/succeeded/failed/cancelled） | §8.6 | 完成 |
| T-3-02 | `POST .../analysis-tasks` + 幂等键 | FR-05 | 完成 |
| T-3-03 | ARQ Worker：拉图 → EXIF 清理 → 视觉分析（Mock 可先） | NFR-SEC-05 | 完成 |
| T-3-04 | 结构化结果：房间候选、置信度、不确定项 | FR-06 | 完成 |
| T-3-05 | 确认/修正 API：未确认不得写入正式 Room 事实 | FR-07 硬规则 | 完成 |
| T-3-06 | 任务 retry / 超时 / 有限重试 | §12.2 | 完成 |
| T-3-07 | 任务事件持久化 + `GET .../events`（可先轮询） | §8.4 | 完成 |
| T-3-08 | Flutter：分析进度、结果卡片、不确定项编辑、确认门禁 | FR-06/07 | 完成 |
| T-3-09 | 文案：分析≠施工结论 | OOS-01 | 完成 |
| T-3-10 | 模糊图/低置信度用例：禁止写成已确认 | NFR-QA | 完成 |

**退出标准：** 上传后异步出分析；用户确认前 Agent/后续设计不可把猜测当事实；失败可重试。

---

## 4 — Agent + SSE + 设计版本（FR-08～11）

| ID | 任务 | 关联 | 状态 |
| --- | --- | --- | --- |
| T-4-01 | AgentRun + Conversation/Message 模型 | §6.1 | 完成 |
| T-4-02 | 状态机落地：INTAKE → … → PRESENT_RESULTS（按 §7.2） | D-AG-01 | 完成 |
| T-4-03 | 工具白名单 + JSON Schema + 服务端二次校验 | §7.3 | 完成 |
| T-4-04 | 实现只读/计算工具：`get_project_context`、`list_uncertainties`、`validate_design_constraints`、`generate_layout_options`（可 Mock） | FR-08 | 完成 |
| T-4-05 | 写入类工具需确认：`save_design_draft` | §7.3 | 完成 |
| T-4-06 | DesignVersion：创建、列表、比较、选择、回退 | FR-09 | 完成 |
| T-4-07 | SSE：`assistant.delta` / tool.* / approval.required / task.* | FR-10 | 完成 |
| T-4-08 | 断线恢复：`Last-Event-ID` / sequence 去重；完成后拉权威详情 | §8.5 | 完成 |
| T-4-09 | 记录模型、Prompt、工具版本、耗时、用量 | FR-11 | 完成 |
| T-4-10 | 步数 / 工具数 / 运行时间 / 费用软上限 | NFR-COST | 完成 |
| T-4-11 | Flutter：对话页流式渲染、确认弹窗、布局候选、版本比较 | §4.2 | 完成 |
| T-4-12 | Prompt Injection 隔离基线（用户上传内容与系统指令分离） | NFR-SEC-09 | 完成 |

**退出标准：** 确认后可对话生成 2～3 方向；可存版本并回退；SSE 断线可恢复；工具越权被拒。

---

## 5 — L0 效果图 + 成本守卫（FR-14）

| ID | 任务 | 关联 | 状态 |
| --- | --- | --- | --- |
| T-5-01 | `create_render_task`：必须用户批准 | FR-14 / OOS-07 | 完成 |
| T-5-02 | ARQ：图像生成 Worker（Mock 出占位图可先） | L0 | 完成 |
| T-5-03 | 结果入库 + 签名下载；UI 标明「效果图」 | §9.4 | 完成 |
| T-5-04 | 用户/项目/日预算硬上限；超限拒绝 | NFR-COST | 完成 |
| T-5-05 | 任务取消、超时、幂等、有限重试 | §12.4 | 完成 |
| T-5-06 | 用量审计与结果回放 | FR-11 | 完成 |
| T-5-07 | Flutter：批准 → 进度 → 结果画廊 | FR-14 | 完成 |

**退出标准：** 未批准不能出图；预算可挡；失败可重试/取消；效果图可展示。

---

## 5B — VR 全景（FR-15）

> 可与阶段 5 **并行**准备查看器；端到端验收需能降级到 L0。

| ID | 任务 | 关联 | 状态 |
| --- | --- | --- | --- |
| T-5B-01 | 全景媒体约定：等距柱状 JPEG、房间索引、版权可追溯 | §9.3 | 完成 |
| T-5B-02 | `scene_build` Worker：已确认布局 → 各房间全景 JPEG | FR-15 | 完成 |
| T-5B-03 | 写出不可变 `asset_manifest`（房间、全景 URL/哈希、初始朝向、降级效果图） | D-VR-03 | 完成 |
| T-5B-04 | 场景 API：scene-tasks、manifest、confirm（无 `/3d-assets`） | §8.3 | 完成 |
| T-5B-05 | Flutter WebView 宿主 + `webview-vr` Three.js 球面查看器 | D-VR-02 | 完成 |
| T-5B-06 | Bridge：`scene.load` / `loaded` / `progress` / `room.switch` / `error` / `dispose` | §9.2 | 完成 |
| T-5B-07 | 拖拽环视；房间切换；加载失败降级到效果图 | §9.4 | 完成 |
| T-5B-08 | 归属校验：WebView 回报的 URL/ID 服务端再验 | §5.2 | 完成 |
| T-5B-09 | 场景版本确认与回退 | SceneVersion | 完成 |
| T-5B-10 | 性能记录：全景大小、首屏、内存、帧率（日志即可） | §9.4 | 完成 |
| T-5B-11 | UI 文案：VR 全景查看；非 BIM / 非可编辑网格 | OOS-05 | 完成 |

**退出标准：** 确认布局后可出全景场景；手机可拖拽环视与切换房间；失败回效果图；无编辑入口。

---

## 6* — 本地质量（不上线，已确认不做）

| ID | 任务 | 说明 | 状态 |
| --- | --- | --- | --- |
| T-6-01 | API 合同测试补全 | 对照 OpenAPI | 不做 |
| T-6-02 | 越权 / 上传恶意文件 / 注入回归 | 安全基线 | 不做 |
| T-6-03 | Agent 黄金集（清晰图/模糊图/冲突需求/预算不足） | 评估 | 不做 |
| T-6-04 | 本地日志与简单用量看板（可选） | 非生产监控 | 不做 |
| T-6-05 | 数据导出/删除流程自测 | NFR-SEC-11 | 不做 |

**明确不做（本清单范围外）：** 灰度、CDN、托管上线、K8s、Unity、多 Agent、BIM、GLB 模板拼装。

---

## 跨阶段并行建议

| 可并行 | 说明 |
| --- | --- |
| 1B OpenAPI ↔ Compose 骨架 | 契约与环境可同时推进 |
| T-5B-01 全景约定 ↔ 阶段 3～4 | 媒体规范不阻塞 Agent |
| Flutter 页面壳 ↔ 后端 API | 先用 Mock/假数据联 UI |
| SSE 与短轮询保底 | 先轮询打通任务，再换 SSE |

---

## 阻塞与依赖（产品侧，不挡骨架）

| 项 | 影响任务 | 临时策略 |
| --- | --- | --- |
| 图片是否允许出域 | T-3-03、T-5-02 真模型 | `USE_MOCK_AI=1` |
| 具体模型供应商 | T-1B-09 | Mock 至 1B 补全 |
| 目标用户/文案语言 | 文案与默认引导 | 先中文占位 |
| 单项目 AI 预算数值 | T-5-04 | `.env` 给开发默认硬上限 |

---

## 进度跟踪（汇总）

| 阶段 | 任务数 | 完成 | 备注 |
| --- | --- | ---: | --- |
| 1B | 9 | 9 | |
| 2 | 17 | 17 | |
| 3 | 10 | 10 | |
| 4 | 12 | 12 | |
| 5 | 7 | 7 | |
| 5B | 11 | 11 | VR 全景 + WebView 球面加载 |
| 6* | 5 | 0 | 已确认不做（不上线） |
| **合计** | **71** | **66** | 必做项已完成 |

更新任务状态时同步改上表；重大范围变更先改 `REQUIREMENTS.md` 再回写本清单。

---

## 修订记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-19 | v1.0 | 按 REQUIREMENTS v1.2 生成本地开发任务清单 |
| 2026-09-19 | v1.1 | 完成阶段 1B 工程骨架 |
| 2026-09-19 | v1.2 | 客户端主链路接通 API；阶段 2～5 多数完成；5B 仍缺真 GLB/WebView |
| 2026-09-19 | v1.3 | WebView+Three.js 桥接；相机预设与降级；Mock 上传走 API 并清理 EXIF |
| 2026-09-19 | v1.4 | 登录过期回登录页；低置信度不写入已确认；事件支持 Last-Event-ID 续传 |
| 2026-09-19 | v1.4 | 模板 GLB 拼装与下载；场景回退；WebView 加载 GLB；场景 ID 校验与 fps 日志 |
| 2026-09-19 | v1.5 | 阶段 6 确认为不做（不上线） |
| 2026-09-19 | v1.6 | 对齐 REQUIREMENTS v1.3：5B 改为 VR 全景（等距柱状 JPEG）；移除 GLB/`assets-3d` 产品任务表述 |
