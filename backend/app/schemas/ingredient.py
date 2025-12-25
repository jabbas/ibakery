from pydantic import BaseModel, ConfigDict, computed_field
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from .unit import UnitResponse


class IngredientBase(BaseModel):
    name: str
    unit_id: UUID
    package_quantity: Decimal = Decimal("1")  # Ilość w opakowaniu (np. 1000g)
    package_price: Decimal = Decimal("0")  # Cena za opakowanie


class IngredientCreate(IngredientBase):
    pass


class IngredientUpdate(BaseModel):
    name: str | None = None
    unit_id: UUID | None = None
    package_quantity: Decimal | None = None
    package_price: Decimal | None = None


class IngredientResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    unit_id: UUID
    package_quantity: Decimal
    package_price: Decimal
    created_at: datetime
    unit: UnitResponse | None = None

    @computed_field
    @property
    def price_per_unit(self) -> Decimal:
        """Cena za 1 jednostkę"""
        if self.package_quantity > 0:
            return self.package_price / self.package_quantity
        return Decimal("0")
