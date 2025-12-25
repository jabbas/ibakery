from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from ..database import get_db
from ..models.ingredient import Ingredient
from ..models.baker import Baker
from ..schemas.ingredient import IngredientCreate, IngredientUpdate, IngredientResponse
from .auth import get_current_baker

router = APIRouter(prefix="/ingredients", tags=["ingredients"])


@router.get("", response_model=list[IngredientResponse])
async def get_ingredients(db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Ingredient).options(selectinload(Ingredient.unit)).order_by(Ingredient.name)
    )
    return result.scalars().all()


@router.get("/{ingredient_id}", response_model=IngredientResponse)
async def get_ingredient(ingredient_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Ingredient)
        .options(selectinload(Ingredient.unit))
        .where(Ingredient.id == ingredient_id)
    )
    ingredient = result.scalar_one_or_none()
    if not ingredient:
        raise HTTPException(status_code=404, detail="Ingredient not found")
    return ingredient


@router.post("", response_model=IngredientResponse, status_code=status.HTTP_201_CREATED)
async def create_ingredient(
    ingredient_data: IngredientCreate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    ingredient = Ingredient(**ingredient_data.model_dump())
    db.add(ingredient)
    await db.commit()
    await db.refresh(ingredient)

    # Reload with unit
    result = await db.execute(
        select(Ingredient)
        .options(selectinload(Ingredient.unit))
        .where(Ingredient.id == ingredient.id)
    )
    return result.scalar_one()


@router.put("/{ingredient_id}", response_model=IngredientResponse)
async def update_ingredient(
    ingredient_id: UUID,
    ingredient_data: IngredientUpdate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    result = await db.execute(select(Ingredient).where(Ingredient.id == ingredient_id))
    ingredient = result.scalar_one_or_none()
    if not ingredient:
        raise HTTPException(status_code=404, detail="Ingredient not found")

    update_data = ingredient_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(ingredient, field, value)

    await db.commit()

    # Reload with unit
    result = await db.execute(
        select(Ingredient)
        .options(selectinload(Ingredient.unit))
        .where(Ingredient.id == ingredient.id)
    )
    return result.scalar_one()


@router.delete("/{ingredient_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_ingredient(
    ingredient_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    result = await db.execute(select(Ingredient).where(Ingredient.id == ingredient_id))
    ingredient = result.scalar_one_or_none()
    if not ingredient:
        raise HTTPException(status_code=404, detail="Ingredient not found")

    await db.delete(ingredient)
    await db.commit()
