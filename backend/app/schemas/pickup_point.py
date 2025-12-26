from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime


class PickupPointBase(BaseModel):
    name: str
    address: str
    description: str | None = None
    is_active: bool = True


class PickupPointCreate(PickupPointBase):
    pass


class PickupPointUpdate(BaseModel):
    name: str | None = None
    address: str | None = None
    description: str | None = None
    is_active: bool | None = None


class PickupPointResponse(PickupPointBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
