from datetime import datetime, timedelta
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import JWTError, jwt
import bcrypt

from ..database import get_db
from ..config import get_settings
from ..models.baker import Baker
from ..schemas.baker import BakerCreate, BakerResponse, Token, TokenData

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return bcrypt.checkpw(
        plain_password.encode('utf-8'),
        hashed_password.encode('utf-8')
    )


def get_password_hash(password: str) -> str:
    return bcrypt.hashpw(
        password.encode('utf-8'),
        bcrypt.gensalt()
    ).decode('utf-8')


def create_access_token(data: dict, expires_delta: timedelta | None = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.secret_key, algorithm=settings.algorithm)
    return encoded_jwt


async def get_current_baker(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db),
) -> Baker:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[settings.algorithm])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
        token_data = TokenData(email=email)
    except JWTError:
        raise credentials_exception

    result = await db.execute(select(Baker).where(Baker.email == token_data.email))
    baker = result.scalar_one_or_none()
    if baker is None:
        raise credentials_exception
    return baker


@router.post("/register", response_model=BakerResponse)
async def register_baker(
    baker_data: BakerCreate,
    db: AsyncSession = Depends(get_db),
):
    # Check if baker already exists
    result = await db.execute(select(Baker).where(Baker.email == baker_data.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    baker = Baker(
        email=baker_data.email,
        password_hash=get_password_hash(baker_data.password),
        name=baker_data.name,
        phone=baker_data.phone,
    )
    db.add(baker)
    await db.commit()
    await db.refresh(baker)
    return baker


@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Baker).where(Baker.email == form_data.username))
    baker = result.scalar_one_or_none()

    if not baker or not verify_password(form_data.password, baker.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token_expires = timedelta(minutes=settings.access_token_expire_minutes)
    access_token = create_access_token(
        data={"sub": baker.email}, expires_delta=access_token_expires
    )
    return Token(access_token=access_token)


@router.get("/me", response_model=BakerResponse)
async def get_current_baker_info(
    current_baker: Baker = Depends(get_current_baker),
):
    return current_baker
