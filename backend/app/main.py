from fastapi import FastAPI

from app.api.routes.devices import router as devices_router
from app.api.routes.events import router as events_router
from app.api.routes.health import router as health_router
from app.api.routes.stats import router as stats_router
from app.core.config import get_settings


settings = get_settings()

app = FastAPI(title=settings.app_name)
app.include_router(health_router)
app.include_router(devices_router)
app.include_router(events_router)
app.include_router(stats_router)
