from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import get_current_device
from app.db.session import get_db
from app.models.device import Device
from app.schemas.stats import KeyCodeStatsResponse, StatsSummaryResponse
from app.services.stats import get_keycode_stats, get_stats_summary


router = APIRouter(prefix="/v1/stats", tags=["stats"])


@router.get("/summary", response_model=StatsSummaryResponse)
def stats_summary(
    start_time: datetime | None = Query(default=None),
    end_time: datetime | None = Query(default=None),
    bucket: Literal["hour", "day"] = Query(default="hour"),
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
        bucket=bucket,
    )


@router.get("/keycodes", response_model=KeyCodeStatsResponse)
def keycode_stats(
    start_time: datetime | None = Query(default=None),
    end_time: datetime | None = Query(default=None),
    limit: int = Query(default=10, ge=1, le=50),
    device: Device = Depends(get_current_device),
    db: Session = Depends(get_db),
) -> KeyCodeStatsResponse:
    resolved_end = end_time or datetime.now(timezone.utc)
    resolved_start = start_time or (resolved_end - timedelta(hours=1))
    return get_keycode_stats(
        db,
        device_id=device.id,
        start_time=resolved_start,
        end_time=resolved_end,
        limit=limit,
    )
