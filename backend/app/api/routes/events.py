from datetime import timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_device
from app.db.session import get_db
from app.models.device import Device
from app.models.ingestion_batch import IngestionBatch
from app.schemas.event import EventBatchRequest, EventBatchResponse, HideRangeRequest, HideRangeResponse
from app.services.ingestion import hide_event_range, ingest_event_batch


router = APIRouter(prefix="/v1/events", tags=["events"])
MAX_HIDE_RANGE = timedelta(hours=24)


@router.post("/batch", response_model=EventBatchResponse)
def ingest_events(
    payload: EventBatchRequest,
    device: Device = Depends(get_current_device),
    db: Session = Depends(get_db),
) -> EventBatchResponse:
    existing_batch = db.scalar(
        select(IngestionBatch).where(IngestionBatch.batch_id == payload.batch_id)
    )
    if existing_batch is not None:
        if existing_batch.device_id != device.id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Batch ID already belongs to another device.",
            )
        return EventBatchResponse(
            batch_id=existing_batch.batch_id,
            received_count=existing_batch.received_count,
            inserted_count=existing_batch.inserted_count,
            duplicate_count=existing_batch.duplicate_count,
        )

    inserted_count, duplicate_count = ingest_event_batch(
        db,
        batch=payload,
        device_id=device.id,
    )
    return EventBatchResponse(
        batch_id=payload.batch_id,
        received_count=len(payload.events),
        inserted_count=inserted_count,
        duplicate_count=duplicate_count,
    )


@router.post("/hide-range", response_model=HideRangeResponse)
def hide_range(
    payload: HideRangeRequest,
    device: Device = Depends(get_current_device),
    db: Session = Depends(get_db),
) -> HideRangeResponse:
    start_time = payload.start_time if payload.start_time.tzinfo is not None else payload.start_time.replace(tzinfo=timezone.utc)
    end_time = payload.end_time if payload.end_time.tzinfo is not None else payload.end_time.replace(tzinfo=timezone.utc)
    duration = end_time - start_time
    if duration <= timedelta(0):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="end_time must be greater than start_time.",
        )
    if duration > MAX_HIDE_RANGE:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Single hide range cannot exceed 24 hours.",
        )

    updated_count = hide_event_range(
        db,
        device_id=device.id,
        start_time=start_time,
        end_time=end_time,
    )
    return HideRangeResponse(
        start_time=start_time,
        end_time=end_time,
        updated_count=updated_count,
    )
