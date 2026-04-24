from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.models.ingestion_batch import IngestionBatch
from app.models.key_event import KeyEvent
from app.schemas.event import EventBatchRequest


def ingest_event_batch(
    db: Session,
    *,
    batch: EventBatchRequest,
    device_id: UUID,
) -> tuple[int, int]:
    event_ids = [event.event_id for event in batch.events]
    existing_ids: set[str] = set()
    if event_ids:
        existing_ids = set(
            db.scalars(
                select(KeyEvent.event_id).where(KeyEvent.event_id.in_(event_ids))
            ).all()
        )

    new_rows = [
        KeyEvent(
            event_id=event.event_id,
            device_id=device_id,
            occurred_at=event.occurred_at,
            key_code=event.key_code,
            modifier_flags=event.modifier_flags,
            event_type=event.event_type,
            source_app=event.source_app,
        )
        for event in batch.events
        if event.event_id not in existing_ids
    ]

    for row in new_rows:
        db.add(row)

    inserted_count = len(new_rows)
    duplicate_count = len(batch.events) - inserted_count

    db.add(
        IngestionBatch(
            batch_id=batch.batch_id,
            device_id=device_id,
            received_count=len(batch.events),
            inserted_count=inserted_count,
            duplicate_count=duplicate_count,
        )
    )
    db.commit()
    return inserted_count, duplicate_count


def hide_event_range(
    db: Session,
    *,
    device_id: UUID,
    start_time: datetime,
    end_time: datetime,
) -> int:
    if start_time.tzinfo is None:
        start_time = start_time.replace(tzinfo=timezone.utc)
    if end_time.tzinfo is None:
        end_time = end_time.replace(tzinfo=timezone.utc)

    result = db.execute(
        update(KeyEvent)
        .where(
            KeyEvent.device_id == device_id,
            KeyEvent.occurred_at >= start_time,
            KeyEvent.occurred_at < end_time,
            KeyEvent.key_code != -1,
        )
        .values(key_code=-1)
    )
    db.commit()
    return result.rowcount or 0
