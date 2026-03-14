from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timedelta
import random, string, smtplib
from email.message import EmailMessage

from app.database import get_db
from app.models.all_models import User, UserRole
from app.core.security import hash_password, verify_password, create_access_token
from app.core.config import settings
from pydantic import BaseModel, EmailStr

router = APIRouter(prefix="/auth", tags=["auth"])

# ── Email sender ──────────────────────────────────────────────────────────────

async def send_otp_email(to_email: str, otp: str):
    msg = EmailMessage()
    msg['Subject'] = 'CoreInventory — Your OTP Code'
    msg['From'] = settings.EMAIL_USER
    msg['To'] = to_email
    msg.set_content(f'''
Your OTP code for CoreInventory password reset is:

{otp}

This code expires in 10 minutes.
Do not share it with anyone.
''')
    try:
        with smtplib.SMTP(settings.EMAIL_HOST, settings.EMAIL_PORT) as smtp:
            smtp.starttls()
            smtp.login(settings.EMAIL_USER, settings.EMAIL_PASSWORD)
            smtp.send_message(msg)
        print(f"[EMAIL] OTP sent to {to_email}")
    except Exception as e:
        print(f"[EMAIL ERROR] {e}")

# ── Schemas ───────────────────────────────────────────────────────────────────

class SignupIn(BaseModel):
    name: str
    email: EmailStr
    password: str
    role: UserRole = UserRole.staff

class LoginIn(BaseModel):
    email: EmailStr
    password: str

class OTPRequestIn(BaseModel):
    email: EmailStr

class OTPVerifyIn(BaseModel):
    email: EmailStr
    otp: str
    new_password: str

# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/signup", status_code=201)
async def signup(body: SignupIn, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    if result.scalar_one_or_none():
        raise HTTPException(400, "Email already registered")
    user = User(
        name=body.name,
        email=body.email,
        hashed_password=hash_password(body.password),
        role=body.role
    )
    db.add(user)
    await db.commit()
    return {"message": "Account created"}

@router.post("/login")
async def login(body: LoginIn, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = create_access_token({"sub": str(user.id)})
    return {"access_token": token, "token_type": "bearer", "name": user.name, "role": user.role}

@router.post("/otp/request")
async def request_otp(body: OTPRequestIn, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user:
        return {"message": "If the email exists, an OTP has been sent"}
    otp = "".join(random.choices(string.digits, k=6))
    user.otp_code = otp
    user.otp_expires_at = datetime.utcnow() + timedelta(minutes=10)
    await db.commit()
    await send_otp_email(body.email, otp)
    return {"message": "OTP sent"}

@router.post("/otp/verify")
async def verify_otp(body: OTPVerifyIn, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()
    if not user or user.otp_code != body.otp:
        raise HTTPException(400, "Invalid OTP")
    if user.otp_expires_at < datetime.utcnow():
        raise HTTPException(400, "OTP expired")
    user.hashed_password = hash_password(body.new_password)
    user.otp_code = None
    user.otp_expires_at = None
    await db.commit()
    return {"message": "Password reset successful"}
