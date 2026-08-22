import logging
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.config import settings

logger = logging.getLogger("smarttransit.db")

Base = declarative_base()

def get_engine_and_session(db_url: str):
    is_sqlite = "sqlite" in db_url
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
        
    eng = create_async_engine(db_url, **engine_kwargs)
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
        print(f"[DATABASE] Connected successfully using: {settings.DATABASE_URL.split('@')[-1] if '@' in settings.DATABASE_URL else 'local db'}")
    except Exception as e:
        print(f"[DATABASE WARNING] Primary database connection failed ({e}). Falling back to local SQLite async...")
        fallback_url = "sqlite+aiosqlite:///./smarttransit.db"
        engine, AsyncSessionLocal = get_engine_and_session(fallback_url)
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print("[DATABASE] Local fallback database initialized successfully.")

