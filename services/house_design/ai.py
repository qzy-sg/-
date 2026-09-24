from __future__ import annotations

import json
import re
import time
from collections.abc import Iterator
from typing import Protocol

import httpx

from house_design.config import get_settings
from house_design.errors import AppError
from house_design.security import DISCLAIMER


class AIProvider(Protocol):
    name: str

    def chat(self, messages: list[dict]) -> dict: ...

    def chat_stream(self, messages: list[dict]): ...

    def analyze_floor_plan(self, asset_id: str | None) -> dict: ...

    def generate_image(self, prompt: str) -> dict: ...


class MockAIProvider:
    name = "mock"

    def chat(self, messages: list[dict]) -> dict:
        return {
            "text": "这是 Mock 回复。请以已确认的房间事实为准，下面给出可比较的布局方向。",
            "input_tokens": 32,
            "output_tokens": 48,
            "model": "mock-chat",
        }

    def chat_stream(self, messages: list[dict]):
        text = str(self.chat(messages).get("text") or "")
        size = 6
        for i in range(0, len(text), size):
            time.sleep(0.02)
            yield text[i : i + size]

    def analyze_floor_plan(self, asset_id: str | None) -> dict:
        rooms = [
            {"name": "客厅", "area_sqm": 22.0, "confidence": 0.79, "source": "ai"},
            {"name": "主卧", "area_sqm": 14.0, "confidence": 0.78, "source": "ai"},
            {"name": "次卧", "area_sqm": 10.0, "confidence": 0.74, "source": "ai"},
            {"name": "厨房", "area_sqm": 6.5, "confidence": 0.76, "source": "ai"},
            {"name": "卫生间", "area_sqm": 4.5, "confidence": 0.72, "source": "ai"},
            {"name": "阳台", "area_sqm": 4.0, "confidence": 0.7, "source": "ai"},
        ]
        return {
            "rooms": rooms,
            "total_area_sqm": round(sum(item["area_sqm"] for item in rooms), 1),
            "uncertainties": [
                {
                    "field": "承重墙",
                    "reason": "户型图无法判断结构，不能写成已确认事实",
                    "needs_confirmation": True,
                }
            ],
            "asset_id": asset_id,
            "disclaimer": DISCLAIMER,
            "model": "mock-vision",
        }

    def generate_image(self, prompt: str) -> dict:
        return {
            "kind": "render",
            "prompt_excerpt": prompt[:80],
            "url": "mock://renders/preview.png",
            "note": "效果图仅用于视觉表达，不是 VR 全景，也不保证真实尺寸。",
            "model": "mock-image",
        }


class DeepSeekAIProvider:
    name = "deepseek"

    def __init__(self) -> None:
        settings = get_settings()
        if not settings.deepseek_api_key.strip():
            raise AppError(503, "AI_NOT_CONFIGURED", "未配置 DEEPSEEK_API_KEY")
        self._base = settings.deepseek_base_url.rstrip("/")
        self._key = settings.deepseek_api_key.strip()
        self._model = settings.deepseek_model.strip() or "deepseek-flash"

    def chat(self, messages: list[dict]) -> dict:
        payload = {
            "model": self._model,
            "messages": messages,
            "temperature": 0.6,
            "stream": False,
        }
        response = None
        last_error: httpx.HTTPError | None = None
        for _ in range(2):
            try:
                with httpx.Client(timeout=60.0) as client:
                    response = client.post(
                        f"{self._base}/v1/chat/completions",
                        headers={
                            "Authorization": f"Bearer {self._key}",
                            "Content-Type": "application/json",
                        },
                        json=payload,
                    )
                last_error = None
                break
            except httpx.HTTPError as exc:
                last_error = exc
        if last_error is not None or response is None:
            raise AppError(502, "AI_UNAVAILABLE", f"DeepSeek 请求失败：{last_error}") from last_error
        if response.status_code >= 400:
            detail = response.text[:300]
            raise AppError(502, "AI_UNAVAILABLE", f"DeepSeek 返回 {response.status_code}：{detail}")
        body = response.json()
        choice = (body.get("choices") or [{}])[0]
        message = choice.get("message") or {}
        text = str(message.get("content") or "").strip()
        usage = body.get("usage") or {}
        return {
            "text": text or "已收到。这是设计灵感，不构成结构、施工结论。",
            "input_tokens": int(usage.get("prompt_tokens") or 0),
            "output_tokens": int(usage.get("completion_tokens") or 0),
            "model": str(body.get("model") or self._model),
        }


    def chat_stream(self, messages: list[dict]):
        payload = {
            "model": self._model,
            "messages": messages,
            "temperature": 0.6,
            "stream": True,
        }
        try:
            with httpx.Client(timeout=90.0) as client:
                with client.stream(
                    "POST",
                    f"{self._base}/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self._key}",
                        "Content-Type": "application/json",
                        "Accept": "text/event-stream",
                    },
                    json=payload,
                ) as response:
                    if response.status_code >= 400:
                        detail = response.read().decode("utf-8", errors="ignore")[:300]
                        raise AppError(502, "AI_UNAVAILABLE", f"DeepSeek 返回 {response.status_code}：{detail}")
                    for line in response.iter_lines():
                        if not line:
                            continue
                        raw = line.strip()
                        if raw.startswith("data:"):
                            raw = raw[5:].strip()
                        if not raw:
                            continue
                        if raw == "[DONE]":
                            break
                        try:
                            body = json.loads(raw)
                        except json.JSONDecodeError:
                            continue
                        choice = (body.get("choices") or [{}])[0]
                        delta = choice.get("delta") or {}
                        piece = delta.get("content")
                        if piece:
                            yield str(piece)
        except AppError:
            raise
        except httpx.HTTPError as exc:
            raise AppError(502, "AI_UNAVAILABLE", f"DeepSeek 流式请求失败：{exc}") from exc

    def analyze_floor_plan(self, asset_id: str | None) -> dict:
        prompt = (
            "你是房屋设计助手。根据常见商品房户型，给出候选房间识别结果。"
            "只返回 JSON，不要 Markdown。格式："
            '{"rooms":[{"name":"客厅","area_sqm":18.0,"confidence":0.7,"source":"ai"}],'
            '"uncertainties":[{"field":"承重墙","reason":"图面无法判断","needs_confirmation":true}]}。'
            "不得给出承重拆改、消防或施工结论。"
            f" asset_id={asset_id or 'unknown'}"
        )
        chat = self.chat(
            [
                {"role": "system", "content": "只输出合法 JSON。输出仅供设计讨论灵感。"},
                {"role": "user", "content": prompt},
            ]
        )
        parsed = _extract_json(chat["text"])
        rooms = parsed.get("rooms") if isinstance(parsed, dict) else None
        uncertainties = parsed.get("uncertainties") if isinstance(parsed, dict) else None
        if not isinstance(rooms, list) or not rooms:
            rooms = [
                {"name": "客厅", "area_sqm": 18.0, "confidence": 0.55, "source": "ai"},
                {"name": "主卧", "area_sqm": 12.0, "confidence": 0.5, "source": "ai"},
            ]
        if not isinstance(uncertainties, list):
            uncertainties = [
                {
                    "field": "承重墙",
                    "reason": "户型图无法判断结构，不能写成已确认事实",
                    "needs_confirmation": True,
                }
            ]
        return {
            "rooms": rooms,
            "uncertainties": uncertainties,
            "asset_id": asset_id,
            "disclaimer": DISCLAIMER,
            "model": chat.get("model"),
        }

    def generate_image(self, prompt: str) -> dict:
        chat = self.chat(
            [
                {
                    "role": "system",
                    "content": "用一两段中文描述室内效果图氛围。强调仅供视觉灵感，不是施工图。",
                },
                {"role": "user", "content": prompt},
            ]
        )
        return {
            "kind": "render",
            "prompt_excerpt": prompt[:80],
            "url": "deepseek://renders/description",
            "description": chat["text"],
            "note": "当前供应商不直接出图，先返回效果描述。效果图不是 VR 全景，也不保证真实尺寸。",
            "model": chat.get("model"),
        }


def _extract_json(text: str) -> dict:
    raw = text.strip()
    if raw.startswith("```"):
        raw = re.sub(r"^```(?:json)?\s*", "", raw)
        raw = re.sub(r"\s*```$", "", raw)
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except json.JSONDecodeError:
        match = re.search(r"\{.*\}", raw, re.DOTALL)
        if not match:
            return {}
        try:
            data = json.loads(match.group(0))
            return data if isinstance(data, dict) else {}
        except json.JSONDecodeError:
            return {}


def get_provider() -> AIProvider:
    settings = get_settings()
    if settings.use_mock_ai:
        return MockAIProvider()
    return DeepSeekAIProvider()
