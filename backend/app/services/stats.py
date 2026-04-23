from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.key_event import KeyEvent
from app.schemas.stats import KeyCodeStatItem, KeyCodeStatsResponse, StatsBucket, StatsSummaryResponse


def get_stats_summary(
    db: Session,
    *,
    device_id: UUID,
    start_time: datetime,
    end_time: datetime,
    bucket: str,
) -> StatsSummaryResponse:
    if start_time.tzinfo is None:
        start_time = start_time.replace(tzinfo=timezone.utc)
    if end_time.tzinfo is None:
        end_time = end_time.replace(tzinfo=timezone.utc)

    total = db.scalar(
        select(func.count())
        .select_from(KeyEvent)
        .where(
            KeyEvent.device_id == device_id,
            KeyEvent.occurred_at >= start_time,
            KeyEvent.occurred_at <= end_time,
        )
    ) or 0

    dialect_name = db.bind.dialect.name if db.bind is not None else ""
    bucket_expr = _bucket_expression(dialect_name=dialect_name, bucket=bucket)

    rows = db.execute(
        select(bucket_expr.label("bucket_start"), func.count().label("count"))
        .where(
            KeyEvent.device_id == device_id,
            KeyEvent.occurred_at >= start_time,
            KeyEvent.occurred_at <= end_time,
        )
        .group_by("bucket_start")
        .order_by("bucket_start")
    ).all()

    buckets = [
        StatsBucket(
            bucket_start=datetime.fromisoformat(row.bucket_start).replace(tzinfo=timezone.utc),
            count=row.count,
        )
        for row in rows
    ]

    return StatsSummaryResponse(
        start_time=start_time,
        end_time=end_time,
        bucket=bucket,
        total_events=total,
        buckets=buckets,
    )


def get_keycode_stats(
    db: Session,
    *,
    device_id: UUID,
    start_time: datetime,
    end_time: datetime,
    limit: int,
) -> KeyCodeStatsResponse:
    if start_time.tzinfo is None:
        start_time = start_time.replace(tzinfo=timezone.utc)
    if end_time.tzinfo is None:
        end_time = end_time.replace(tzinfo=timezone.utc)

    total = db.scalar(
        select(func.count())
        .select_from(KeyEvent)
        .where(
            KeyEvent.device_id == device_id,
            KeyEvent.occurred_at >= start_time,
            KeyEvent.occurred_at <= end_time,
        )
    ) or 0

    rows = db.execute(
        select(KeyEvent.key_code, func.count().label("count"))
        .where(
            KeyEvent.device_id == device_id,
            KeyEvent.occurred_at >= start_time,
            KeyEvent.occurred_at <= end_time,
        )
        .group_by(KeyEvent.key_code)
        .order_by(func.count().desc(), KeyEvent.key_code.asc())
        .limit(limit)
    ).all()

    return KeyCodeStatsResponse(
        start_time=start_time,
        end_time=end_time,
        total_events=total,
        items=[KeyCodeStatItem(key_code=row.key_code, count=row.count) for row in rows],
    )


def _bucket_expression(*, dialect_name: str, bucket: str):
    if dialect_name == "sqlite":
        if bucket == "hour":
            return func.strftime("%Y-%m-%dT%H:00:00", KeyEvent.occurred_at)
        return func.strftime("%Y-%m-%dT00:00:00", KeyEvent.occurred_at)

    if bucket == "hour":
        return func.to_char(
            func.date_trunc("hour", KeyEvent.occurred_at),
            "YYYY-MM-DD\"T\"HH24:00:00",
        )

    return func.to_char(
        func.date_trunc("day", KeyEvent.occurred_at),
        "YYYY-MM-DD\"T\"00:00:00",
    )
