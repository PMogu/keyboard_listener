from fastapi import Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.device import Device
from app.services.security import hash_token


def get_current_device(
    authorization: str = Header(default=""),
    db: Session = Depends(get_db),
) -> Device:
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid bearer token.",
        )

    device = db.scalar(select(Device).where(Device.token_hash == hash_token(token)))
    if device is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Device token not recognized.",
        )
    return device
