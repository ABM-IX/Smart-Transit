import os
import time
import logging
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.config import settings

logger = logging.getLogger("smarttransit.db")

Base = declarative_base()

def resolve_db_url(url: str) -> str:
    """Ensures SQLite URLs resolve to the canonical backend database file."""
    if url.startswith("sqlite+aiosqlite:///.") or url.startswith("sqlite+aiosqlite://smarttransit.db"):
        # Anchor to backend directory to ensure consistency regardless of CWD
        backend_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        db_file = os.path.join(backend_dir, "backend", "smarttransit.db")
        if not os.path.exists(os.path.dirname(db_file)):
            db_file = os.path.join(backend_dir, "smarttransit.db")
        # Format for SQLite URL (forward slashes)
        db_file_formatted = db_file.replace("\\", "/")
        return f"sqlite+aiosqlite:///{db_file_formatted}"
    return url

def get_engine_and_session(db_url: str):
    resolved_url = resolve_db_url(db_url)
    is_sqlite = "sqlite" in resolved_url
    connect_args = {"check_same_thread": False} if is_sqlite else {}
    
    engine_kwargs = {
        "echo": False,
        "future": True,
        "connect_args": connect_args,
    }
    
    if not is_sqlite:
        engine_kwargs.update({
            "pool_pre_ping": True,
            "pool_recycle": 300,
            "pool_size": 10,
            "max_overflow": 20,
        })
        
    eng = create_async_engine(resolved_url, **engine_kwargs)
    session_factory = async_sessionmaker(
        bind=eng,
        class_=AsyncSession,
        expire_on_commit=False,
        autocommit=False,
        autoflush=False
    )
    return eng, session_factory

# Primary engine setup
engine, AsyncSessionLocal = get_engine_and_session(settings.DATABASE_URL)

async def get_db():
    """Dependency for injecting async database sessions into FastAPI routes."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def init_db():
    """Creates all database tables on application startup with fallback resilience."""
    global engine, AsyncSessionLocal
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print(f"[DATABASE] Connected successfully using: {settings.DATABASE_URL.split('@')[-1] if '@' in settings.DATABASE_URL else 'local SQLite db'}")
    except Exception as e:
        print(f"[DATABASE WARNING] Primary database connection failed ({e}). Falling back to local SQLite async...")
        fallback_url = resolve_db_url("sqlite+aiosqlite:///./smarttransit.db")
        engine, AsyncSessionLocal = get_engine_and_session(fallback_url)
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print("[DATABASE] Local fallback database initialized successfully.")

async def check_db_health() -> dict:
    """Actively pings the database and returns diagnostics."""
    t0 = time.time()
    try:
        async with AsyncSessionLocal() as session:
            # Check basic query connectivity
            await session.execute(text("SELECT 1"))
            # Fetch record counts for verification
            r_res = await session.execute(text("SELECT count(*) FROM routes"))
            routes_count = r_res.scalar() or 0
            
            s_res = await session.execute(text("SELECT count(*) FROM stops"))
            stops_count = s_res.scalar() or 0

            d_res = await session.execute(text("SELECT count(*) FROM driver_profiles"))
            drivers_count = d_res.scalar() or 0

            latency_ms = round((time.time() - t0) * 1000, 2)
            dialect = engine.dialect.name
            target = settings.DATABASE_URL.split("@")[-1] if "@" in settings.DATABASE_URL else "local_sqlite"

            return {
                "status": "connected",
                "dialect": dialect,
                "target": target,
                "latency_ms": latency_ms,
                "routes_registered": routes_count,
                "stops_registered": stops_count,
                "drivers_registered": drivers_count
            }
    except Exception as ex:
        return {
            "status": "disconnected",
            "error": str(ex),
            "target": settings.DATABASE_URL.split("@")[-1] if "@" in settings.DATABASE_URL else "local_sqlite"
        }


