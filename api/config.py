from pydantic_settings import BaseSettings
from pydantic import Field
from dotenv import load_dotenv

# 从.env.local读取环境变量
load_dotenv(dotenv_path=".env.local")

class Settings(BaseSettings):
    AUTH_TOKEN: str = Field(..., env="AUTH_TOKEN")
    USERNAME: str = Field(..., env="USERNAME")
    PASSWORD: str = Field(..., env="PASSWORD")
    CRITICAL_TIME: str = Field("14", env="CRITICAL_TIME")
    FLAG_MORNING_TO_YANYUAN: bool = Field(True, env="FLAG_MORNING_TO_YANYUAN")
    PREV_INTERVAL: int = Field(10, env="PREV_INTERVAL")
    NEXT_INTERVAL: int = Field(60, env="NEXT_INTERVAL")

    class Config:
        env_file = ".env.local"
        env_file_encoding = "utf-8"

settings = Settings()