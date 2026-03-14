from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from app.database import get_db
from app.models.all_models import Transfer, TransferLine, OperationStatus, User
from app.core.dependencies import get_current_user
from app.services.stock_service import transfer_stock

router = APIRouter(prefix="/transfers", tags=["transfers"])

class TransferLineIn(BaseModel):
    product_id: int
    qty: float

class TransferIn(BaseModel):
    from_location_id: int
    to_location_id: int
    notes: Optional[str] = None
    lines: list[TransferLineIn] = []

@router.get("")
async def list_transfers(status: Optional[OperationStatus] = None, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    q = select(Transfer)
    if status:
        q = q.where(Transfer.status == status)
    result = await db.execute(q)
    return result.scalars().all()

@router.post("", status_code=201)
async def create_transfer(body: TransferIn, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    if body.from_location_id == body.to_location_id:
        raise HTTPException(400, "Source and destination must be different")
    t = Transfer(
        from_location_id=body.from_location_id,
        to_location_id=body.to_location_id,
        notes=body.notes, created_by=user.id
    )
    db.add(t)
    await db.flush()
    for line in body.lines:
        db.add(TransferLine(transfer_id=t.id, **line.model_dump()))
    await db.commit()
    await db.refresh(t)
    return t

@router.get("/{transfer_id}")
async def get_transfer(transfer_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Transfer).where(Transfer.id == transfer_id))
    t = result.scalar_one_or_none()
    if not t:
        raise HTTPException(404, "Transfer not found")
    lines = await db.execute(select(TransferLine).where(TransferLine.transfer_id == transfer_id))
    return {"transfer": t, "lines": lines.scalars().all()}

@router.post("/{transfer_id}/validate")
async def validate_transfer(transfer_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(select(Transfer).where(Transfer.id == transfer_id))
    t = result.scalar_one_or_none()
    if not t:
        raise HTTPException(404, "Transfer not found")
    if t.status == OperationStatus.done:
        raise HTTPException(400, "Already validated")

    lines_result = await db.execute(select(TransferLine).where(TransferLine.transfer_id == transfer_id))
    for line in lines_result.scalars().all():
        await transfer_stock(
            db, line.product_id,
            t.from_location_id, t.to_location_id,
            line.qty, ref_id=t.id, created_by=user.id,
            note=t.notes
        )
    t.status = OperationStatus.done
    await db.commit()
    return {"message": "Transfer validated", "transfer_id": t.id}
