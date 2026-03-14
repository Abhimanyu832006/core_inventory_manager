from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from app.database import get_db
from app.models.all_models import Receipt, ReceiptLine, OperationStatus, User, RefType
from app.core.dependencies import get_current_user
from app.services.stock_service import apply_delta

router = APIRouter(prefix="/receipts", tags=["receipts"])

class ReceiptLineIn(BaseModel):
    product_id: int
    expected_qty: float
    received_qty: float = 0.0

class ReceiptIn(BaseModel):
    supplier: str
    location_id: int
    notes: Optional[str] = None
    lines: list[ReceiptLineIn] = []

@router.get("")
async def list_receipts(
    status: Optional[OperationStatus] = None,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)
):
    q = select(Receipt)
    if status:
        q = q.where(Receipt.status == status)
    result = await db.execute(q)
    return result.scalars().all()

@router.post("", status_code=201)
async def create_receipt(body: ReceiptIn, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    receipt = Receipt(
        supplier=body.supplier, location_id=body.location_id,
        notes=body.notes, created_by=user.id
    )
    db.add(receipt)
    await db.flush()
    for line in body.lines:
        db.add(ReceiptLine(receipt_id=receipt.id, **line.model_dump()))
    await db.commit()
    await db.refresh(receipt)
    return receipt

@router.get("/{receipt_id}")
async def get_receipt(receipt_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Receipt).where(Receipt.id == receipt_id))
    r = result.scalar_one_or_none()
    if not r:
        raise HTTPException(404, "Receipt not found")
    lines_result = await db.execute(select(ReceiptLine).where(ReceiptLine.receipt_id == receipt_id))
    return {"receipt": r, "lines": lines_result.scalars().all()}

@router.put("/{receipt_id}")
async def update_receipt(receipt_id: int, body: ReceiptIn, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    result = await db.execute(select(Receipt).where(Receipt.id == receipt_id))
    r = result.scalar_one_or_none()
    if not r:
        raise HTTPException(404, "Receipt not found")
    if r.status == OperationStatus.done:
        raise HTTPException(400, "Cannot edit a validated receipt")
    r.supplier = body.supplier
    r.location_id = body.location_id
    r.notes = body.notes
    # Delete old lines and re-add
    old_lines = await db.execute(select(ReceiptLine).where(ReceiptLine.receipt_id == receipt_id))
    for line in old_lines.scalars().all():
        await db.delete(line)
    for line in body.lines:
        db.add(ReceiptLine(receipt_id=r.id, **line.model_dump()))
    await db.commit()
    return r

@router.post("/{receipt_id}/validate")
async def validate_receipt(receipt_id: int, db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)):
    """Validate receipt → stock increases for each line by received_qty."""
    result = await db.execute(select(Receipt).where(Receipt.id == receipt_id))
    r = result.scalar_one_or_none()
    if not r:
        raise HTTPException(404, "Receipt not found")
    if r.status == OperationStatus.done:
        raise HTTPException(400, "Already validated")
    if r.status == OperationStatus.cancelled:
        raise HTTPException(400, "Receipt is cancelled")

    lines_result = await db.execute(select(ReceiptLine).where(ReceiptLine.receipt_id == receipt_id))
    lines = lines_result.scalars().all()
    if not lines:
        raise HTTPException(400, "No lines to validate")

    for line in lines:
        if line.received_qty <= 0:
            raise HTTPException(400, f"received_qty must be > 0 for product_id={line.product_id}")
        await apply_delta(
            db, line.product_id, r.location_id,
            delta=line.received_qty,
            ref_type=RefType.receipt,
            ref_id=r.id,
            created_by=user.id,
            note=f"Receipt from {r.supplier}"
        )

    r.status = OperationStatus.done
    await db.commit()
    return {"message": "Receipt validated", "receipt_id": r.id}
