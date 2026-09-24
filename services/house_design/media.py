"""图片处理：EXIF 清理与本地 Mock 落盘。"""

from __future__ import annotations

from io import BytesIO
from pathlib import Path

from house_design.runtime import repo_root


def strip_exif_bytes(data: bytes, content_type: str | None = None) -> tuple[bytes, bool]:
    """去掉 EXIF（含 GPS）。失败时返回原文并标记未清理。"""
    try:
        from PIL import Image, ImageOps
    except ImportError:
        return data, False
    try:
        image = Image.open(BytesIO(data))
        image = ImageOps.exif_transpose(image)
        fmt = (image.format or _format_from_content_type(content_type) or "JPEG").upper()
        if fmt not in {"JPEG", "JPG", "PNG", "WEBP"}:
            fmt = "JPEG"
        if fmt == "JPG":
            fmt = "JPEG"
        if fmt == "JPEG" and image.mode not in {"RGB", "L"}:
            image = image.convert("RGB")
        out = BytesIO()
        save_kwargs: dict = {}
        if fmt == "JPEG":
            save_kwargs["quality"] = 90
            save_kwargs["optimize"] = True
        image.save(out, format=fmt, **save_kwargs)
        return out.getvalue(), True
    except Exception:
        return data, False


def _format_from_content_type(content_type: str | None) -> str | None:
    if not content_type:
        return None
    mapping = {
        "image/jpeg": "JPEG",
        "image/jpg": "JPEG",
        "image/png": "PNG",
        "image/webp": "WEBP",
    }
    return mapping.get(content_type.lower())


def store_local_asset(object_key: str, data: bytes) -> Path:
    root = repo_root() / ".local-assets"
    path = root / object_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path
