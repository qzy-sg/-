"""微信授权会话。本地签发一次性 state，避免重复提交同一轮授权。"""

from __future__ import annotations

import re
import threading
import time

from house_design.errors import AppError
from house_design.security import new_id

_TTL_SECONDS = 120
_lock = threading.Lock()
_states: dict[str, float] = {}
_SUBJECT = re.compile(r"^wxsub_[A-Za-z0-9]{8,40}$")


def issue_state() -> dict:
    now = time.time()
    state = new_id("wxst")
    with _lock:
        expired = [key for key, exp in _states.items() if exp <= now]
        for key in expired:
            _states.pop(key, None)
        _states[state] = now + _TTL_SECONDS
    return {"state": state, "mode": "identity", "expires_in": _TTL_SECONDS}


def consume_state(state: str) -> None:
    now = time.time()
    with _lock:
        exp = _states.pop(state, None)
    if exp is None or exp <= now:
        raise AppError(401, "UNAUTHORIZED", "授权已过期，请重新发起")


def normalize_subject(subject: str) -> str:
    value = subject.strip()
    if not _SUBJECT.match(value):
        raise AppError(422, "VALIDATION_ERROR", "微信身份无效，请重新授权")
    return value
