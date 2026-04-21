from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_device
from app.db.session import get_db
from app.models.device import Device
from app.models.ingestion_batch import IngestionBatch
from app.schemas.event import EventBatchRequest, EventBatchResponse
from app.services.ingestion import ingest_event_batch


router = APIRouter(prefix="/v1/events", tags=["events"])


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
