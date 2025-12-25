from pydantic import BaseModel, ConfigDict
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from .ingredient import IngredientResponse


class ProductIngredientCreate(BaseModel):
    ingredient_id: UUID
    quantity: Decimal


class ProductIngredientResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    ingredient_id: UUID
    quantity: Decimal
    ingredient: IngredientResponse | None = None


# Product Size schemas
class ProductSizeCreate(BaseModel):
    name: str
    percentage: Decimal = Decimal("100")
    is_default: bool = False
    sort_order: int = 0


class ProductSizeResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    percentage: Decimal
    is_default: bool
    sort_order: int
    created_at: datetime


class ProductBase(BaseModel):
    name: str
    description: str | None = None
    image_url: str | None = None
    base_price: Decimal = Decimal("0")
    parent_product_id: UUID | None = None
    base_percentage: Decimal = Decimal("100")


class ProductCreate(ProductBase):
    ingredients: list[ProductIngredientCreate] = []
    sizes: list[ProductSizeCreate] = []


class ProductUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    image_url: str | None = None
    base_price: Decimal | None = None
    parent_product_id: UUID | None = None
    base_percentage: Decimal | None = None
    ingredients: list[ProductIngredientCreate] | None = None
    sizes: list[ProductSizeCreate] | None = None


class ParentProductInfo(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    base_price: Decimal


class ProductResponse(ProductBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    created_at: datetime
    ingredients: list[ProductIngredientResponse] = []
    sizes: list[ProductSizeResponse] = []
    parent_product: ParentProductInfo | None = None
