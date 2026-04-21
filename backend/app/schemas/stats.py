from datetime import datetime

from pydantic import BaseModel


class StatsBucket(BaseModel):
    minute: datetime
    count: int


class StatsSummaryResponse(BaseModel):
    start_time: datetime
    end_time: datetime
    total_events: int
    buckets: list[StatsBucket]
