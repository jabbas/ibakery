import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import ForeignKey, Boolean, Numeric, String, DateTime, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from ..database import Base


class ProductSize(Base):
    __tablename__ = "product_sizes"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    product_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)  # np. "Bochenek", "XXL", "Foremka"
    percentage: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False, default=Decimal("100"))  # 100 = bazowy, 150 = 1.5x
    is_default: Mapped[bool] = mapped_column(Boolean, default=False)  # Czy to rozmiar bazowy
    sort_order: Mapped[int] = mapped_column(Integer, default=0)  # Kolejność wyświetlania
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    # Relationships
    product: Mapped["Product"] = relationship("Product", back_populates="sizes")
