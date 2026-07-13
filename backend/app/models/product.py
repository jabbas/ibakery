import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, DateTime, Numeric, Text, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class Product(Base):
    __tablename__ = "products"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    base_price: Mapped[Decimal] = mapped_column(
        Numeric(10, 2), nullable=False, default=Decimal("0")
    )
    # Parent product for variants (e.g., "Chleb mały" based on "Chleb")
    parent_product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    # Percentage of parent's ingredients to use (e.g., 50 = half size)
    base_percentage: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False, default=Decimal("100")
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )

    # Relationships
    ingredients: Mapped[list["ProductIngredient"]] = relationship(  # noqa: F821
        "ProductIngredient", back_populates="product", cascade="all, delete-orphan"
    )
    sizes: Mapped[list["ProductSize"]] = relationship(  # noqa: F821
        "ProductSize", back_populates="product", cascade="all, delete-orphan",
        order_by="ProductSize.sort_order"
    )
    offer_items: Mapped[list["OfferItem"]] = relationship(  # noqa: F821
        "OfferItem", back_populates="product"
    )
    parent_product: Mapped["Product | None"] = relationship(
        "Product", remote_side=[id], foreign_keys=[parent_product_id]
    )
