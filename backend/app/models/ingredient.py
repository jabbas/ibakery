import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, DateTime, ForeignKey, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class Ingredient(Base):
    __tablename__ = "ingredients"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    unit_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("units.id"), nullable=False)
    package_quantity: Mapped[Decimal] = mapped_column(
        Numeric(10, 4), nullable=False, default=Decimal("1")
    )  # Ilość w opakowaniu (np. 1000g mąki, 100g drożdży)
    package_price: Mapped[Decimal] = mapped_column(
        Numeric(10, 2), nullable=False, default=Decimal("0")
    )  # Cena za opakowanie
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )

    @property
    def price_per_unit(self) -> Decimal:
        """Cena za 1 jednostkę (np. za 1 gram)"""
        if self.package_quantity > 0:
            return self.package_price / self.package_quantity
        return Decimal("0")

    # Relationships
    unit: Mapped["Unit"] = relationship("Unit", back_populates="ingredients")
    product_ingredients: Mapped[list["ProductIngredient"]] = relationship(
        "ProductIngredient", back_populates="ingredient"
    )
