from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_device
from app.db.session import get_db
from app.models.device import Device
from app.schemas.stats import StatsSummaryResponse
from app.services.stats import get_stats_summary


router = APIRouter(prefix="/v1/stats", tags=["stats"])


@router.get("/summary", response_model=StatsSummaryResponse)
def stats_summary(
    start_time: datetime | None = Query(default=None),
    end_time: datetime | None = Query(default=None),
    device: Device = Depends(get_current_device),
    db: Session = Depends(get_db),
) -> StatsSummaryResponse:
    resolved_end = end_time or datetime.now(timezone.utc)
    resolved_start = start_time or (resolved_end - timedelta(hours=1))
    return get_stats_summary(
        db,
        device_id=device.id,
        start_time=resolved_start,
        end_time=resolved_end,
    )
