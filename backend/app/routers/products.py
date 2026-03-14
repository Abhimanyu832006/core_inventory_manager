from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from typing import Optional
from app.database import get_db
from app.models.all_models import Product, ProductCategory, Stock
from app.core.dependencies import get_current_user
from app.models.all_models import User

router = APIRouter(prefix="/products", tags=["products"])

class CategoryIn(BaseModel):
    name: str

class ProductIn(BaseModel):
    name: str
    sku: str
    category_id: Optional[int] = None
    unit_of_measure: str = "pcs"
    reorder_min: int = 10

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    category_id: Optional[int] = None
    unit_of_measure: Optional[str] = None
    reorder_min: Optional[int] = None

# ── Categories ───────────────────────────────────────────────────────────────

@router.get("/categories")
async def list_categories(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(ProductCategory))
    return result.scalars().all()

@router.post("/categories", status_code=201)
async def create_category(body: CategoryIn, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    cat = ProductCategory(name=body.name)
    db.add(cat)
    await db.commit()
    await db.refresh(cat)
    return cat

# ── Products ─────────────────────────────────────────────────────────────────

@router.get("")
async def list_products(
    search: Optional[str] = None,
    category_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user)
):
    q = select(Product)
    if search:
        q = q.where(Product.name.ilike(f"%{search}%") | Product.sku.ilike(f"%{search}%"))
    if category_id:
        q = q.where(Product.category_id == category_id)
    result = await db.execute(q)
    products = result.scalars().all()
    # Attach total stock
    out = []
    for p in products:
        stock_result = await db.execute(select(func.sum(Stock.quantity)).where(Stock.product_id == p.id))
        total_stock = stock_result.scalar() or 0.0
        out.append({
            "id": p.id, "name": p.name, "sku": p.sku,
            "category_id": p.category_id, "unit_of_measure": p.unit_of_measure,
            "reorder_min": p.reorder_min, "total_stock": total_stock,
            "low_stock": total_stock <= p.reorder_min
        })
    return out

@router.post("", status_code=201)
async def create_product(body: ProductIn, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    existing = await db.execute(select(Product).where(Product.sku == body.sku))
    if existing.scalar_one_or_none():
        raise HTTPException(400, "SKU already exists")
    product = Product(**body.model_dump())
    db.add(product)
    await db.commit()
    await db.refresh(product)
    return product

@router.get("/{product_id}")
async def get_product(product_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Product).where(Product.id == product_id))
    p = result.scalar_one_or_none()
    if not p:
        raise HTTPException(404, "Product not found")
    # Stock by location
    stock_result = await db.execute(select(Stock).where(Stock.product_id == product_id))
    stocks = stock_result.scalars().all()
    return {
        "id": p.id, "name": p.name, "sku": p.sku,
        "category_id": p.category_id, "unit_of_measure": p.unit_of_measure,
        "reorder_min": p.reorder_min,
        "stock_by_location": [{"location_id": s.location_id, "quantity": s.quantity} for s in stocks]
    }

@router.put("/{product_id}")
async def update_product(product_id: int, body: ProductUpdate, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Product).where(Product.id == product_id))
    p = result.scalar_one_or_none()
    if not p:
        raise HTTPException(404, "Product not found")
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(p, k, v)
    await db.commit()
    await db.refresh(p)
    return p

@router.delete("/{product_id}", status_code=204)
async def delete_product(product_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Product).where(Product.id == product_id))
    p = result.scalar_one_or_none()
    if not p:
        raise HTTPException(404, "Product not found")
    await db.delete(p)
    await db.commit()
