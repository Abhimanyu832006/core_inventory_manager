"""
routers/ledger.py
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import Optional
from app.database import get_db
from app.models.all_models import StockLedger, RefType, User
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/ledger", tags=["ledger"])

@router.get("")
async def get_ledger(
    product_id: Optional[int] = None,
    location_id: Optional[int] = None,
    ref_type: Optional[RefType] = None,
    limit: int = 100,
    offset: int = 0,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)
):
    q = select(StockLedger).order_by(StockLedger.created_at.desc()).limit(limit).offset(offset)
    if product_id:
        q = q.where(StockLedger.product_id == product_id)
    if location_id:
        q = q.where(StockLedger.location_id == location_id)
    if ref_type:
        q = q.where(StockLedger.ref_type == ref_type)
    result = await db.execute(q)
    return result.scalars().all()


"""
routers/dashboard.py
"""
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from app.database import get_db
from app.models.all_models import Product, Stock, Receipt, Delivery, Transfer, OperationStatus, User
from app.core.dependencies import get_current_user
from app.core.config import settings

dashboard_router = APIRouter(prefix="/dashboard", tags=["dashboard"])

@dashboard_router.get("/kpis")
async def get_kpis(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    # Total products
    total_products = (await db.execute(select(func.count(Product.id)))).scalar() or 0

    # Low stock & out of stock
    products = (await db.execute(select(Product))).scalars().all()
    low_stock_count = 0
    out_of_stock_count = 0
    for p in products:
        total_qty = (await db.execute(select(func.sum(Stock.quantity)).where(Stock.product_id == p.id))).scalar() or 0.0
        if total_qty == 0:
            out_of_stock_count += 1
        elif total_qty <= p.reorder_min:
            low_stock_count += 1

    # Pending operations (not done, not cancelled)
    pending_statuses = [OperationStatus.draft, OperationStatus.waiting, OperationStatus.ready]

    pending_receipts = (await db.execute(
        select(func.count(Receipt.id)).where(Receipt.status.in_(pending_statuses))
    )).scalar() or 0

    pending_deliveries = (await db.execute(
        select(func.count(Delivery.id)).where(Delivery.status.in_(pending_statuses))
    )).scalar() or 0

    pending_transfers = (await db.execute(
        select(func.count(Transfer.id)).where(Transfer.status.in_(pending_statuses))
    )).scalar() or 0

    return {
        "total_products": total_products,
        "low_stock": low_stock_count,
        "out_of_stock": out_of_stock_count,
        "pending_receipts": pending_receipts,
        "pending_deliveries": pending_deliveries,
        "pending_transfers": pending_transfers,
    }
