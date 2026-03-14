from datetime import datetime
from sqlalchemy import Integer, String, Float, DateTime, ForeignKey, Enum, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base
import enum

# ─── Enums ───────────────────────────────────────────────────────────────────

class OperationStatus(str, enum.Enum):
    draft = "draft"
    waiting = "waiting"
    ready = "ready"
    done = "done"
    cancelled = "cancelled"

class RefType(str, enum.Enum):
    receipt = "receipt"
    delivery = "delivery"
    transfer = "transfer"
    adjustment = "adjustment"

class UserRole(str, enum.Enum):
    manager = "manager"
    staff = "staff"

# ─── User ─────────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255))
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.staff)
    otp_code: Mapped[str | None] = mapped_column(String(6), nullable=True)
    otp_expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

# ─── Warehouse & Location ─────────────────────────────────────────────────────

class Warehouse(Base):
    __tablename__ = "warehouses"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100), unique=True)
    address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    locations: Mapped[list["Location"]] = relationship("Location", back_populates="warehouse")

class Location(Base):
    __tablename__ = "locations"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    warehouse_id: Mapped[int] = mapped_column(ForeignKey("warehouses.id"))
    name: Mapped[str] = mapped_column(String(100))
    warehouse: Mapped["Warehouse"] = relationship("Warehouse", back_populates="locations")

# ─── Product ──────────────────────────────────────────────────────────────────

class ProductCategory(Base):
    __tablename__ = "product_categories"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100), unique=True)

class Product(Base):
    __tablename__ = "products"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(200))
    sku: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    category_id: Mapped[int | None] = mapped_column(ForeignKey("product_categories.id"), nullable=True)
    unit_of_measure: Mapped[str] = mapped_column(String(50), default="pcs")
    reorder_min: Mapped[int] = mapped_column(Integer, default=10)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    category: Mapped["ProductCategory | None"] = relationship("ProductCategory")

# ─── Stock ────────────────────────────────────────────────────────────────────

class Stock(Base):
    __tablename__ = "stock"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"))
    quantity: Mapped[float] = mapped_column(Float, default=0.0)
    product: Mapped["Product"] = relationship("Product")
    location: Mapped["Location"] = relationship("Location")

# ─── Receipts ─────────────────────────────────────────────────────────────────

class Receipt(Base):
    __tablename__ = "receipts"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    supplier: Mapped[str] = mapped_column(String(200))
    location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"))
    status: Mapped[OperationStatus] = mapped_column(Enum(OperationStatus), default=OperationStatus.draft)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    lines: Mapped[list["ReceiptLine"]] = relationship("ReceiptLine", back_populates="receipt", cascade="all, delete-orphan")
    location: Mapped["Location"] = relationship("Location")

class ReceiptLine(Base):
    __tablename__ = "receipt_lines"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    receipt_id: Mapped[int] = mapped_column(ForeignKey("receipts.id"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    expected_qty: Mapped[float] = mapped_column(Float, default=0.0)
    received_qty: Mapped[float] = mapped_column(Float, default=0.0)
    receipt: Mapped["Receipt"] = relationship("Receipt", back_populates="lines")
    product: Mapped["Product"] = relationship("Product")

# ─── Deliveries ───────────────────────────────────────────────────────────────

class Delivery(Base):
    __tablename__ = "deliveries"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    customer: Mapped[str] = mapped_column(String(200))
    status: Mapped[OperationStatus] = mapped_column(Enum(OperationStatus), default=OperationStatus.draft)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    lines: Mapped[list["DeliveryLine"]] = relationship("DeliveryLine", back_populates="delivery", cascade="all, delete-orphan")

class DeliveryLine(Base):
    __tablename__ = "delivery_lines"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    delivery_id: Mapped[int] = mapped_column(ForeignKey("deliveries.id"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"))
    qty: Mapped[float] = mapped_column(Float)
    delivery: Mapped["Delivery"] = relationship("Delivery", back_populates="lines")
    product: Mapped["Product"] = relationship("Product")
    location: Mapped["Location"] = relationship("Location")

# ─── Transfers ────────────────────────────────────────────────────────────────

class Transfer(Base):
    __tablename__ = "transfers"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    from_location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"))
    to_location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"))
    status: Mapped[OperationStatus] = mapped_column(Enum(OperationStatus), default=OperationStatus.draft)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    lines: Mapped[list["TransferLine"]] = relationship("TransferLine", back_populates="transfer", cascade="all, delete-orphan")
    from_location: Mapped["Location"] = relationship("Location", foreign_keys=[from_location_id])
    to_location: Mapped["Location"] = relationship("Location", foreign_keys=[to_location_id])

class TransferLine(Base):
    __tablename__ = "transfer_lines"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    transfer_id: Mapped[int] = mapped_column(ForeignKey("transfers.id"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    qty: Mapped[float] = mapped_column(Float)
    transfer: Mapped["Transfer"] = relationship("Transfer", back_populates="lines")
    product: Mapped["Product"] = relationship("Product")

# ─── Adjustments ──────────────────────────────────────────────────────────────

class Adjustment(Base):
    __tablename__ = "adjustments"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"))
    status: Mapped[OperationStatus] = mapped_column(Enum(OperationStatus), default=OperationStatus.draft)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    lines: Mapped[list["AdjustmentLine"]] = relationship("AdjustmentLine", back_populates="adjustment", cascade="all, delete-orphan")
    location: Mapped["Location"] = relationship("Location")

class AdjustmentLine(Base):
    __tablename__ = "adjustment_lines"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    adjustment_id: Mapped[int] = mapped_column(ForeignKey("adjustments.id"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    system_qty: Mapped[float] = mapped_column(Float)
    counted_qty: Mapped[float] = mapped_column(Float)
    delta: Mapped[float] = mapped_column(Float)  # counted - system
    adjustment: Mapped["Adjustment"] = relationship("Adjustment", back_populates="lines")
    product: Mapped["Product"] = relationship("Product")

# ─── Stock Ledger ─────────────────────────────────────────────────────────────

class StockLedger(Base):
    __tablename__ = "stock_ledger"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    location_id: Mapped[int] = mapped_column(ForeignKey("locations.id"))
    ref_type: Mapped[RefType] = mapped_column(Enum(RefType))
    ref_id: Mapped[int] = mapped_column(Integer)
    delta: Mapped[float] = mapped_column(Float)       # +/- change
    qty_after: Mapped[float] = mapped_column(Float)   # stock after this event
    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_by: Mapped[int] = mapped_column(ForeignKey("users.id"))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    product: Mapped["Product"] = relationship("Product")
    location: Mapped["Location"] = relationship("Location")
