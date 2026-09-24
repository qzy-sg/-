"""业务实体。字段与原先表结构一致，持久化由文件存储负责。"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from house_design.security import utcnow

_MISSING = object()
REGISTRY: dict[str, type] = {}


class Attr:
    def __init__(self, model: type, name: str) -> None:
        self.model = model
        self.name = name

    def __eq__(self, other: object) -> Cmp:  # type: ignore[override]
        return Cmp(self, "==", other)

    def __ne__(self, other: object) -> Cmp:  # type: ignore[override]
        return Cmp(self, "!=", other)

    def __gt__(self, other: object) -> Cmp:
        return Cmp(self, ">", other)

    def __ge__(self, other: object) -> Cmp:
        return Cmp(self, ">=", other)

    def asc(self) -> Order:
        return Order(self, False)

    def desc(self) -> Order:
        return Order(self, True)


class Cmp:
    def __init__(self, attr: Attr, op: str, value: object) -> None:
        self.attr = attr
        self.op = op
        self.value = value


class Order:
    def __init__(self, attr: Attr, descending: bool) -> None:
        self.attr = attr
        self.descending = descending


class Column:
    def __init__(
        self,
        *,
        pk: bool = False,
        default: Any = _MISSING,
        default_factory: Any = _MISSING,
        kind: str = "raw",
    ) -> None:
        self.name = ""
        self.pk = pk
        self.default = default
        self.default_factory = default_factory
        self.kind = kind

    def __set_name__(self, owner: type, name: str) -> None:
        self.name = name
        columns = owner.__dict__.get("__columns__")
        if columns is None or columns is getattr(owner.__bases__[0], "__columns__", None):
            columns = dict(getattr(owner, "__columns__", {}))
            owner.__columns__ = columns
        columns[name] = self
        if self.pk:
            owner.__pk__ = name

    def __get__(self, obj: Any, owner: type | None = None) -> Any:
        if obj is None:
            return Attr(owner, self.name)  # type: ignore[arg-type]
        if self.name not in obj.__dict__:
            obj.__dict__[self.name] = self.make_default()
        return obj.__dict__[self.name]

    def __set__(self, obj: Any, value: Any) -> None:
        obj.__dict__[self.name] = value

    def make_default(self) -> Any:
        if self.default_factory is not _MISSING:
            return self.default_factory()
        if self.default is not _MISSING:
            return self.default
        return None


class Record:
    __tablename__ = ""
    __pk__ = "id"
    __columns__: dict[str, Column] = {}
    __uniques__: tuple[tuple[str, ...], ...] = ()

    def __init_subclass__(cls, **kwargs: Any) -> None:
        super().__init_subclass__(**kwargs)
        if cls.__tablename__:
            REGISTRY[cls.__tablename__] = cls

    def __init__(self, **kwargs: Any) -> None:
        unknown = set(kwargs) - set(self.__columns__)
        if unknown:
            raise TypeError(f"{type(self).__name__} 不认识字段 {sorted(unknown)}")
        for name, column in self.__columns__.items():
            if name in kwargs:
                setattr(self, name, kwargs[name])
            else:
                setattr(self, name, column.make_default())

    def to_dict(self) -> dict[str, Any]:
        data: dict[str, Any] = {}
        for name, column in self.__columns__.items():
            value = getattr(self, name)
            if column.kind == "datetime" and isinstance(value, datetime):
                if value.tzinfo is None:
                    value = value.replace(tzinfo=timezone.utc)
                value = value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
            data[name] = value
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> Record:
        obj = cls.__new__(cls)
        for name, column in cls.__columns__.items():
            value = data.get(name)
            if column.kind == "datetime" and isinstance(value, str):
                value = datetime.fromisoformat(value.replace("Z", "+00:00"))
            obj.__dict__[name] = value
        return obj


class User(Record):
    __tablename__ = "users"
    __uniques__ = (("email",),)

    id = Column(pk=True)
    email = Column()
    password_hash = Column()
    display_name = Column(default="")
    auth_provider = Column(default="password")
    openid = Column(default="")
    city = Column(default="")
    bio = Column(default="")
    avatar_id = Column(default="orb")
    created_at = Column(kind="datetime", default_factory=utcnow)


class Project(Record):
    __tablename__ = "projects"

    id = Column(pk=True)
    user_id = Column()
    name = Column()
    city = Column()
    status = Column(default="active")
    current_design_version_id = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)
    updated_at = Column(kind="datetime", default_factory=utcnow)


class PropertyProfile(Record):
    __tablename__ = "property_profiles"
    __pk__ = "project_id"

    project_id = Column(pk=True)
    house_type = Column()
    area_sqm = Column()
    orientation = Column()
    city = Column()
    budget = Column()
    household_notes = Column()
    updated_at = Column(kind="datetime", default_factory=utcnow)


class Room(Record):
    __tablename__ = "rooms"

    id = Column(pk=True)
    project_id = Column()
    name = Column()
    area_sqm = Column()
    source = Column(default="ai")
    confirmation_status = Column(default="candidate")
    confidence = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class Constraint(Record):
    __tablename__ = "constraints"

    id = Column(pk=True)
    project_id = Column()
    content = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class Asset(Record):
    __tablename__ = "assets"

    id = Column(pk=True)
    project_id = Column()
    user_id = Column()
    kind = Column()
    object_key = Column()
    filename = Column()
    content_type = Column()
    size_bytes = Column(default=0)
    status = Column(default="pending")
    sha256 = Column()
    exif_stripped = Column(default=False)
    created_at = Column(kind="datetime", default_factory=utcnow)


class Conversation(Record):
    __tablename__ = "conversations"

    id = Column(pk=True)
    project_id = Column()
    state = Column(default="INTAKE")
    step_count = Column(default=0)
    draft_json = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)
    updated_at = Column(kind="datetime", default_factory=utcnow)


class Message(Record):
    __tablename__ = "messages"

    id = Column(pk=True)
    conversation_id = Column()
    role = Column()
    content = Column()
    payload = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class DesignVersion(Record):
    __tablename__ = "design_versions"

    id = Column(pk=True)
    project_id = Column()
    parent_id = Column()
    title = Column()
    summary = Column(default="")
    status = Column(default="saved")
    payload = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class DesignArtifact(Record):
    __tablename__ = "design_artifacts"

    id = Column(pk=True)
    version_id = Column()
    artifact_type = Column()
    payload = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class SceneVersion(Record):
    __tablename__ = "scene_versions"

    id = Column(pk=True)
    project_id = Column()
    design_version_id = Column()
    status = Column(default="draft")
    manifest = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class GenerationTask(Record):
    __tablename__ = "generation_tasks"
    __uniques__ = (("project_id", "task_type", "idempotency_key"),)

    id = Column(pk=True)
    project_id = Column()
    user_id = Column()
    task_type = Column()
    status = Column(default="queued")
    idempotency_key = Column()
    progress = Column(default=0)
    input_json = Column()
    result_json = Column()
    error_message = Column()
    cost_units = Column(default=0)
    created_at = Column(kind="datetime", default_factory=utcnow)
    updated_at = Column(kind="datetime", default_factory=utcnow)


class DomainEvent(Record):
    __tablename__ = "domain_events"
    __uniques__ = (("stream_id", "sequence"),)

    id = Column(pk=True)
    stream_id = Column()
    task_id = Column()
    sequence = Column()
    event_type = Column()
    payload = Column(default_factory=dict)
    created_at = Column(kind="datetime", default_factory=utcnow)


class AgentRun(Record):
    __tablename__ = "agent_runs"

    id = Column(pk=True)
    project_id = Column()
    conversation_id = Column()
    provider = Column()
    model = Column()
    prompt_version = Column()
    tool_version = Column()
    input_tokens = Column(default=0)
    output_tokens = Column(default=0)
    latency_ms = Column(default=0)
    status = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class Approval(Record):
    __tablename__ = "approvals"

    id = Column(pk=True)
    project_id = Column()
    user_id = Column()
    action = Column()
    status = Column()
    payload = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class AuditLog(Record):
    __tablename__ = "audit_logs"

    id = Column(pk=True)
    user_id = Column()
    action = Column()
    target_type = Column()
    target_id = Column()
    created_at = Column(kind="datetime", default_factory=utcnow)


class OutboxMessage(Record):
    __tablename__ = "outbox_messages"

    id = Column(pk=True)
    topic = Column()
    payload = Column(default_factory=dict)
    created_at = Column(kind="datetime", default_factory=utcnow)
    published_at = Column(kind="datetime")
