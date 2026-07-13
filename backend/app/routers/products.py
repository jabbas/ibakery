import logging
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload, joinedload

from ..database import get_db
from ..models.product import Product
from ..models.product_ingredient import ProductIngredient
from ..models.product_size import ProductSize
from ..models.ingredient import Ingredient
from ..models.offer_item import OfferItem
from ..models.offer import Offer
from ..models.baker import Baker
from ..schemas.product import ProductCreate, ProductUpdate, ProductResponse
from .auth import get_current_baker

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/products", tags=["products"])


def _product_query():
    return select(Product).options(
        selectinload(Product.ingredients)
        .selectinload(ProductIngredient.ingredient)
        .selectinload(Ingredient.unit),
        selectinload(Product.sizes),
        # Use joinedload for parent_product to load it in single query
        # and only load basic columns needed for ParentProductInfo
        joinedload(Product.parent_product).load_only(
            Product.id, Product.name, Product.base_price
        ),
    )


@router.get("", response_model=list[ProductResponse])
async def get_products(db: AsyncSession = Depends(get_db)):
    result = await db.execute(_product_query().order_by(Product.name))
    return result.scalars().all()


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(_product_query().where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


@router.post("", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
async def create_product(
    product_data: ProductCreate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    try:
        # Create product
        product = Product(
            name=product_data.name,
            description=product_data.description,
            image_url=product_data.image_url,
            base_price=product_data.base_price,
            parent_product_id=product_data.parent_product_id,
            base_percentage=product_data.base_percentage,
        )
        db.add(product)
        await db.flush()

        # Save ID before adding related objects
        product_id = product.id

        # Add ingredients
        for ing_data in product_data.ingredients:
            product_ingredient = ProductIngredient(
                product_id=product_id,
                ingredient_id=ing_data.ingredient_id,
                quantity=ing_data.quantity,
            )
            db.add(product_ingredient)

        # Add sizes
        for size_data in product_data.sizes:
            product_size = ProductSize(
                product_id=product_id,
                name=size_data.name,
                percentage=size_data.percentage,
                is_default=size_data.is_default,
                sort_order=size_data.sort_order,
            )
            db.add(product_size)

        await db.commit()

        # Expire all cached objects to force fresh load
        db.expire_all()

        # Reload with relationships
        result = await db.execute(_product_query().where(Product.id == product_id))
        loaded_product = result.scalar_one()

        # Explicitly serialize to catch any issues
        return ProductResponse.model_validate(loaded_product)

    except Exception as e:
        logger.error(f"[CREATE_PRODUCT] EXCEPTION: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: UUID,
    product_data: ProductUpdate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    try:
        logger.debug(f"[UPDATE_PRODUCT] START: {product_id}")

        result = await db.execute(
            select(Product)
            .options(selectinload(Product.ingredients), selectinload(Product.sizes))
            .where(Product.id == product_id)
        )
        product = result.scalar_one_or_none()
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        logger.debug(f"[UPDATE_PRODUCT] Product found: {product.name}")

        # Update basic fields
        update_data = product_data.model_dump(exclude_unset=True, exclude={"ingredients", "sizes"})
        for field, value in update_data.items():
            setattr(product, field, value)

        # Update ingredients if provided
        if product_data.ingredients is not None:
            logger.debug(f"[UPDATE_PRODUCT] Updating ingredients: {len(product_data.ingredients)}")
            # Remove existing ingredients
            for ing in product.ingredients:
                await db.delete(ing)

            # Add new ingredients
            for ing_data in product_data.ingredients:
                product_ingredient = ProductIngredient(
                    product_id=product.id,
                    ingredient_id=ing_data.ingredient_id,
                    quantity=ing_data.quantity,
                )
                db.add(product_ingredient)

        # Update sizes if provided
        if product_data.sizes is not None:
            logger.debug(f"[UPDATE_PRODUCT] Updating sizes: {len(product_data.sizes)}")
            # Remove existing sizes
            for size in product.sizes:
                await db.delete(size)

            # Add new sizes
            for size_data in product_data.sizes:
                product_size = ProductSize(
                    product_id=product.id,
                    name=size_data.name,
                    percentage=size_data.percentage,
                    is_default=size_data.is_default,
                    sort_order=size_data.sort_order,
                )
                db.add(product_size)

        await db.commit()
        logger.debug("[UPDATE_PRODUCT] COMMITTED")

        # Expire all cached objects to force fresh load
        db.expire_all()

        # Reload with relationships - use fresh query
        logger.debug("[UPDATE_PRODUCT] Reloading product...")
        result = await db.execute(_product_query().where(Product.id == product_id))
        product = result.scalar_one()
        logger.debug("[UPDATE_PRODUCT] Product reloaded, serializing...")

        # Serialize response
        response = ProductResponse.model_validate(product)
        logger.debug("[UPDATE_PRODUCT] SUCCESS")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[UPDATE_PRODUCT] EXCEPTION: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_product(
    product_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    result = await db.execute(select(Product).where(Product.id == product_id))
    product = result.scalar_one_or_none()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")

    # Check if product is used in any active (non-completed) offers
    active_offer_items_result = await db.execute(
        select(func.count(OfferItem.id))
        .join(Offer, OfferItem.offer_id == Offer.id)
        .where(OfferItem.product_id == product_id)
        .where(Offer.is_completed == False)  # noqa: E712
    )
    active_count = active_offer_items_result.scalar()

    if active_count > 0:
        raise HTTPException(
            status_code=400,
            detail=f"Nie można usunąć produktu, który jest używany w aktywnych ofertach ({active_count} pozycji). Najpierw zakończ oferty lub usuń z nich ten produkt."
        )

    await db.delete(product)
    await db.commit()
