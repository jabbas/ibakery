import logging
from uuid import UUID
from datetime import datetime
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload

from ..database import get_db

logger = logging.getLogger(__name__)
from ..models.offer import Offer
from ..models.offer_item import OfferItem
from ..models.order import Order
from ..models.order_item import OrderItem
from ..models.product import Product
from ..models.product_ingredient import ProductIngredient
from ..models.product_size import ProductSize
from ..models.ingredient import Ingredient
from ..models.baker import Baker
from ..schemas.offer import (
    OfferCreate,
    OfferUpdate,
    OfferResponse,
    OfferSummary,
    IngredientSummary,
)
from .auth import get_current_baker
from ..services.recurring_service import generate_recurring_offers, format_recurrence_rule_pl

router = APIRouter(prefix="/offers", tags=["offers"])


def _offer_query():
    return select(Offer).options(
        selectinload(Offer.items)
        .selectinload(OfferItem.product)
        .selectinload(Product.ingredients)
        .selectinload(ProductIngredient.ingredient)
        .selectinload(Ingredient.unit),
        selectinload(Offer.items)
        .selectinload(OfferItem.product)
        .selectinload(Product.sizes),
        selectinload(Offer.items)
        .selectinload(OfferItem.product_size),
    )


@router.get("", response_model=list[OfferResponse])
async def get_offers(
    active_only: bool = True,
    include_completed: bool = False,
    db: AsyncSession = Depends(get_db),
):
    query = _offer_query()
    if active_only:
        query = query.where(Offer.is_active == True)
    if not include_completed:
        query = query.where(Offer.is_completed == False)
    query = query.order_by(Offer.pickup_date.desc())
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/active", response_model=list[OfferResponse])
async def get_active_offers(db: AsyncSession = Depends(get_db)):
    """Get offers that are still accepting orders (for clients)."""
    now = datetime.utcnow()
    result = await db.execute(
        _offer_query()
        .where(Offer.is_active == True)
        .where(Offer.is_completed == False)
        .where(Offer.order_deadline > now)
        .order_by(Offer.pickup_date)
    )
    return result.scalars().all()


@router.get("/{offer_id}", response_model=OfferResponse)
async def get_offer(offer_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(_offer_query().where(Offer.id == offer_id))
    offer = result.scalar_one_or_none()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    return offer


@router.post("", response_model=OfferResponse, status_code=status.HTTP_201_CREATED)
async def create_offer(
    offer_data: OfferCreate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    # Create offer
    offer = Offer(
        title=offer_data.title,
        description=offer_data.description,
        pickup_date=offer_data.pickup_date,
        pickup_time_from=offer_data.pickup_time_from,
        pickup_time_to=offer_data.pickup_time_to,
        order_deadline=offer_data.order_deadline,
        is_recurring=offer_data.is_recurring,
        recurrence_rule=offer_data.recurrence_rule,
    )
    db.add(offer)
    await db.flush()

    # Add items
    for item_data in offer_data.items:
        offer_item = OfferItem(
            offer_id=offer.id,
            product_id=item_data.product_id,
            product_size_id=item_data.product_size_id,
            price=item_data.price,
            max_quantity=item_data.max_quantity,
            available_quantity=item_data.max_quantity,
        )
        db.add(offer_item)

    await db.commit()

    # Expire all cached objects to force fresh load
    db.expire_all()

    # Reload with relationships
    result = await db.execute(_offer_query().where(Offer.id == offer.id))
    return result.scalar_one()


@router.put("/{offer_id}", response_model=OfferResponse)
async def update_offer(
    offer_id: UUID,
    offer_data: OfferUpdate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    result = await db.execute(
        select(Offer).options(selectinload(Offer.items)).where(Offer.id == offer_id)
    )
    offer = result.scalar_one_or_none()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")

    # Update basic fields
    update_data = offer_data.model_dump(exclude_unset=True, exclude={"items"})
    for field, value in update_data.items():
        setattr(offer, field, value)

    # Update items if provided
    if offer_data.items is not None:
        # Remove existing items
        for item in offer.items:
            await db.delete(item)

        # Add new items
        for item_data in offer_data.items:
            offer_item = OfferItem(
                offer_id=offer.id,
                product_id=item_data.product_id,
                product_size_id=item_data.product_size_id,
                price=item_data.price,
                max_quantity=item_data.max_quantity,
                available_quantity=item_data.max_quantity,
            )
            db.add(offer_item)

    await db.commit()

    # Expire all cached objects to force fresh load
    db.expire_all()

    # Reload with relationships
    result = await db.execute(_offer_query().where(Offer.id == offer.id))
    return result.scalar_one()


@router.delete("/{offer_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_offer(
    offer_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    try:
        logger.debug(f"[DELETE_OFFER] START: {offer_id}")

        result = await db.execute(select(Offer).where(Offer.id == offer_id))
        offer = result.scalar_one_or_none()
        if not offer:
            raise HTTPException(status_code=404, detail="Offer not found")

        # Check if there are any orders for this offer
        orders_count_result = await db.execute(
            select(func.count(Order.id)).where(Order.offer_id == offer_id)
        )
        orders_count = orders_count_result.scalar()

        if orders_count > 0:
            raise HTTPException(
                status_code=400,
                detail=f"Nie można usunąć oferty z zamówieniami ({orders_count} zamówień). Najpierw usuń zamówienia lub dezaktywuj ofertę."
            )

        await db.delete(offer)
        await db.commit()
        logger.debug(f"[DELETE_OFFER] SUCCESS: {offer_id}")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[DELETE_OFFER] EXCEPTION: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{offer_id}/complete", response_model=OfferResponse)
async def complete_offer(
    offer_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Ręcznie oznacz ofertę jako zakończoną."""
    result = await db.execute(select(Offer).where(Offer.id == offer_id))
    offer = result.scalar_one_or_none()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")

    offer.is_completed = True
    await db.commit()

    db.expire_all()
    result = await db.execute(_offer_query().where(Offer.id == offer_id))
    return result.scalar_one()


@router.get("/{offer_id}/summary", response_model=OfferSummary)
async def get_offer_summary(
    offer_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Calculate ingredient summary for an offer based on orders."""
    # Get offer
    result = await db.execute(select(Offer).where(Offer.id == offer_id))
    offer = result.scalar_one_or_none()
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")

    # Get all orders for this offer
    orders_result = await db.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.offer_id == offer_id)
    )
    orders = orders_result.scalars().all()

    total_revenue = Decimal("0")
    ingredient_totals: dict[UUID, dict] = {}

    for order in orders:
        total_revenue += order.total_price

        for order_item in order.items:
            # Get offer item -> product -> ingredients + product_size + parent_product
            offer_item_result = await db.execute(
                select(OfferItem)
                .options(
                    selectinload(OfferItem.product).selectinload(
                        Product.ingredients
                    ).selectinload(ProductIngredient.ingredient).selectinload(
                        Ingredient.unit
                    ),
                    selectinload(OfferItem.product).selectinload(
                        Product.parent_product
                    ).selectinload(Product.ingredients).selectinload(
                        ProductIngredient.ingredient
                    ).selectinload(Ingredient.unit),
                    selectinload(OfferItem.product_size),
                )
                .where(OfferItem.id == order_item.offer_item_id)
            )
            offer_item = offer_item_result.scalar_one()

            # Skip if product was deleted
            if offer_item.product is None:
                continue

            product = offer_item.product

            # Get size percentage (default 100% if no size specified)
            size_percentage = Decimal("100")
            if offer_item.product_size:
                size_percentage = offer_item.product_size.percentage

            # Helper function to add ingredient to totals
            def add_ingredient(prod_ing, multiplier=Decimal("1")):
                ing = prod_ing.ingredient
                ing_id = ing.id

                if ing_id not in ingredient_totals:
                    ingredient_totals[ing_id] = {
                        "ingredient_id": ing_id,
                        "ingredient_name": ing.name,
                        "unit_abbreviation": ing.unit.abbreviation,
                        "total_quantity": Decimal("0"),
                        "price_per_unit": ing.price_per_unit,
                    }

                # Apply size percentage and multiplier to ingredient quantity
                ingredient_totals[ing_id]["total_quantity"] += (
                    prod_ing.quantity * order_item.quantity * size_percentage * multiplier / Decimal("100")
                )

            # Add parent product ingredients (scaled by base_percentage)
            if product.parent_product is not None:
                parent_multiplier = product.base_percentage / Decimal("100")
                for prod_ing in product.parent_product.ingredients:
                    add_ingredient(prod_ing, parent_multiplier)

            # Add product's own ingredients
            for prod_ing in product.ingredients:
                add_ingredient(prod_ing)

    # Calculate costs
    ingredients_summary = []
    total_cost = Decimal("0")

    for ing_data in ingredient_totals.values():
        cost = ing_data["total_quantity"] * ing_data["price_per_unit"]
        total_cost += cost
        ingredients_summary.append(
            IngredientSummary(
                ingredient_id=ing_data["ingredient_id"],
                ingredient_name=ing_data["ingredient_name"],
                unit_abbreviation=ing_data["unit_abbreviation"],
                total_quantity=ing_data["total_quantity"],
                price_per_unit=ing_data["price_per_unit"],
                total_cost=cost,
            )
        )

    return OfferSummary(
        offer_id=offer_id,
        offer_title=offer.title,
        total_orders=len(orders),
        total_revenue=total_revenue,
        ingredients=ingredients_summary,
        total_ingredient_cost=total_cost,
        profit=total_revenue - total_cost,
    )


@router.post("/generate-recurring")
async def generate_recurring(
    days_ahead: int = 14,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Generate recurring offer instances for the next N days."""
    created = await generate_recurring_offers(db, days_ahead=days_ahead)
    return {
        "message": f"Generated {len(created)} offer instances",
        "created": created,
    }


@router.get("/recurring-templates", response_model=list[OfferResponse])
async def get_recurring_templates(
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Get all recurring offer templates."""
    result = await db.execute(
        _offer_query()
        .where(Offer.is_recurring == True)
        .where(Offer.parent_offer_id == None)
        .order_by(Offer.title)
    )
    return result.scalars().all()
