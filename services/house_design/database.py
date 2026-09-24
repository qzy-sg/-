"""本地 JSON 文件存储。调用方式与原先 Session 对齐：add / get / scalar / commit。"""

from __future__ import annotations

import json
import threading
from collections.abc import Generator, Iterable
from contextlib import contextmanager
from pathlib import Path
from typing import Any

from house_design.config import get_settings
from house_design.errors import AppError
from house_design.models import REGISTRY, Cmp, Order, Record


class Agg:
    def __init__(self, op: str, attr: Any) -> None:
        self.op = op
        self.attr = attr

    @property
    def model(self) -> type:
        return self.attr.model


class Coalesce:
    def __init__(self, inner: Agg, default: Any) -> None:
        self.inner = inner
        self.default = default

    @property
    def model(self) -> type:
        return self.inner.model


class _Func:
    def max(self, attr: Any) -> Agg:
        return Agg("max", attr)

    def sum(self, attr: Any) -> Agg:
        return Agg("sum", attr)

    def coalesce(self, inner: Agg, default: Any) -> Coalesce:
        return Coalesce(inner, default)


func = _Func()


class Query:
    def __init__(self, target: Any) -> None:
        self.target = target
        self.conds: list[Cmp] = []
        self.orders: list[Order] = []

    def where(self, *conds: Cmp) -> Query:
        self.conds.extend(conds)
        return self

    def order_by(self, *orders: Order) -> Query:
        self.orders.extend(orders)
        return self

    @property
    def model(self) -> type[Record]:
        target = self.target
        if isinstance(target, type):
            return target
        return target.model


class Delete:
    def __init__(self, model: type[Record]) -> None:
        self.model = model
        self.conds: list[Cmp] = []

    def where(self, *conds: Cmp) -> Delete:
        self.conds.extend(conds)
        return self


def select(target: Any) -> Query:
    return Query(target)


def delete(model: type[Record]) -> Delete:
    return Delete(model)


def _match(row: Record, cond: Cmp) -> bool:
    left = getattr(row, cond.attr.name)
    right = cond.value
    if cond.op == "==":
        return left == right
    if cond.op == "!=":
        return left != right
    if left is None or right is None:
        return False
    if cond.op == ">":
        return left > right
    if cond.op == ">=":
        return left >= right
    raise AppError(500, "INTERNAL", f"不支持的比较 {cond.op}")


def _sort(rows: list[Record], orders: list[Order]) -> list[Record]:
    result = list(rows)
    for order in reversed(orders):
        result.sort(key=lambda row, order=order: (getattr(row, order.attr.name) is None, getattr(row, order.attr.name)), reverse=order.descending)
    return result


class FileStore:
    def __init__(self) -> None:
        self._lock = threading.RLock()
        self.tables: dict[str, list[Record]] = {}
        self.loaded = False

    def directory(self) -> Path:
        root = Path(get_settings().data_dir)
        root.mkdir(parents=True, exist_ok=True)
        return root

    def load(self) -> None:
        with self._lock:
            import house_design.models  # noqa: F401

            tables: dict[str, list[Record]] = {}
            root = self.directory()
            for name, cls in REGISTRY.items():
                path = root / f"{name}.json"
                rows: list[Record] = []
                if path.exists():
                    raw = json.loads(path.read_text(encoding="utf-8"))
                    rows = [cls.from_dict(item) for item in raw]
                tables[name] = rows
            self.tables = tables
            self.loaded = True

    def save(self) -> None:
        with self._lock:
            root = self.directory()
            for name, rows in self.tables.items():
                path = root / f"{name}.json"
                payload = [row.to_dict() for row in rows]
                temp = path.with_suffix(".tmp")
                temp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
                temp.replace(path)

    def rows(self, model: type[Record]) -> list[Record]:
        if not self.loaded:
            self.load()
        return self.tables.setdefault(model.__tablename__, [])

    def get(self, model: type[Record], key: object) -> Record | None:
        pk = model.__pk__
        for row in self.rows(model):
            if getattr(row, pk) == key:
                return row
        return None

    def add(self, obj: Record) -> None:
        model = type(obj)
        rows = self.rows(model)
        pk_name = model.__pk__
        pk = getattr(obj, pk_name)
        for fields in model.__uniques__:
            for other in rows:
                if getattr(other, pk_name) == pk:
                    continue
                if all(getattr(other, field) == getattr(obj, field) for field in fields):
                    raise AppError(409, "CONFLICT", "记录已存在")
        for index, other in enumerate(rows):
            if getattr(other, pk_name) == pk:
                rows[index] = obj
                return
        rows.append(obj)

    def remove_where(self, model: type[Record], conds: list[Cmp]) -> None:
        rows = self.rows(model)
        self.tables[model.__tablename__] = [row for row in rows if not all(_match(row, cond) for cond in conds)]

    def query(self, query: Query) -> list[Record] | Any:
        rows = [row for row in self.rows(query.model) if all(_match(row, cond) for cond in query.conds)]
        if isinstance(query.target, type):
            return _sort(rows, query.orders)
        return _aggregate(query.target, rows)


def _aggregate(target: Agg | Coalesce, rows: list[Record]) -> Any:
    if isinstance(target, Coalesce):
        value = _aggregate(target.inner, rows)
        return target.default if value is None else value
    values = [getattr(row, target.attr.name) for row in rows]
    values = [value for value in values if value is not None]
    if target.op == "max":
        return max(values) if values else None
    if target.op == "sum":
        return sum(values) if values else None
    raise AppError(500, "INTERNAL", f"不支持的聚合 {target.op}")


_store: FileStore | None = None
_store_lock = threading.Lock()


def get_store() -> FileStore:
    global _store
    with _store_lock:
        if _store is None:
            _store = FileStore()
        return _store


def reset_engine() -> None:
    global _store
    with _store_lock:
        root = Path(get_settings().data_dir)
        if root.exists():
            for path in root.glob("*.json"):
                path.unlink(missing_ok=True)
            for path in root.glob("*.tmp"):
                path.unlink(missing_ok=True)
        _store = None


class Session:
    def add(self, obj: Record) -> None:
        get_store().add(obj)

    def get(self, model: type[Record], key: object) -> Record | None:
        return get_store().get(model, key)

    def scalar(self, query: Query) -> Any:
        result = get_store().query(query)
        if isinstance(query.target, type):
            return result[0] if result else None
        return result

    def scalars(self, query: Query) -> Iterable[Record]:
        result = get_store().query(query)
        return result if isinstance(result, list) else []

    def execute(self, statement: Delete) -> None:
        get_store().remove_where(statement.model, statement.conds)

    def flush(self) -> None:
        return None

    def expire(self, _obj: Record | None = None) -> None:
        return None

    def refresh(self, obj: Record) -> None:
        current = get_store().get(type(obj), getattr(obj, type(obj).__pk__))
        if current is None or current is obj:
            return
        for name in type(obj).__columns__:
            setattr(obj, name, getattr(current, name))

    def commit(self) -> None:
        get_store().save()

    def rollback(self) -> None:
        get_store().load()

    def close(self) -> None:
        return None


def init_db() -> None:
    import house_design.models  # noqa: F401

    get_store().load()


def ping_db() -> None:
    path = get_store().directory() / ".ready"
    path.write_text("ok", encoding="utf-8")
    path.unlink(missing_ok=True)


def get_db() -> Generator[Session, None, None]:
    db = Session()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


@contextmanager
def session_scope() -> Generator[Session, None, None]:
    db = Session()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
