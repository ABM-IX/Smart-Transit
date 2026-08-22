import logging
from typing import Optional
from app.config import settings

logger = logging.getLogger(__name__)

_supabase_client = None

def get_supabase():
    """Returns initialized Supabase client if configured in settings."""
    global _supabase_client
    if _supabase_client is not None:
        return _supabase_client

    if not settings.SUPABASE_URL or not settings.SUPABASE_KEY:
        logger.debug("Supabase URL or Key not set. Running in local/direct database mode.")
        return None

    try:
        from supabase import create_client, Client
        _supabase_client = create_client(settings.SUPABASE_URL, settings.SUPABASE_KEY)
        logger.info("Supabase client initialized successfully.")
        return _supabase_client
    except Exception as e:
        logger.error(f"Failed to initialize Supabase client: {e}")
        return None
