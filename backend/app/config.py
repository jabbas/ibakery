from pydantic_settings import BaseSettings
from pydantic import computed_field
from functools import lru_cache
import os


class Settings(BaseSettings):
    # Logging
    log_level: str = "INFO"  # DEBUG, INFO, WARNING, ERROR, CRITICAL

    # Database - can be set directly or constructed from PG* vars
    database_url: str | None = None

    @computed_field
    @property
    def db_url(self) -> str:
        if self.database_url:
            return self.database_url
        # Construct from PG* environment variables (CNPG secret)
        pghost = os.getenv("PGHOST", "localhost")
        pgport = os.getenv("PGPORT", "5432")
        pguser = os.getenv("PGUSER", "ibakery")
        pgpassword = os.getenv("PGPASSWORD", "password")
        pgdatabase = os.getenv("PGDATABASE", "ibakery")
        return f"postgresql+asyncpg://{pguser}:{pgpassword}@{pghost}:{pgport}/{pgdatabase}"

    # JWT
    secret_key: str = "your-secret-key-here-change-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60

    # Email
    mail_username: str = ""
    mail_password: str = ""
    mail_from: str = "noreply@ibakery.pl"
    mail_port: int = 587
    mail_server: str = "smtp.example.com"
    mail_starttls: bool = True
    mail_ssl_tls: bool = False

    # SMSAPI
    smsapi_token: str = ""
    smsapi_sender: str = "iBakery"

    # Baker
    baker_phone: str = ""

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    return Settings()
