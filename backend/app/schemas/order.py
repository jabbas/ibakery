from pydantic import BaseModel, ConfigDict, EmailStr
from uuid import UUID
from datetime import datetime, date, time
from decimal import Decimal
from ..models.order import PaymentMethod, PaymentStatus


class OrderItemCreate(BaseModel):
    offer_item_id: UUID
    quantity: int


class OrderItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    offer_item_id: UUID
    quantity: int
    unit_price: Decimal


class OrderBase(BaseModel):
    customer_name: str
    customer_phone: str
    customer_email: EmailStr
    payment_method: PaymentMethod
    notes: str | None = None


class OrderCreate(OrderBase):
    offer_id: UUID
    items: list[OrderItemCreate]


class OrderUpdate(BaseModel):
    payment_status: PaymentStatus | None = None
    notes: str | None = None


class OrderOfferInfo(BaseModel):
    """Minimal offer info for order response."""
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    pickup_date: date
    pickup_time_from: time
    pickup_time_to: time
    is_completed: bool


class OrderResponse(OrderBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    offer_id: UUID
    payment_status: PaymentStatus
    total_price: Decimal
    created_at: datetime
    items: list[OrderItemResponse] = []
    offer: OrderOfferInfo | None = None
