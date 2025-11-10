"""Application configuration."""
from typing import List, Optional

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings."""

    # Application
    app_name: str = "Zapier Triggers API"
    app_version: str = "1.0.0"
    debug: bool = False

    # API
    api_v1_prefix: str = "/v1"
    cors_origins: List[str] = ["*"]

    # AWS
    aws_region: str = "us-east-1"
    dynamodb_table_name: str = "zapier-triggers-events"
    dynamodb_endpoint_url: Optional[str] = None  # For LocalStack

    # Authentication
    api_key_header: str = "X-API-Key"
    api_keys: List[str] = []  # In production, use Secrets Manager

    # Rate Limiting
    rate_limit_per_minute: int = 100

    # Event Settings
    max_payload_size_kb: int = 256
    default_inbox_limit: int = 50
    max_inbox_limit: int = 100

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


settings = Settings()

