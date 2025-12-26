from uuid import UUID
from datetime import datetime
from decimal import Decimal
import logging
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from ..database import get_db

logger = logging.getLogger(__name__)
from ..models.offer import Offer
from ..models.offer_item import OfferItem
from ..models.order import Order
from ..models.order_item import OrderItem
from ..models.baker import Baker
from ..schemas.order import OrderCreate, OrderUpdate, OrderResponse
from .auth import get_current_baker

router = APIRouter(prefix="/orders", tags=["orders"])


def _order_query():
    return select(Order).options(
        selectinload(Order.items),
        selectinload(Order.offer),
    )


@router.get("", response_model=list[OrderResponse])
async def get_orders(
    offer_id: UUID | None = None,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Get all orders (baker only). Optionally filter by offer."""
    query = _order_query()
    if offer_id:
        query = query.where(Order.offer_id == offer_id)
    query = query.order_by(Order.created_at.desc())
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(order_id: UUID, db: AsyncSession = Depends(get_db)):
    """Get order by ID (public - for customers to check their order)."""
    result = await db.execute(_order_query().where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order


@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def create_order(
    order_data: OrderCreate,
    db: AsyncSession = Depends(get_db),
):
    """Create a new order (public - for customers)."""
    # Verify offer exists and is still accepting orders
    offer_result = await db.execute(
        select(Offer).where(Offer.id == order_data.offer_id)
    )
    offer = offer_result.scalar_one_or_none()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")

    if not offer.is_active:
        raise HTTPException(status_code=400, detail="Offer is not active")

    if datetime.utcnow() > offer.order_deadline:
        raise HTTPException(status_code=400, detail="Order deadline has passed")

    # Validate items and calculate total
    total_price = Decimal("0")
    items_to_create = []

    for item_data in order_data.items:
        # Get offer item
        offer_item_result = await db.execute(
            select(OfferItem).where(OfferItem.id == item_data.offer_item_id)
        )
        offer_item = offer_item_result.scalar_one_or_none()

        if not offer_item:
            raise HTTPException(
                status_code=400,
                detail=f"Offer item {item_data.offer_item_id} not found",
            )

        if offer_item.offer_id != order_data.offer_id:
            raise HTTPException(
                status_code=400,
                detail=f"Offer item {item_data.offer_item_id} does not belong to this offer",
            )

        # Check availability
        if offer_item.available_quantity is not None:
            if item_data.quantity > offer_item.available_quantity:
                raise HTTPException(
                    status_code=400,
                    detail=f"Not enough quantity available for item {offer_item.id}",
                )

        item_total = offer_item.price * item_data.quantity
        total_price += item_total

        items_to_create.append(
            {
                "offer_item_id": offer_item.id,
                "quantity": item_data.quantity,
                "unit_price": offer_item.price,
                "available_quantity": offer_item.available_quantity,
            }
        )

    # Create order
    try:
        order = Order(
            offer_id=order_data.offer_id,
            customer_name=order_data.customer_name,
            customer_phone=order_data.customer_phone,
            customer_email=order_data.customer_email,
            payment_method=order_data.payment_method.value,
            total_price=total_price,
            notes=order_data.notes,
        )
        db.add(order)
        await db.flush()
        print(f"DEBUG: Order created with id: {order.id}", flush=True)

        # Create order items and update availability
        for item_info in items_to_create:
            print(f"DEBUG: Creating order item: {item_info}", flush=True)
            order_item = OrderItem(
                order_id=order.id,
                offer_item_id=item_info["offer_item_id"],
                quantity=item_info["quantity"],
                unit_price=item_info["unit_price"],
            )
            db.add(order_item)

            # Update availability
            if item_info["available_quantity"] is not None:
                offer_item_result = await db.execute(
                    select(OfferItem).where(OfferItem.id == item_info["offer_item_id"])
                )
                offer_item_to_update = offer_item_result.scalar_one()
                offer_item_to_update.available_quantity -= item_info["quantity"]

        await db.commit()
        order_id = order.id  # Save ID before expire
        logger.info("Order committed successfully")
    except Exception as e:
        import traceback
        print(f"DEBUG ERROR: {e}", flush=True)
        print(traceback.format_exc(), flush=True)
        raise

    # Reload with relationships
    try:
        result = await db.execute(_order_query().where(Order.id == order_id))
        order_result = result.scalar_one()
        print(f"DEBUG: Order reloaded: {order_result.id}", flush=True)
        print(f"DEBUG: payment_method={order_result.payment_method}, payment_status={order_result.payment_status}", flush=True)
        return order_result
    except Exception as e:
        import traceback
        print(f"DEBUG ERROR reloading: {e}", flush=True)
        print(traceback.format_exc(), flush=True)
        raise


@router.patch("/{order_id}", response_model=OrderResponse)
async def update_order(
    order_id: UUID,
    order_data: OrderUpdate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Update order status (baker only)."""
    result = await db.execute(select(Order).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    update_data = order_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        # Convert enum to string value for database
        if hasattr(value, 'value'):
            value = value.value
        setattr(order, field, value)

    await db.commit()

    # Reload with relationships (order_id from path, no lazy load issue)
    result = await db.execute(_order_query().where(Order.id == order_id))
    return result.scalar_one()


@router.delete("/{order_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_order(
    order_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Delete order (baker only)."""
    result = await db.execute(
        select(Order).options(selectinload(Order.items)).where(Order.id == order_id)
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    # Restore availability
    for order_item in order.items:
        offer_item_result = await db.execute(
            select(OfferItem).where(OfferItem.id == order_item.offer_item_id)
        )
        offer_item = offer_item_result.scalar_one()
        if offer_item.available_quantity is not None:
            offer_item.available_quantity += order_item.quantity

    await db.delete(order)
    await db.commit()
