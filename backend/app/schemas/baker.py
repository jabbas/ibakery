from pydantic import BaseModel, EmailStr
from uuid import UUID
from datetime import datetime


class BakerBase(BaseModel):
    email: EmailStr
    name: str
    phone: str | None = None


class BakerCreate(BakerBase):
    password: str


class BakerResponse(BakerBase):
    id: UUID
    created_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


class TokenData(BaseModel):
    email: str | None = None
