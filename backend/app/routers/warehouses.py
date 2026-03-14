from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import Optional
from app.database import get_db
from app.models.all_models import Warehouse, Location, User
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/warehouses", tags=["warehouses"])

class WarehouseIn(BaseModel):
    name: str
    address: Optional[str] = None

class LocationIn(BaseModel):
    name: str

@router.get("")
async def list_warehouses(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Warehouse))
    return result.scalars().all()

@router.post("", status_code=201)
async def create_warehouse(body: WarehouseIn, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    wh = Warehouse(**body.model_dump())
    db.add(wh)
    await db.commit()
    await db.refresh(wh)
    return wh

@router.get("/{warehouse_id}/locations")
async def list_locations(warehouse_id: int, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    result = await db.execute(select(Location).where(Location.warehouse_id == warehouse_id))
    return result.scalars().all()

@router.post("/{warehouse_id}/locations", status_code=201)
async def create_location(warehouse_id: int, body: LocationIn, db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)):
    loc = Location(warehouse_id=warehouse_id, name=body.name)
    db.add(loc)
    await db.commit()
    await db.refresh(loc)
    return loc
