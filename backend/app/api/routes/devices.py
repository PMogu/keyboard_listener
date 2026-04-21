from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.db.session import get_db
from app.models.device import Device
from app.schemas.device import DeviceRegisterRequest, DeviceRegisterResponse
from app.services.security import generate_device_token, hash_token


router = APIRouter(prefix="/v1/devices", tags=["devices"])


@router.post("/register", response_model=DeviceRegisterResponse, status_code=status.HTTP_201_CREATED)
def register_device(
    payload: DeviceRegisterRequest,
    db: Session = Depends(get_db),
) -> DeviceRegisterResponse:
    settings = get_settings()
    if payload.bootstrap_secret != settings.bootstrap_secret:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Bootstrap secret is invalid.",
        )

    token = generate_device_token()
    device = Device(
        name=payload.name,
        platform=payload.platform,
        app_version=payload.app_version,
        token_hash=hash_token(token),
    )
    db.add(device)
    db.commit()
    db.refresh(device)

    return DeviceRegisterResponse(
        device_id=device.id,
        device_token=token,
        created_at=device.created_at,
    )
