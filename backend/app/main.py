from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.database import init_db
from app.routers.auth import router as auth_router
from app.routers.products import router as products_router
from app.routers.warehouses import router as warehouses_router
from app.routers.receipts import router as receipts_router
from app.routers.deliveries import router as deliveries_router
from app.routers.transfers import router as transfers_router
from app.routers.adjustments import router as adjustments_router
from app.routers.ledger_and_dashboard import router as ledger_router, dashboard_router

@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield

app = FastAPI(
    title="CoreInventory API",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:57982",
        "http://127.0.0.1:3000",
        "http://192.168.1.9:8000",
        "https://coreinventory.shop",
        "https://www.coreinventory.shop",
        "https://api.coreinventory.shop",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(products_router)
app.include_router(warehouses_router)
app.include_router(receipts_router)
app.include_router(deliveries_router)
app.include_router(transfers_router)
app.include_router(adjustments_router)
app.include_router(ledger_router)
app.include_router(dashboard_router)

@app.get("/health")
async def health():
    return {"status": "ok", "service": "CoreInventory API"}
