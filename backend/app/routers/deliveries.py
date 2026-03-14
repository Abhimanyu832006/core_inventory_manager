"""
routers/deliveries.py
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from app.database import get_db
from app.models.all_models import Delivery, DeliveryLine, OperationStatus, User, RefType
from app.core.dependencies import get_current_user
from app.services.stock_service import apply_delta

router = APIRouter(prefix="/deliveries", tags=["deliveries"])

class DeliveryLineIn(BaseModel):
    product_id: int
    location_id: int
    qty: float

class DeliveryIn(BaseModel):
    customer: str
    notes: Optional[str] = None
    lines: list[DeliveryLineIn] = []

@router.get("")
async def list_deliveries(status: Optional[OperationStatus] = None, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    q = select(Delivery)
    if status:
        q = q.where(Delivery.status == status)
    result = await db.execute(q)
    return result.scalars().all()

@router.post("", status_code=201)
async def create_delivery(body: DeliveryIn, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    delivery = Delivery(customer=body.customer, notes=body.notes, created_by=user.id)
    db.add(delivery)
    await db.flush()
    for line in body.lines:
        db.add(DeliveryLine(delivery_id=delivery.id, **line.model_dump()))
    await db.commit()
    await db.refresh(delivery)
    return delivery

@router.get("/{delivery_id}")
async def get_delivery(delivery_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Delivery).where(Delivery.id == delivery_id))
    d = result.scalar_one_or_none()
    if not d:
        raise HTTPException(404, "Delivery not found")
    lines = await db.execute(select(DeliveryLine).where(DeliveryLine.delivery_id == delivery_id))
    return {"delivery": d, "lines": lines.scalars().all()}

@router.post("/{delivery_id}/validate")
async def validate_delivery(delivery_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(select(Delivery).where(Delivery.id == delivery_id))
    d = result.scalar_one_or_none()
    if not d:
        raise HTTPException(404, "Delivery not found")
    if d.status == OperationStatus.done:
        raise HTTPException(400, "Already validated")

    lines_result = await db.execute(select(DeliveryLine).where(DeliveryLine.delivery_id == delivery_id))
    lines = lines_result.scalars().all()
    for line in lines:
        await apply_delta(
            db, line.product_id, line.location_id,
            delta=-line.qty,
            ref_type=RefType.delivery,
            ref_id=d.id,
            created_by=user.id,
            note=f"Delivery to {d.customer}"
        )
    d.status = OperationStatus.done
    await db.commit()
    return {"message": "Delivery validated", "delivery_id": d.id}
