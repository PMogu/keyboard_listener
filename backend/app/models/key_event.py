import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class KeyEvent(Base):
    __tablename__ = "key_events"
    __table_args__ = (UniqueConstraint("event_id", name="uq_key_events_event_id"),)

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    event_id: Mapped[str] = mapped_column(String(64), nullable=False)
    device_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("devices.id"), nullable=False, index=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    key_code: Mapped[int] = mapped_column(Integer, nullable=False)
    modifier_flags: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    event_type: Mapped[str] = mapped_column(String(32), nullable=False)
    source_app: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    device = relationship("Device", back_populates="events")
