from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "house-design-api"
    api_prefix: str = "/api/v1"
    # 业务数据落在本地 JSON 文件，不使用 MySQL / SQLite。
    data_dir: str = "data/store"
    redis_url: str = "redis://127.0.0.1:6379/0"
    jwt_secret: str = "dev-only-not-for-production-key!!"
    jwt_expire_minutes: int = 60 * 24
    use_mock_ai: bool = True
    use_mock_storage: bool = True
    # 本地模拟验证码。为 true 时签发接口返回 dev_code，不调用短信厂商。
    use_mock_sms: bool = True
    task_inline: bool = True
    seed_demo: bool = True
    deepseek_base_url: str = "https://api.deepseek.com"
    deepseek_api_key: str = ""
    deepseek_model: str = "deepseek-flash"
    demo_email: str = "demo@local.test"
    demo_password: str = "demo-password"
    s3_endpoint: str = "http://127.0.0.1:9000"
    s3_access_key: str = "minio"
    s3_secret_key: str = "minio12345"
    s3_bucket: str = "house-design"
    s3_region: str = "us-east-1"
    signed_url_seconds: int = 300
    panorama_url_seconds: int = 60 * 60 * 2
    file_max_bytes: int = 10 * 1024 * 1024
    budget_user_daily: int = 100
    budget_project: int = 50
    budget_task: int = 10
    render_cost_units: int = 5
    agent_max_steps: int = 8
    prompt_version: str = "prompt_v0"
    tool_version: str = "tools_v0"


@lru_cache
def get_settings() -> Settings:
    return Settings()
