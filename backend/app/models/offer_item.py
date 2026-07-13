import uuid
from decimal import Decimal
from sqlalchemy import ForeignKey, Numeric, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class OfferItem(Base):
    __tablename__ = "offer_items"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    offer_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("offers.id", ondelete="CASCADE"), nullable=False
    )
    product_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("products.id", ondelete="SET NULL"), nullable=True
    )
    product_size_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("product_sizes.id", ondelete="SET NULL"), nullable=True
    )
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    max_quantity: Mapped[int | None] = mapped_column(Integer, nullable=True)
    available_quantity: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Relationships
    offer: Mapped["Offer"] = relationship("Offer", back_populates="items")  # noqa: F821
    product: Mapped["Product | None"] = relationship("Product", back_populates="offer_items")  # noqa: F821
    product_size: Mapped["ProductSize"] = relationship("ProductSize")  # noqa: F821
    order_items: Mapped[list["OrderItem"]] = relationship(  # noqa: F821
        "OrderItem", back_populates="offer_item"
    )
