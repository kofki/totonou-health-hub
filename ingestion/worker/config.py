from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    api_base_url: str = "http://localhost:8080"
    garmin_email: str = ""
    garmin_password: str = ""
    vesync_email: str = ""
    vesync_password: str = ""
    vesync_timezone: str = "America/New_York"


settings = Settings()
