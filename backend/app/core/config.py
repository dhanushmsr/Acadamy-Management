from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    database_url: str = "postgresql://postgres:postgres@localhost:5432/king_saas"
    secret_key: str = "change-this-to-a-long-random-secret"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 60
    refresh_token_expire_days: int = 30

    # WhatsApp Cloud API (Meta) - see backend/README.md for one-time setup
    whatsapp_access_token: str = ""
    whatsapp_phone_number_id: str = ""
    whatsapp_api_version: str = "v23.0"
    whatsapp_template_name: str = "academy_custom_message"

    # SMTP (payment receipt emails) - see backend/README.md for Gmail App Password setup
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_username: str = "inkwake2025@gmail.com"
    smtp_password: str = ""
    # HTTPS Email APIs (Render friendly - port 443)
    resend_api_key: str = ""
    brevo_api_key: str = ""


settings = Settings()
