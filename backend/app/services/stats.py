from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.key_event import KeyEvent
from app.schemas.stats import StatsBucket, StatsSummaryResponse


def get_stats_summary(
    db: Session,
    *,
    device_id: UUID,
    start_time: datetime,
    end_time: datetime,
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
    if dialect_name == "sqlite":
        minute_expr = func.strftime("%Y-%m-%dT%H:%M:00", KeyEvent.occurred_at)
    else:
        minute_expr = func.to_char(
            func.date_trunc("minute", KeyEvent.occurred_at),
            "YYYY-MM-DD\"T\"HH24:MI:00",
        )

    rows = db.execute(
        select(minute_expr.label("minute"), func.count().label("count"))
        .where(
            KeyEvent.device_id == device_id,
            KeyEvent.occurred_at >= start_time,
            KeyEvent.occurred_at <= end_time,
        )
        .group_by("minute")
        .order_by("minute")
    ).all()

    buckets = [
        StatsBucket(
            minute=datetime.fromisoformat(row.minute).replace(tzinfo=timezone.utc),
            count=row.count,
        )
        for row in rows
    ]

    return StatsSummaryResponse(
        start_time=start_time,
        end_time=end_time,
        total_events=total,
        buckets=buckets,
    )
