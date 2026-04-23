from datetime import datetime

from pydantic import BaseModel, Field


class KeyEventPayload(BaseModel):
    event_id: str = Field(min_length=1, max_length=64)
    occurred_at: datetime
    key_code: int = Field(ge=0, le=65535)
    modifier_flags: int = Field(ge=0, le=4_294_967_295)
    event_type: str = Field(min_length=1, max_length=32)
    source_app: str | None = Field(default=None, max_length=255)


class EventBatchRequest(BaseModel):
    batch_id: str = Field(min_length=1, max_length=64)
    events: list[KeyEventPayload] = Field(default_factory=list, max_length=500)


class EventBatchResponse(BaseModel):
    batch_id: str
    received_count: int
    inserted_count: int
    duplicate_count: int
