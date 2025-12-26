from .units import router as units_router
from .ingredients import router as ingredients_router
from .products import router as products_router
from .offers import router as offers_router
from .orders import router as orders_router
from .auth import router as auth_router
from .pickup_points import router as pickup_points_router

__all__ = [
    "units_router",
    "ingredients_router",
    "products_router",
    "offers_router",
    "orders_router",
    "auth_router",
    "pickup_points_router",
]
