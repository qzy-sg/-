# AI 房屋设计助手 — 开发计划

> **版本：** v1.1  
> **日期：** 2026-09-19  
> **依据：** [`REQUIREMENTS.md`](./REQUIREMENTS.md) v1.3  
> **状态：** 可据此创建工程（本地技术栈已锁定）  
> **目标：** 交付可在 Android（优先）联调的 MVP 闭环：  
> 登录 → 项目 → 户型分析确认 → Agent 设计版本 → L0 效果图 → VR 全景

---

## 1. 计划摘要

### 1.1 已锁定技术栈（不再选型）

| 层 | 选型 |
| --- | --- |
| 客户端 | Flutter · Riverpod · go_router · Dio |
| API / Agent | FastAPI · 单主 Agent + 工具白名单 · 状态机 |
| 任务 | Redis + ARQ Worker |
| 数据库 | MySQL 8.x |
| 对象存储 | MinIO（S3 兼容） |
| 实时 | REST + SSE（终态以详情接口为准） |
| AI | Provider 抽象 + `USE_MOCK_AI`；对话 / 视觉 / 效果图分配置 |
| 视觉与场景 | L0 效果图 + VR 全景（WebView + Three.js 球面 + 等距柱状 JPEG） |
| 本地运行 | Docker Compose / 本机进程 |

**明确不做：** P5/P6、可编辑网格、GLB/glTF 模板拼装、Unity/Godot、BIM、首期独立 GPU、GraphQL、K8s、多 Agent。

### 1.2 里程碑总览

| 里程碑 | 阶段 | 建议工期 | 可演示结果 |
| --- | ---: | ---: | --- |
| M0 | 1B 工程基线 | 3～5 天 | Compose 起得来；OpenAPI 空壳；Flutter 能打到 API |
| M1 | 阶段 2 基础业务 | 1～1.5 周 | 登录、项目、资料、上传/删除 |
| M2 | 阶段 3 户型分析 | 1 周 | 异步分析 + 置信度 + 用户确认 |
| M3 | 阶段 4 Agent 设计 | 1.5～2 周 | 对话、SSE、2～3 方案、版本比较回退 |
| M4 | 阶段 5 L0 效果图 | 1 周 | 确认后出图、预算守卫、幂等 |
| M5 | 阶段 5B VR 全景 | 1.5～2 周 | 等距柱状 JPEG、WebView 环视、房间切换、失败降级 |
| M6 | 阶段 6 硬化 | 1 周 | 安全回归、监控、本地验收包；上线另议 |

**合计（单人全职粗估）：约 8～11 周。** 可用 `USE_MOCK_AI` 并行前端与合同测试，不阻塞骨架。

```text
1B ──► 2 ──► 3 ──► 4 ──► 5 ──► 5B ──► 6(本地)
              │         │
              └─ mock AI ┘     5 与 5B 可部分并行（5B 降级依赖 L0 结果页）
```

---

## 2. 仓库与目录结构

首期采用 **单仓 monorepo**（与 P1「同仓分进程」一致）：

```text
zui/
├─ REQUIREMENTS.md
├─ DEVELOPMENT-PLAN.md          # 本文档
├─ contracts/                   # OpenAPI、事件 Schema、工具 Schema
│  ├─ openapi.yaml
│  ├─ events.schema.json
│  └─ agent-tools/
├─ mobile/                      # Flutter
├─ api/                         # FastAPI（鉴权、业务、任务提交、SSE）
├─ worker/                      # ARQ（分析 / 效果图 / scene_build / 清理）
│  # 也可与 api 同包、不同入口进程；目录可合并为 services/backend
├─ webview-vr/                  # Three.js VR 全景查看器静态页（供 Flutter WebView 加载）
├─ infra/
│  ├─ docker-compose.yml        # mysql + redis + minio + api + worker
│  └─ .env.example
├─ tests/                       # 合同 / 越权 / Agent 回归夹具
└─ docs/                        # 运行手册、Prompt 版本说明（按需）
```

**注意：** 无 `assets-3d` 模板目录；场景媒体为对象存储中的等距柱状 JPEG，由 manifest 引用。

### 2.1 进程拓扑（本地）

```text
Flutter (Android 优先)
    │ HTTPS/JSON + SSE
    ▼
api (FastAPI)
    ├─ MySQL 8
    ├─ Redis（队列 + 可选缓存）
    ├─ MinIO（预签名上下传）
    └─ enqueue → worker (ARQ)
                      ├─ analyze_floor_plan
                      ├─ create_render (L0)
                      ├─ scene_build (VR 全景)
                      └─ asset_cleanup
```

---

## 3. 阶段计划（工作包）

### 阶段 1B — 工程基线与契约（M0）

**目标：** 锁定依赖版本与 OpenAPI，使后续阶段有合同可测。

| 工作包 | 内容 | 产出 |
| --- | --- | --- |
| WP-1B-01 | 初始化 Flutter / FastAPI / Compose | 可 `compose up` 的空服务 |
| WP-1B-02 | MySQL 迁移骨架（Alembic 或等价）+ utf8mb4 / 时区约定 | 空库可迁移 |
| WP-1B-03 | 起草 `contracts/openapi.yaml`（§8 全部路径 stub） | 契约 v0 |
| WP-1B-04 | 统一错误体、`request_id`、分页/ID/时间约定 | 中间件 + 文档 |
| WP-1B-05 | AI Provider 接口 + `USE_MOCK_AI=true` 默认 | mock 可切换 |
| WP-1B-06 | 记录依赖版本表（Flutter/Dart、Python、MySQL、Redis、MinIO） | `docs/versions.md` 或 README |

**验收：**

- [ ] `docker compose up` 后 health 正常  
- [ ] Flutter 能请求 `/health` 或等价  
- [ ] OpenAPI 可导入生成 Dart 客户端（或手写 Dio 对齐契约）  
- [ ] 未引入 GraphQL / K8s / 第二后端语言  

**退出条件：** 契约冻结到「可改字段、不可乱改路径语义」；进入阶段 2。

---

### 阶段 2 — 基础业务闭环（M1）

**目标：** FR-01～04、FR-12 的基础部分；无 AI 也能完成项目与文件闭环。

| 工作包 | 内容 | 对应 FR |
| --- | --- | --- |
| WP-2-01 | 认证登录、Token 安全存储、过期处理 | FR-01 |
| WP-2-02 | Project CRUD / 归档 / 删除 | FR-02, FR-12 |
| WP-2-03 | PropertyProfile / Room / Constraint 表单与 API | FR-03 |
| WP-2-04 | 预签名上传 → complete → 预览 → 删除；EXIF 清理任务 | FR-04, NFR-SEC |
| WP-2-05 | 用户→项目→文件归属中间件 | NFR-SEC-02 |
| WP-2-06 | Flutter：登录 → 列表 → 详情 → 资料 → 上传页状态机 | — |
| WP-2-07 | API 合同测试 + 越权冒烟 | NFR-QA |

**实体优先落地：** `User`、`Project`、`PropertyProfile`、`Room`、`Constraint`、`Asset`、`AuditLog`（基础）。

**验收：** 对齐 `REQUIREMENTS.md` §12.1 全部勾选。

**风险：** MinIO 签名 URL 与 Android 模拟器网络；预留 host 映射说明。

---

### 阶段 3 — 户型分析与确认（M2）

**目标：** FR-05～07；分析必须异步，且不得跳过确认。

| 工作包 | 内容 |
| --- | --- |
| WP-3-01 | `GenerationTask` 状态机：queued/running/succeeded/failed + 幂等键 |
| WP-3-02 | `POST .../analysis-tasks` + Worker `analyze_floor_plan`（mock 先通） |
| WP-3-03 | 结构化结果：房间候选、置信度、不确定项 |
| WP-3-04 | 用户确认/修正 API → 写入已确认房屋数据 |
| WP-3-05 | 任务 SSE / events + 失败重试 |
| WP-3-06 | Flutter 分析确认页；展示「非施工结论」提示（FR-13 起步） |
| WP-3-07 | 硬规则测试：未确认不得进入设计写入 |

**验收：** §12.2 全部勾选；mock 与真实 Provider 切换不改 API。

---

### 阶段 4 — Agent 与设计版本（M3）

**目标：** FR-08～11、FR-13；主业务「可解释可迭代」。

| 工作包 | 内容 |
| --- | --- |
| WP-4-01 | Agent 状态机持久化（§7.2） |
| WP-4-02 | 工具白名单 + JSON Schema + 服务端二次校验 |
| WP-4-03 | 对话 API + SSE：`assistant.delta` / `tool.*` / `approval.required` |
| WP-4-04 | `generate_layout_options` → 2～3 方向；`save_design_draft` 需确认 |
| WP-4-05 | `DesignVersion` / `DesignArtifact`：比较、选择、回退 |
| WP-4-06 | `AgentRun` 用量与 Prompt/工具版本记录 |
| WP-4-07 | 步数 / 超时 / 费用软上限（可先本地配置） |
| WP-4-08 | Flutter：对话、候选卡、版本比较、断线恢复与 sequence 去重 |
| WP-4-09 | Prompt Injection 隔离冒烟 + 专业边界文案常驻 |

**工具落地顺序建议：**

1. `get_project_context` → `list_uncertainties`  
2. `analyze_floor_plan`（复用阶段 3）→ `validate_design_constraints`  
3. `generate_layout_options` → `save_design_draft`（确认）  
4. `get_task_status` →（阶段 5）`create_render_task`  
5. `estimate_budget_range`（可 mock）→ `delete_project_assets`（明确用户操作）

**验收：** §12.3 全部勾选。

---

### 阶段 5 — L0 效果图与成本守卫（M4）

**目标：** FR-14；高成本路径必须审批。

| 工作包 | 内容 |
| --- | --- |
| WP-5-01 | `create_render_task` 审批流 + 用户确认门闩 |
| WP-5-02 | Worker 图像生成（mock 静态图 → 真实 Provider） |
| WP-5-03 | 用户/项目/日预算守卫与用量记账 |
| WP-5-04 | 取消 / 超时 / 有限重试 / 死信标记 |
| WP-5-05 | 结果页：展示效果图 + 免责声明；**禁止**标成可编辑网格或「3D 模型」 |
| WP-5-06 | 结果可回放与重新下载签名 URL |

**验收：** §12.4 中 L0 相关项；NFR-COST 基础项可测。

---

### 阶段 5B — VR 全景（M5，MVP 必须）

**目标：** FR-15；与阶段 5 可部分并行，但降级路径依赖 L0 结果页。

| 工作包 | 内容 |
| --- | --- |
| WP-5B-01 | 全景媒体约定：等距柱状 JPEG、房间索引、许可证元数据 |
| WP-5B-02 | Worker `scene_build`：已确认布局 → 各房间全景 JPEG + manifest |
| WP-5B-03 | `SceneVersion` + 不可变 manifest（房间、全景 URL/哈希、初始朝向、降级效果图） |
| WP-5B-04 | 场景 API（§8.3：scene-tasks / manifest / confirm）+ 任务 events；**无** `/3d-assets` |
| WP-5B-05 | `webview-vr` Three.js 球面查看器 + Bridge 事件（§9.2） |
| WP-5B-06 | Flutter WebView 页：加载进度、拖拽环视、房间切换 |
| WP-5B-07 | 失败 / 低端设备降级到效果图 |
| WP-5B-08 | 归属校验；禁止信任 WebView 回传 URL/资产 ID 而不校验 |
| WP-5B-09 | 性能日志：全景大小、首屏、内存、帧率（可先 Android 一台） |

**验收：** §12.4 中 5B 全部勾选；无自由编辑、无 BIM 文案、无 GLB 模板拼装。

---

### 阶段 6 — 硬化与本地验收包（M6）

**目标：** 本地 MVP「可交接」；云上线可另立子计划。

| 工作包 | 内容 | 优先级 |
| --- | --- | --- |
| WP-6-01 | Agent 回归集（清晰/模糊户型、冲突需求、预算不足、专业边界） | P0 |
| WP-6-02 | 越权、恶意文件、删除链路、Prompt Injection | P0 |
| WP-6-03 | 关键页专业边界提示巡检（FR-13） | P0 |
| WP-6-04 | 日志脱敏、备份/恢复演练（本地 MySQL + MinIO） | P1 |
| WP-6-05 | 基础监控：任务失败率、队列堆积、费用计数告警（本地可打日志） | P1 |
| WP-6-06 | 上线托管 / HTTPS / 生产费用硬暂停 | P2（待产品确认后） |

**验收：** §12.5 中本地可完成项；上线项标为「待阶段 0 余项」。

---

## 4. 建议排期（单人参考）

| 周 | 焦点 | 里程碑 |
| ---: | --- | --- |
| W1 | 1B + 阶段 2 启动（认证/项目） | M0 → M1 进行中 |
| W2 | 阶段 2 上传与合同测试收尾 | **M1** |
| W3 | 阶段 3 分析与确认 | **M2** |
| W4–W5 | 阶段 4 Agent + SSE + 版本 | **M3** |
| W6 | 阶段 5 L0 + 预算守卫 | **M4** |
| W7–W8 | 阶段 5B 全景 + WebView | **M5** |
| W9 | 阶段 6 回归与文档 | **M6** |

双人时建议：**A = API/Worker/Agent，B = Flutter/WebView**；契约与 mock 为集成面。

---

## 5. 每阶段「完成定义」（DoD）

任一阶段合并/演示前须满足：

1. 对应用例在 Android（优先）可走通主路径；  
2. OpenAPI / 事件契约已更新且合同测试通过；  
3. 归属校验与确认门闩未被绕过；  
4. 失败可重试或有明确错误态；  
5. 日志无 Token / 无完整原图；  
6. `REQUIREMENTS.md` 对应 §12 勾选更新。

---

## 6. 风险与缓解

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 真实模型费用与出域策略未确认 | 联调受阻 | 全程可 `USE_MOCK_AI`；出域前不接真实视觉 |
| WebView 内存 / 机型差异 | VR 体验差 | 先合理分辨率全景；强制降级到 L0 |
| 户型识别不准 | 用户不信任 | 强制不确定项确认；文案区分事实/假设 |
| 任务与 SSE 状态不一致 | 卡死/重复 | sequence 去重 + 终态拉详情；outbox |
| 范围蔓延到可编辑网格 / Unity | 工期爆炸 | 严格 OOS-05；变更需改需求文档版本 |
| MinIO/模拟器网络 | 上传失败 | 文档化 endpoint；提供局域网调试配置 |

---

## 7. 待产品确认（不阻塞骨架，阻塞真实 AI/上线）

来自 `REQUIREMENTS.md` §13，开发中按 mock 推进：

- [ ] 目标用户画像  
- [ ] 市场与语言  
- [ ] MVP 期望上线时间  
- [ ] 单项目 AI 预算上限（数值）  
- [ ] 房屋图片 / 全景是否允许出域及区域  
- [ ] 生产托管与域名（阶段 6 P2）

确认后回填需求文档修订记录，并更新本计划「真实 Provider 接入」子任务。

---

## 8. 立即执行的下一步（本周）

1. 创建 monorepo 目录与 `docker-compose.yml`（mysql / redis / minio / api / worker）。  
2. 冻结依赖版本表 + `contracts/openapi.yaml` stub。  
3. Flutter 工程：Riverpod + go_router + Dio + 登录占位页。  
4. FastAPI：health、统一错误、`request_id`、JWT 登录 stub。  
5. 打开 `USE_MOCK_AI=true`，合并第一份「绿」的合同测试。

完成以上五项即视为 **M0 达成**，进入阶段 2。

---

## 9. 修订记录

| 日期 | 版本 | 说明 |
| --- | --- | --- |
| 2026-09-19 | v1.0 | 依据 REQUIREMENTS.md v1.2 生成开发计划；对齐 P1 与 L0+L1 MVP |
| 2026-09-19 | v1.1 | 对齐 REQUIREMENTS v1.3：5B 改为 VR 全景；目录 `webview-vr/`；移除 `assets-3d` 与 GLB 模板拼装 |
