import uuid
from datetime import datetime
from decimal import Decimal
from enum import Enum
from sqlalchemy import String, DateTime, ForeignKey, Numeric, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class PaymentMethod(str, Enum):
    CASH = "CASH"
    BLIK = "BLIK"


class PaymentStatus(str, Enum):
    PENDING = "PENDING"
    PAID = "PAID"
    CANCELLED = "CANCELLED"


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    offer_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("offers.id"), nullable=False
    )
    customer_name: Mapped[str] = mapped_column(String(200), nullable=False)
    customer_phone: Mapped[str] = mapped_column(String(20), nullable=False)
    customer_email: Mapped[str] = mapped_column(String(200), nullable=False)
    payment_method: Mapped[str] = mapped_column(String(20), nullable=False)
    payment_status: Mapped[str] = mapped_column(
        String(20), nullable=False, default=PaymentStatus.PENDING.value
    )
    total_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    pickup_point_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("pickup_points.id"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )

    # Relationships
    offer: Mapped["Offer"] = relationship("Offer", back_populates="orders")  # noqa: F821
    pickup_point: Mapped["PickupPoint"] = relationship(  # noqa: F821
        "PickupPoint", back_populates="orders"
    )
    items: Mapped[list["OrderItem"]] = relationship(  # noqa: F821
        "OrderItem", back_populates="order", cascade="all, delete-orphan"
    )
