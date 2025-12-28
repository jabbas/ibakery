import os
import sys
import asyncio
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from alembic.config import Config
from alembic import command

from .config import get_settings

settings = get_settings()

# Konfiguracja logowania
log_level = getattr(logging, settings.log_level.upper(), logging.INFO)
logging.basicConfig(
    level=log_level,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)
logger.info(f"Log level set to: {settings.log_level.upper()}")

from .routers import (
    units_router,
    ingredients_router,
    products_router,
    offers_router,
    orders_router,
    auth_router,
    pickup_points_router,
)
from .database import async_session
from .models import *  # noqa: F401, F403 - Import all models for table creation
from .models.unit import Unit
from .models.offer import Offer

# Podstawowe jednostki do utworzenia
DEFAULT_UNITS = [
    {"name": "gram", "abbreviation": "g"},
    {"name": "litr", "abbreviation": "l"},
    {"name": "sztuka", "abbreviation": "szt"},
]


def _run_upgrade():
    """Synchroniczna funkcja uruchamiająca migracje."""
    import traceback
    try:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        alembic_ini_path = os.path.join(base_path, "alembic.ini")
        script_location = os.path.join(base_path, "alembic")

        logger.info(f"Alembic config: {alembic_ini_path}")
        logger.info(f"Script location: {script_location}")

        if not os.path.exists(alembic_ini_path):
            logger.error(f"Nie znaleziono pliku alembic.ini: {alembic_ini_path}")
            return

        alembic_cfg = Config(alembic_ini_path)
        alembic_cfg.set_main_option("script_location", script_location)

        logger.info("Uruchamianie command.upgrade...")
        command.upgrade(alembic_cfg, "head")
        logger.info("command.upgrade zakończone.")
    except Exception as e:
        logger.error(f"BŁĄD podczas migracji: {e}")
        traceback.print_exc()
        raise


async def run_migrations():
    """Uruchom migracje Alembic asynchronicznie w osobnym wątku."""
    logger.info("Uruchamianie migracji bazy danych...")
    try:
        await asyncio.to_thread(_run_upgrade)
        logger.info("Migracje zakończone pomyślnie.")
    except Exception as e:
        logger.error(f"BŁĄD migracji: {e}")
        # Kontynuuj mimo błędu migracji - tabele mogą już istnieć
        logger.warning("Kontynuowanie mimo błędu migracji...")


async def seed_default_units():
    """Dodaj podstawowe jednostki jeśli nie istnieją."""
    logger.info("Sprawdzanie domyślnych jednostek...")
    async with async_session() as session:
        result = await session.execute(select(Unit).limit(1))
        if result.scalar_one_or_none() is None:
            # Brak jednostek - dodaj domyślne
            for unit_data in DEFAULT_UNITS:
                unit = Unit(**unit_data)
                session.add(unit)
            await session.commit()
            logger.info(f"Dodano {len(DEFAULT_UNITS)} domyślnych jednostek")
        else:
            logger.info("Jednostki już istnieją, pomijam.")


async def generate_recurring_offers_startup():
    """Generate recurring offer instances on startup."""
    from .services.recurring_service import generate_recurring_offers as gen_recurring

    logger.info("Generowanie ofert cyklicznych...")
    async with async_session() as session:
        try:
            created = await gen_recurring(session, days_ahead=14)
            if created:
                logger.info(f"Wygenerowano {len(created)} nowych instancji ofert cyklicznych")
            else:
                logger.info("Brak nowych ofert cyklicznych do wygenerowania")
        except Exception as e:
            logger.error(f"Błąd podczas generowania ofert cyklicznych: {e}")


async def complete_expired_offers():
    """Oznacz przeterminowane oferty jako zakończone."""
    from datetime import datetime, timedelta
    from sqlalchemy import and_, update

    logger.info("Sprawdzanie przeterminowanych ofert...")
    async with async_session() as session:
        now = datetime.utcnow()
        today = now.date()

        # Znajdź oferty gdzie:
        # - pickup_date < dzisiaj (minął dzień odbioru)
        # - lub pickup_date == dzisiaj i pickup_time_to < teraz
        # - i nie są jeszcze zakończone
        result = await session.execute(
            select(Offer).where(
                and_(
                    Offer.is_completed == False,
                    Offer.pickup_date <= today
                )
            )
        )
        offers = result.scalars().all()

        completed_count = 0
        for offer in offers:
            # Sprawdź czy minął czas odbioru
            pickup_end = datetime.combine(offer.pickup_date, offer.pickup_time_to)
            if now > pickup_end:
                offer.is_completed = True
                completed_count += 1

        if completed_count > 0:
            await session.commit()
            logger.info(f"Zakończono {completed_count} przeterminowanych ofert")
        else:
            logger.info("Brak przeterminowanych ofert do zakończenia")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("=== Rozpoczynam startup aplikacji ===")

    # Run database migrations on startup
    await run_migrations()

    # Seed default units
    await seed_default_units()

    # Complete expired offers
    await complete_expired_offers()

    # Generate recurring offers
    await generate_recurring_offers_startup()

    logger.info("=== Startup aplikacji zakończony ===")
    yield
    logger.info("=== Zamykanie aplikacji ===")


app = FastAPI(
    title="iBakery API",
    description="API dla aplikacji piekarni internetowej",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_router, prefix="/api")
app.include_router(units_router, prefix="/api")
app.include_router(ingredients_router, prefix="/api")
app.include_router(products_router, prefix="/api")
app.include_router(offers_router, prefix="/api")
app.include_router(orders_router, prefix="/api")
app.include_router(pickup_points_router, prefix="/api")


@app.get("/")
async def root():
    return {"message": "Welcome to iBakery API", "docs": "/docs"}


@app.get("/api/health")
async def health_check():
    return {"status": "healthy"}


@app.get("/api/version")
async def get_version():
    import os
    return {"version": os.environ.get("APP_VERSION", "unknown")}
