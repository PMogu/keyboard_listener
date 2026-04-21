from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class DeviceRegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    platform: str = Field(min_length=1, max_length=64)
    app_version: str = Field(min_length=1, max_length=64)
    bootstrap_secret: str = Field(min_length=1)


class DeviceRegisterResponse(BaseModel):
    device_id: UUID
    device_token: str
    created_at: datetime


class DeviceResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    platform: str
    app_version: str
    created_at: datetime
