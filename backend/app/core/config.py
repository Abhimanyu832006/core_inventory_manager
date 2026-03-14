from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440
    DATABASE_URL: str = "sqlite+aiosqlite:///./coreinventory.db"
    LOW_STOCK_THRESHOLD: int = 10

    class Config:
        env_file = ".env"

settings = Settings()
