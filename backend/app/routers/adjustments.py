from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from app.database import get_db
from app.models.all_models import Adjustment, AdjustmentLine, Stock, OperationStatus, User, RefType
from app.core.dependencies import get_current_user
from app.services.stock_service import apply_delta

router = APIRouter(prefix="/adjustments", tags=["adjustments"])

class AdjustmentLineIn(BaseModel):
    product_id: int
    counted_qty: float

class AdjustmentIn(BaseModel):
    location_id: int
    notes: Optional[str] = None
    lines: list[AdjustmentLineIn] = []

@router.get("")
async def list_adjustments(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Adjustment))
    return result.scalars().all()

@router.post("", status_code=201)
async def create_adjustment(body: AdjustmentIn, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    adj = Adjustment(location_id=body.location_id, notes=body.notes, created_by=user.id)
    db.add(adj)
    await db.flush()
    for line in body.lines:
        # Fetch current system qty
        stock_result = await db.execute(
            select(Stock).where(Stock.product_id == line.product_id, Stock.location_id == body.location_id)
        )
        stock = stock_result.scalar_one_or_none()
        system_qty = stock.quantity if stock else 0.0
        delta = line.counted_qty - system_qty
        db.add(AdjustmentLine(
            adjustment_id=adj.id,
            product_id=line.product_id,
            system_qty=system_qty,
            counted_qty=line.counted_qty,
            delta=delta
        ))
    await db.commit()
    await db.refresh(adj)
    return adj

@router.get("/{adjustment_id}")
async def get_adjustment(adjustment_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Adjustment).where(Adjustment.id == adjustment_id))
    adj = result.scalar_one_or_none()
    if not adj:
        raise HTTPException(404, "Adjustment not found")
    lines = await db.execute(select(AdjustmentLine).where(AdjustmentLine.adjustment_id == adjustment_id))
    return {"adjustment": adj, "lines": lines.scalars().all()}

@router.post("/{adjustment_id}/validate")
async def validate_adjustment(adjustment_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(select(Adjustment).where(Adjustment.id == adjustment_id))
    adj = result.scalar_one_or_none()
    if not adj:
        raise HTTPException(404, "Adjustment not found")
    if adj.status == OperationStatus.done:
        raise HTTPException(400, "Already validated")

    lines_result = await db.execute(select(AdjustmentLine).where(AdjustmentLine.adjustment_id == adjustment_id))
    for line in lines_result.scalars().all():
        if line.delta == 0:
            continue
        await apply_delta(
            db, line.product_id, adj.location_id,
            delta=line.delta,
            ref_type=RefType.adjustment,
            ref_id=adj.id,
            created_by=user.id,
            allow_negative=False,
            note=f"Stock adjustment: system={line.system_qty} → counted={line.counted_qty}"
        )
    adj.status = OperationStatus.done
    await db.commit()
    return {"message": "Adjustment validated", "adjustment_id": adj.id}
