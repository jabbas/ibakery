import uuid
from datetime import datetime, date, time
from sqlalchemy import String, DateTime, Date, Time, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from ..database import Base


class Offer(Base):
    __tablename__ = "offers"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(300), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    pickup_date: Mapped[date] = mapped_column(Date, nullable=False)
    pickup_time_from: Mapped[time] = mapped_column(Time, nullable=False)
    pickup_time_to: Mapped[time] = mapped_column(Time, nullable=False)
    order_deadline: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    is_recurring: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    recurrence_rule: Mapped[str | None] = mapped_column(String(100), nullable=True)
    parent_offer_id: Mapped[uuid.UUID | None] = mapped_column(
        nullable=True
    )  # For recurring instances
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, nullable=False
    )

    # Relationships
    items: Mapped[list["OfferItem"]] = relationship(  # noqa: F821
        "OfferItem", back_populates="offer", cascade="all, delete-orphan"
    )
    orders: Mapped[list["Order"]] = relationship("Order", back_populates="offer")  # noqa: F821
