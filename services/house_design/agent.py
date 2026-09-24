"""单主 Agent：状态机 + 工具白名单。模型不能访问 SQL / Shell。"""

from house_design.database import Session, select

from house_design.config import get_settings
from house_design.errors import AppError
from house_design.models import Project, Room, User
from house_design.security import SYSTEM_PROMPT

STATES = (
    "INTAKE",
    "ANALYZE_INPUT",
    "NEED_CLARIFICATION",
    "PRESENT_ASSUMPTIONS",
    "WAIT_USER_CONFIRMATION",
    "GENERATE_LAYOUT_OPTIONS",
    "PRESENT_DESIGN_DRAFT",
    "WAIT_DESIGN_SELECTION",
    "REVISE_DESIGN",
    "REQUEST_RENDER_APPROVAL",
    "GENERATE_RENDER_TASK",
    "PRESENT_RESULTS",
)

TOOL_SCHEMAS: dict[str, dict] = {
    "get_project_context": {"required": [], "needs_confirmation": False},
    "analyze_floor_plan": {"required": [], "needs_confirmation": False},
    "list_uncertainties": {"required": [], "needs_confirmation": False},
    "validate_design_constraints": {"required": [], "needs_confirmation": False},
    "generate_layout_options": {"required": [], "needs_confirmation": False},
    "save_design_draft": {"required": ["title"], "needs_confirmation": True},
    "create_render_task": {"required": ["design_version_id"], "needs_confirmation": True},
    "get_task_status": {"required": ["task_id"], "needs_confirmation": False},
    "estimate_budget_range": {"required": [], "needs_confirmation": False},
    "delete_project_assets": {"required": ["user_action"], "needs_confirmation": True},
}


def build_model_messages(user_text: str) -> list[dict]:
    """用户文本只进入 user 角色，不能并入系统指令。"""
    return [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": user_text},
    ]


def project_rooms(db: Session, project_id: str) -> list[Room]:
    return list(db.scalars(select(Room).where(Room.project_id == project_id)))


def has_unconfirmed_rooms(rooms: list[Room]) -> bool:
    return any(room.confirmation_status != "confirmed" for room in rooms)


def invoke_tool(db: Session, user: User, project: Project, name: str, args: dict | None = None) -> dict:
    args = args or {}
    spec = TOOL_SCHEMAS.get(name)
    if spec is None:
        raise AppError(403, "TOOL_DENIED", "工具不在白名单")
    if project.user_id != user.id:
        raise AppError(404, "NOT_FOUND", "项目不存在")
    missing = [key for key in spec["required"] if args.get(key) in (None, "")]
    if missing:
        raise AppError(400, "VALIDATION_ERROR", "工具参数不完整", {"missing": missing})
    if spec["needs_confirmation"] and not args.get("confirmed"):
        raise AppError(409, "APPROVAL_REQUIRED", "该操作需要用户确认")
    if name == "delete_project_assets" and args.get("user_action") is not True:
        raise AppError(409, "APPROVAL_REQUIRED", "删除必须来自明确的用户操作")

    rooms = project_rooms(db, project.id)
    if name == "get_project_context":
        return {
            "project_id": project.id,
            "name": project.name,
            "room_count": len(rooms),
            "unconfirmed": has_unconfirmed_rooms(rooms),
        }
    if name == "list_uncertainties":
        return {
            "items": [
                {"room_id": room.id, "name": room.name, "status": room.confirmation_status}
                for room in rooms
                if room.confirmation_status != "confirmed"
            ]
        }
    if name == "validate_design_constraints":
        return {"ok": not has_unconfirmed_rooms(rooms), "room_count": len(rooms)}
    if name == "generate_layout_options":
        if not rooms or has_unconfirmed_rooms(rooms):
            raise AppError(409, "CONFIRMATION_REQUIRED", "户型识别尚未确认，不能生成正式布局")
        return {"options": layout_options()}
    if name == "estimate_budget_range":
        return {"min": 0, "max": 0, "currency": "CNY", "note": "参考区间，不是报价"}
    if name == "get_task_status":
        return {"task_id": args["task_id"], "hint": "以任务详情接口为权威状态"}
    if name in {"save_design_draft", "create_render_task", "delete_project_assets"}:
        return {"accepted": True, "tool": name}
    if name == "analyze_floor_plan":
        return {"delegated": True}
    raise AppError(403, "TOOL_DENIED", "工具不在白名单")


def layout_options() -> list[dict]:
    return [
        {
            "id": "opt_open",
            "title": "通透会客",
            "vibe": "把光线留给客厅，家具轻轻分区",
            "summary": "不动未知承重，用沙发与餐桌划出会客和用餐，空间显得更开敞。",
            "tags": ["通透", "会客", "少隔断"],
            "highlights": ["客厅做视觉中心", "客餐轻微分区", "动线短而顺"],
            "assumptions": ["假设客厅可做会客与用餐分区"],
            "needs_confirmation": True,
        },
        {
            "id": "opt_storage",
            "title": "整墙收纳",
            "vibe": "东西有处可放，家里才显干净",
            "summary": "沿墙做柜体，不改门窗位置，把杂物收进看不见的地方。",
            "tags": ["收纳", "干净", "耐住"],
            "highlights": ["玄关与客厅一体收纳", "卧室柜体顺墙", "台面尽量留空"],
            "assumptions": ["假设墙面可用于柜体"],
            "needs_confirmation": True,
        },
        {
            "id": "opt_quiet",
            "title": "安静睡区",
            "vibe": "热闹留在前场，卧室留给休息",
            "summary": "卧室远离入户热闹动线，灯光偏暖，风格只作氛围参考。",
            "tags": ["安静", "卧室", "柔光"],
            "highlights": ["动静分区更清楚", "主卧少打扰", "夜间光线更柔"],
            "assumptions": ["假设主卧位置已由用户确认"],
            "needs_confirmation": True,
        },
    ]


def next_state(rooms: list[Room], step_count: int) -> str:
    settings = get_settings()
    if step_count >= settings.agent_max_steps:
        return "PRESENT_RESULTS"
    if not rooms:
        return "NEED_CLARIFICATION"
    if has_unconfirmed_rooms(rooms):
        return "WAIT_USER_CONFIRMATION"
    return "PRESENT_DESIGN_DRAFT"
