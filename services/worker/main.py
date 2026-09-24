import asyncio

from arq.connections import RedisSettings

from house_design.config import get_settings
from house_design.runtime import SYNC_JOBS


async def analyze_floor_plan(ctx, task_id: str):
    await asyncio.to_thread(SYNC_JOBS["analyze_floor_plan"], task_id)


async def create_render(ctx, task_id: str):
    await asyncio.to_thread(SYNC_JOBS["create_render"], task_id)


async def scene_build(ctx, task_id: str):
    await asyncio.to_thread(SYNC_JOBS["scene_build"], task_id)


async def asset_cleanup(ctx, task_id: str):
    await asyncio.to_thread(SYNC_JOBS["asset_cleanup"], task_id)


class WorkerSettings:
    functions = [analyze_floor_plan, create_render, scene_build, asset_cleanup]
    redis_settings = RedisSettings.from_dsn(get_settings().redis_url)
    job_timeout = 300
    max_tries = 2
