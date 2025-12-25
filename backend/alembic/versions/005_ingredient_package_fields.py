"""Add package_quantity and package_price to ingredients

Revision ID: 005
Revises: 004_add_product_parent
Create Date: 2025-12-25
"""
from alembic import op
import sqlalchemy as sa

revision = "005_ingredient_package_fields"
down_revision = "004_add_product_parent"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add new columns
    op.add_column("ingredients", sa.Column("package_quantity", sa.Numeric(10, 4), nullable=False, server_default="1"))
    op.add_column("ingredients", sa.Column("package_price", sa.Numeric(10, 2), nullable=False, server_default="0"))

    # Migrate data: price_per_unit becomes package_price with package_quantity=1
    op.execute("UPDATE ingredients SET package_price = price_per_unit, package_quantity = 1")

    # Drop old column
    op.drop_column("ingredients", "price_per_unit")


def downgrade() -> None:
    op.add_column("ingredients", sa.Column("price_per_unit", sa.Numeric(10, 4), nullable=False, server_default="0"))
    op.execute("UPDATE ingredients SET price_per_unit = package_price / package_quantity")
    op.drop_column("ingredients", "package_quantity")
    op.drop_column("ingredients", "package_price")
