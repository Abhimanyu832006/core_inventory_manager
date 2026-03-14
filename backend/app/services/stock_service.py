"""
stock_service.py
Core engine for all stock mutations.
ALL stock changes go through here — never mutate Stock directly from routers.
Every mutation auto-creates a ledger entry.
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.all_models import Stock, StockLedger, RefType
from fastapi import HTTPException, status


async def _get_or_create_stock(db: AsyncSession, product_id: int, location_id: int) -> Stock:
    result = await db.execute(
        select(Stock).where(Stock.product_id == product_id, Stock.location_id == location_id)
    )
    stock = result.scalar_one_or_none()
    if not stock:
        stock = Stock(product_id=product_id, location_id=location_id, quantity=0.0)
        db.add(stock)
        await db.flush()
    return stock


async def apply_delta(
    db: AsyncSession,
    product_id: int,
    location_id: int,
    delta: float,
    ref_type: RefType,
    ref_id: int,
    created_by: int,
    note: str | None = None,
    allow_negative: bool = False,
) -> Stock:
    stock = await _get_or_create_stock(db, product_id, location_id)

    new_qty = stock.quantity + delta
    if not allow_negative and new_qty < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient stock for product_id={product_id} at location_id={location_id}. "
                   f"Available: {stock.quantity}, Requested: {abs(delta)}"
        )

    stock.quantity = new_qty

    ledger_entry = StockLedger(
        product_id=product_id,
        location_id=location_id,
        ref_type=ref_type,
        ref_id=ref_id,
        delta=delta,
        qty_after=new_qty,
        note=note,
        created_by=created_by,
    )
    db.add(ledger_entry)
    return stock


async def transfer_stock(
    db: AsyncSession,
    product_id: int,
    from_location_id: int,
    to_location_id: int,
    qty: float,
    ref_id: int,
    created_by: int,
    note: str | None = None,
):
    """Move stock between locations. Net total unchanged."""
    await apply_delta(
        db, product_id, from_location_id, -qty,
        RefType.transfer, ref_id, created_by, note=f"Transfer out → location {to_location_id}"
    )
    await apply_delta(
        db, product_id, to_location_id, +qty,
        RefType.transfer, ref_id, created_by, note=f"Transfer in ← location {from_location_id}"
    )
