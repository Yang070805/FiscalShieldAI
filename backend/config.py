"""
应用配置 — Pydantic BaseSettings
自动从 .env 文件和环境变量读取配置
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # 应用
    APP_NAME: str = "FiscalShieldAI"
    APP_VERSION: str = "2.0.0"
    DEBUG: bool = True

    # 数据库
    DATABASE_URL: str = "sqlite+aiosqlite:///./fiscal_shield.db"

    # JWT
    SECRET_KEY: str = "fiscal-shield-ai-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_HOURS: int = 72

    # 蓝心大模型
    BLUELM_API_KEY: str = ""

    # 服务器
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "extra": "ignore",
    }


@lru_cache
def get_settings() -> Settings:
    return Settings()
