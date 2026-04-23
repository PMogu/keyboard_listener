from datetime import datetime

from pydantic import BaseModel


class StatsBucket(BaseModel):
    bucket_start: datetime
    count: int


class StatsSummaryResponse(BaseModel):
    start_time: datetime
    end_time: datetime
    bucket: str
    total_events: int
    buckets: list[StatsBucket]


class KeyCodeStatItem(BaseModel):
    key_code: int
    count: int


class KeyCodeStatsResponse(BaseModel):
    start_time: datetime
    end_time: datetime
    total_events: int
    items: list[KeyCodeStatItem]
