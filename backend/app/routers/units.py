from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..database import get_db
from ..models.unit import Unit
from ..models.baker import Baker
from ..schemas.unit import UnitCreate, UnitUpdate, UnitResponse
from .auth import get_current_baker

router = APIRouter(prefix="/units", tags=["units"])


@router.get("", response_model=list[UnitResponse])
async def get_units(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Unit).order_by(Unit.name))
    return result.scalars().all()


@router.get("/{unit_id}", response_model=UnitResponse)
async def get_unit(unit_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Unit).where(Unit.id == unit_id))
    unit = result.scalar_one_or_none()
    if not unit:
        raise HTTPException(status_code=404, detail="Unit not found")
    return unit


@router.post("", response_model=UnitResponse, status_code=status.HTTP_201_CREATED)
async def create_unit(
    unit_data: UnitCreate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    unit = Unit(**unit_data.model_dump())
    db.add(unit)
    await db.commit()
    await db.refresh(unit)
    return unit


@router.put("/{unit_id}", response_model=UnitResponse)
async def update_unit(
    unit_id: UUID,
    unit_data: UnitUpdate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    result = await db.execute(select(Unit).where(Unit.id == unit_id))
    unit = result.scalar_one_or_none()
    if not unit:
        raise HTTPException(status_code=404, detail="Unit not found")

    update_data = unit_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(unit, field, value)

    await db.commit()
    await db.refresh(unit)
    return unit


@router.delete("/{unit_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_unit(
    unit_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    result = await db.execute(select(Unit).where(Unit.id == unit_id))
    unit = result.scalar_one_or_none()
    if not unit:
        raise HTTPException(status_code=404, detail="Unit not found")

    await db.delete(unit)
    await db.commit()
