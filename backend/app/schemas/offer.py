from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime, date, time
from decimal import Decimal
from .product import ProductResponse, ProductSizeResponse


class OfferItemCreate(BaseModel):
    product_id: UUID
    product_size_id: UUID | None = None
    price: Decimal
    max_quantity: int | None = None


class OfferItemResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    product_id: UUID | None = None
    product_size_id: UUID | None = None
    price: Decimal
    max_quantity: int | None = None
    available_quantity: int | None = None
    product: ProductResponse | None = None
    product_size: ProductSizeResponse | None = None


class OfferBase(BaseModel):
    title: str
    description: str | None = None
    pickup_date: date
    pickup_time_from: time
    pickup_time_to: time
    order_deadline: datetime
    is_recurring: bool = False
    recurrence_rule: str | None = None


class OfferCreate(OfferBase):
    items: list[OfferItemCreate] = []


class OfferUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    pickup_date: date | None = None
    pickup_time_from: time | None = None
    pickup_time_to: time | None = None
    order_deadline: datetime | None = None
    is_recurring: bool | None = None
    recurrence_rule: str | None = None
    is_active: bool | None = None
    is_completed: bool | None = None
    items: list[OfferItemCreate] | None = None


class OfferResponse(OfferBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    is_active: bool
    is_completed: bool
    parent_offer_id: UUID | None = None
    created_at: datetime
    items: list[OfferItemResponse] = []


class IngredientSummary(BaseModel):
    ingredient_id: UUID
    ingredient_name: str
    unit_abbreviation: str
    total_quantity: Decimal
    price_per_unit: Decimal
    total_cost: Decimal


class OfferSummary(BaseModel):
    offer_id: UUID
    offer_title: str
    total_orders: int
    total_revenue: Decimal
    ingredients: list[IngredientSummary]
    total_ingredient_cost: Decimal
    profit: Decimal
