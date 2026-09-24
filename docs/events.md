# 事件约定

事实状态在本地持久化（`domain_events`）。SSE 只是投递。断线后用 `after_sequence` 回放，任务完成后以 `GET /tasks/{task_id}` 为准。

信封字段：`id`、`type`、`task_id`、`sequence`、`created_at`（UTC，`Z` 结尾）、`data`。

事件类型：

- `task.created`
- `phase.started`
- `assistant.delta`
- `tool.started`
- `tool.completed`
- `approval.required`
- `task.progress`
- `task.completed`
- `task.failed`

同一 `stream_id` 内 `sequence` 单调递增。客户端按 sequence 去重。

## AI 顾问流式（`POST /api/v1/ai/consult/stream`）

`Content-Type: text/event-stream`。一次请求内推送：

1. `phase.started` — 开始咨询  
2. `assistant.delta` — `data.text` 为增量片段，`done: false`  
3. `task.completed` — `data.reply` 为完整回复（权威终态）  
4. 失败时 `task.failed`

非流式兼容：`POST /api/v1/ai/consult` 仍返回整包 JSON。
