import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STORE = ROOT / "tests" / "_file_store"
os.environ["DATA_DIR"] = str(STORE)
os.environ["USE_MOCK_AI"] = "true"
os.environ["USE_MOCK_STORAGE"] = "true"
os.environ["TASK_INLINE"] = "true"
os.environ["SEED_DEMO"] = "true"
os.environ["JWT_SECRET"] = "test-secret-key-at-least-32-bytes!"
os.environ["DEMO_EMAIL"] = "demo@local.test"
os.environ["DEMO_PASSWORD"] = "demo-password"

import pytest


@pytest.fixture()
def client():
    from fastapi.testclient import TestClient

    from house_design.config import get_settings
    from house_design.database import reset_engine

    get_settings.cache_clear()
    reset_engine()
    from api.main import app

    with TestClient(app) as test_client:
        yield test_client
    reset_engine()
    get_settings.cache_clear()
