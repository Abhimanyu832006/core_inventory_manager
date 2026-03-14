Live WebSite at: https://coreinventory.shop
# CoreInventory

A modular, full-stack Inventory Management System built to replace manual registers and Excel sheets with a centralized, real-time web application.

---

## Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter Web |
| Backend | Python · FastAPI |
| Database | SQLite via SQLAlchemy (async) |
| Auth | JWT (HS256) · OTP email reset |
| State Management | Riverpod |
| HTTP Client | Dio |
| Hosting | Self-hosted on Dell homelab · Ubuntu 22.04 |

---

## Features

### Authentication
- Signup / Login with JWT tokens
- OTP-based password reset via email
- Role-based accounts (Manager / Staff)

### Dashboard
- Live KPI cards — Total Products, Low Stock, Out of Stock, Pending Receipts, Pending Deliveries, Pending Transfers
- Quick action shortcuts
- Recent receipts overview

### Products
- Create and manage products with SKU, category, unit of measure
- Low stock threshold per product
- Stock availability tracked per warehouse location

### Receipts (Incoming Stock)
- Create receipts with supplier and product lines
- Validate to automatically increase stock
- Full status flow: Draft → Done

### Deliveries (Outgoing Stock)
- Create delivery orders with customer and product lines
- Validate to automatically decrease stock from specified locations

### Internal Transfers
- Move stock between locations or warehouses
- Net total stock unchanged — only location updated
- Every movement logged

### Stock Adjustments
- Physical count reconciliation
- Live delta calculation (counted vs system)
- Validate to correct stock discrepancies

### Stock Ledger
- Append-only audit trail of every stock movement
- Filterable by product, location, operation type
- Records delta, quantity after, reference operation, timestamp

### Warehouses & Locations
- Multi-warehouse support
- Nested location management (Rack A, Production Floor, etc.)

---

## Project Structure
```
coreinventory/
├── backend/                  # FastAPI server
│   ├── app/
│   │   ├── main.py           # App entry point
│   │   ├── database.py       # SQLite engine + table init
│   │   ├── core/             # Config, JWT, dependencies
│   │   ├── models/           # SQLAlchemy ORM models
│   │   ├── routers/          # API route handlers
│   │   └── services/         # Stock mutation engine
│   ├── requirements.txt
│   └── run.sh
└── frontend/                 # Flutter Web app
    └── lib/
        ├── core/             # Theme, router, constants
        ├── screens/          # All app screens
        ├── services/         # API service layer
        ├── providers/        # Riverpod state providers
        └── widgets/          # Shared UI components
```

---

## Running Locally

### Backend
```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Create .env file
cp .env.example .env
# Edit .env and set JWT_SECRET and email credentials

uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

API docs available at `http://localhost:8000/docs`

### Frontend
```bash
cd frontend
flutter pub get

# Set API URL in lib/core/constants.dart
# static const String apiBaseUrl = 'http://localhost:8000';

flutter run -d chrome --web-port 3000
```

---

## Environment Variables

Create a `.env` file inside the `backend/` directory:
```
JWT_SECRET=your_long_random_secret
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=1440
DATABASE_URL=sqlite+aiosqlite:///./coreinventory.db
LOW_STOCK_THRESHOLD=10
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USER=your@gmail.com
EMAIL_PASSWORD=your_app_password
```

> The `.env` file is gitignored and must be created manually. Never commit it.

---

## First Run Setup

1. Start the backend — database tables are created automatically on first launch
2. Sign up for an account via the app
3. Create a warehouse and at least one location
4. Add product categories and products
5. Create a receipt and validate it to load initial stock

---

## Architecture Notes

- All stock mutations go through `stock_service.py` — never directly from routers
- The stock ledger is append-only — every validated operation writes a permanent entry
- SQLite can be swapped for PostgreSQL by changing `DATABASE_URL` in `.env` — no other code changes needed
