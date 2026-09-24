"""本地模拟短信验证码。不调用短信厂商，开发模式把明文码返回给客户端。"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import secrets
import threading
import time
from pathlib import Path

from house_design.config import get_settings
from house_design.errors import AppError

logger = logging.getLogger(__name__)

_TTL_SECONDS = 300
_RESEND_SECONDS = 60
_MAX_ATTEMPTS = 5
_lock = threading.Lock()


def _digits(phone: str) -> str:
    digits = "".join(ch for ch in phone if ch.isdigit())
    if len(digits) != 11 or not digits.startswith("1"):
        raise AppError(422, "VALIDATION_ERROR", "请输入 11 位手机号")
    return digits


def _path() -> Path:
    root = Path(get_settings().data_dir)
    root.mkdir(parents=True, exist_ok=True)
    return root / "_sms_codes.json"


def _load() -> dict:
    path = _path()
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def _save(data: dict) -> None:
    path = _path()
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    temp.replace(path)


def _digest(phone: str, code: str) -> str:
    secret = get_settings().jwt_secret.encode()
    return hmac.new(secret, f"{phone}:{code}".encode(), hashlib.sha256).hexdigest()


def _live(data: dict, now: float) -> dict:
    return {key: row for key, row in data.items() if float(row.get("expires_at", 0)) > now}


def issue_code(phone: str) -> dict:
    digits = _digits(phone)
    now = time.time()
    code = f"{secrets.randbelow(1_000_000):06d}"
    with _lock:
        data = _live(_load(), now)
        row = data.get(digits)
        if row is not None and float(row.get("sent_at", 0)) + _RESEND_SECONDS > now:
            wait = int(float(row["sent_at"]) + _RESEND_SECONDS - now) + 1
            raise AppError(429, "RATE_LIMITED", f"请 {wait} 秒后再获取验证码")
        data[digits] = {
            "code_hash": _digest(digits, code),
            "sent_at": now,
            "expires_at": now + _TTL_SECONDS,
            "attempts": 0,
        }
        _save(data)
    logger.info("mock sms code phone=%s code=%s", digits, code)
    body = {"sent": True, "expires_in": _TTL_SECONDS, "retry_after": _RESEND_SECONDS}
    if get_settings().use_mock_sms:
        body["dev_code"] = code
    return body


def consume_code(phone: str, code: str) -> None:
    digits = _digits(phone)
    submitted = code.strip()
    if not submitted.isdigit() or len(submitted) != 6:
        raise AppError(401, "UNAUTHORIZED", "验证码不正确")
    now = time.time()
    with _lock:
        data = _live(_load(), now)
        row = data.get(digits)
        if row is None:
            _save(data)
            raise AppError(401, "UNAUTHORIZED", "验证码已过期，请重新获取")
        if int(row.get("attempts", 0)) >= _MAX_ATTEMPTS:
            data.pop(digits, None)
            _save(data)
            raise AppError(401, "UNAUTHORIZED", "验证码已失效，请重新获取")
        if not hmac.compare_digest(str(row["code_hash"]), _digest(digits, submitted)):
            row["attempts"] = int(row.get("attempts", 0)) + 1
            if row["attempts"] >= _MAX_ATTEMPTS:
                data.pop(digits, None)
                _save(data)
                raise AppError(401, "UNAUTHORIZED", "验证码已失效，请重新获取")
            _save(data)
            raise AppError(401, "UNAUTHORIZED", "验证码不正确")
        data.pop(digits, None)
        _save(data)
