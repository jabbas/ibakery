import uuid
from decimal import Decimal
from sqlalchemy import ForeignKey, Numeric
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class ProductIngredient(Base):
    __tablename__ = "product_ingredients"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    product_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("products.id", ondelete="CASCADE"), nullable=False
    )
    ingredient_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("ingredients.id"), nullable=False
    )
    quantity: Mapped[Decimal] = mapped_column(Numeric(10, 4), nullable=False)

    # Relationships
    product: Mapped["Product"] = relationship("Product", back_populates="ingredients")
    ingredient: Mapped["Ingredient"] = relationship(
        "Ingredient", back_populates="product_ingredients"
    )
