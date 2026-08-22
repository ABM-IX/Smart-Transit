import os
from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore")

    PROJECT_NAME: str = "SmartTransit AI Platform"
    VERSION: str = "2.0.0"
    API_V1_STR: str = "/api"
    DEBUG: bool = True
    
    # Database (Default: local SQLite async, or Supabase PostgreSQL)
    DATABASE_URL: str = "sqlite+aiosqlite:///./smarttransit.db"
    
    # Supabase Cloud Configuration
    SUPABASE_URL: str = "https://xpphmiajwjkcxtxitcex.supabase.co"
    SUPABASE_KEY: str = "sb_publishable_7cqahorS_JAw4601eqpQkA_xPgA3YZL"
    SUPABASE_JWT_SECRET: str = ""
    
    # Server Host & Port
    PORT: int = 8000
    HOST: str = "0.0.0.0"
    
    # CORS
    CORS_ORIGINS: List[str] = ["*"]
    
    # Transit Pricing Constants (Botswana Pula - BWP)
    TAXI_STANDARD_FARE: float = 8.0
    TAXI_SPECIAL_BASE: float = 10.0
    TAXI_SPECIAL_PER_KM: float = 2.5
    TAXI_SPECIAL_PER_MIN: float = 0.5
    BUS_COMBI_FARE: float = 8.0
    
    # Geofencing & Operational Parameters (Meters & Seconds)
    HAIL_MAX_DISTANCE_METERS: float = 60.0
    BOARDING_DISTANCE_METERS: float = 20.0
    BOARDING_CONFIRM_WINDOW_MS: int = 12000

settings = Settings()

