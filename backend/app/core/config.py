from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "keyboard-listener-api"
    app_env: str = Field(default="development", alias="APP_ENV")
    database_url: str = Field(
        default="sqlite:///./keyboard_listener.db",
        alias="DATABASE_URL",
    )
    bootstrap_secret: str = Field(
        default="change-me-bootstrap-secret",
        alias="BOOTSTRAP_SECRET",
    )
    api_base_url: str | None = Field(default=None, alias="API_BASE_URL")


@lru_cache
def get_settings() -> Settings:
    return Settings()
