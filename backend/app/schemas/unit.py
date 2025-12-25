from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime


class UnitBase(BaseModel):
    name: str
    abbreviation: str


class UnitCreate(UnitBase):
    pass


class UnitUpdate(BaseModel):
    name: str | None = None
    abbreviation: str | None = None


class UnitResponse(UnitBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
