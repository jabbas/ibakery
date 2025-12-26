from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from ..database import get_db
from ..models.pickup_point import PickupPoint
from ..models.order import Order
from ..models.baker import Baker
from ..schemas.pickup_point import PickupPointCreate, PickupPointUpdate, PickupPointResponse
from .auth import get_current_baker

router = APIRouter(prefix="/pickup-points", tags=["pickup-points"])


@router.get("", response_model=list[PickupPointResponse])
async def get_pickup_points(
    active_only: bool = False,
    db: AsyncSession = Depends(get_db),
):
    """Get all pickup points. Optionally filter by active status."""
    query = select(PickupPoint).order_by(PickupPoint.name)
    if active_only:
        query = query.where(PickupPoint.is_active == True)
    result = await db.execute(query)
    return result.scalars().all()


@router.get("/{pickup_point_id}", response_model=PickupPointResponse)
async def get_pickup_point(
    pickup_point_id: UUID,
    db: AsyncSession = Depends(get_db),
):
    """Get pickup point by ID."""
    result = await db.execute(
        select(PickupPoint).where(PickupPoint.id == pickup_point_id)
    )
    pickup_point = result.scalar_one_or_none()
    if not pickup_point:
        raise HTTPException(status_code=404, detail="Punkt odbioru nie istnieje")
    return pickup_point


@router.post("", response_model=PickupPointResponse, status_code=status.HTTP_201_CREATED)
async def create_pickup_point(
    data: PickupPointCreate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Create a new pickup point (baker only)."""
    pickup_point = PickupPoint(**data.model_dump())
    db.add(pickup_point)
    await db.commit()
    await db.refresh(pickup_point)
    return pickup_point


@router.put("/{pickup_point_id}", response_model=PickupPointResponse)
async def update_pickup_point(
    pickup_point_id: UUID,
    data: PickupPointUpdate,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Update pickup point (baker only)."""
    result = await db.execute(
        select(PickupPoint).where(PickupPoint.id == pickup_point_id)
    )
    pickup_point = result.scalar_one_or_none()
    if not pickup_point:
        raise HTTPException(status_code=404, detail="Punkt odbioru nie istnieje")

    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(pickup_point, field, value)

    await db.commit()
    await db.refresh(pickup_point)
    return pickup_point


@router.delete("/{pickup_point_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_pickup_point(
    pickup_point_id: UUID,
    db: AsyncSession = Depends(get_db),
    _: Baker = Depends(get_current_baker),
):
    """Delete pickup point (baker only). Will fail if orders reference it."""
    result = await db.execute(
        select(PickupPoint).where(PickupPoint.id == pickup_point_id)
    )
    pickup_point = result.scalar_one_or_none()
    if not pickup_point:
        raise HTTPException(status_code=404, detail="Punkt odbioru nie istnieje")

    # Check if any orders reference this pickup point
    order_result = await db.execute(
        select(Order).where(Order.pickup_point_id == pickup_point_id).limit(1)
    )
    if order_result.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail="Nie mozna usunac punktu odbioru, do ktorego istnieja zamowienia. Dezaktywuj go zamiast usuwac."
        )

    await db.delete(pickup_point)
    await db.commit()
