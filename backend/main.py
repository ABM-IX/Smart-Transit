import socketio
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import settings
from app.database import init_db
from app.sockets.gateway import sio
import app.sockets  # Registers all socket listeners
from app.routers import health_router, transit_router, ai_router, trips_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifecycle manager: initializes database and tables on startup."""
    print("[SERVER] Initializing SmartTransit Database...")
    await init_db()
    print("[SERVER] SmartTransit Engine is live!")
    yield
    print("[SERVER] Shutting down SmartTransit Engine...")

# Create FastAPI instance
fastapi_app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Intelligent Multi-Modal Public Transit & AI Mobility Facilitator Engine for Botswana and Southern Africa.",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS
fastapi_app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register REST Routers
fastapi_app.include_router(health_router)
fastapi_app.include_router(transit_router)
fastapi_app.include_router(ai_router)
fastapi_app.include_router(trips_router)

# Mount static Admin Dispatch Dashboard assets
import os
from fastapi.staticfiles import StaticFiles
assets_dir = os.path.join(os.path.dirname(__file__), "static", "assets")
if os.path.exists(assets_dir):
    fastapi_app.mount("/assets", StaticFiles(directory=assets_dir), name="assets")



# Mount Socket.IO with FastAPI to create a unified ASGI application
app = socketio.ASGIApp(
    socketio_server=sio,
    other_asgi_app=fastapi_app,
    socketio_path="socket.io"
)

if __name__ == "__main__":
    import uvicorn
    import os
    port = int(os.environ.get("PORT", getattr(settings, "PORT", 8000)))
    host = os.environ.get("HOST", getattr(settings, "HOST", "0.0.0.0"))
    uvicorn.run("main:app", host=host, port=port, reload=settings.DEBUG)

