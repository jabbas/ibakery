"""Initial schema - baseline migration

Revision ID: 000_initial_schema
Revises:
Create Date: 2025-12-24

This migration creates all initial tables if they don't exist.
It serves as a baseline for databases that were created using SQLAlchemy create_all.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision: str = '000_initial_schema'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def table_exists(table_name: str) -> bool:
    """Check if a table exists in the database."""
    bind = op.get_bind()
    inspector = inspect(bind)
    return table_name in inspector.get_table_names()


def upgrade() -> None:
    # Units table
    if not table_exists('units'):
        op.create_table(
            'units',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('name', sa.String(50), nullable=False),
            sa.Column('abbreviation', sa.String(10), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('abbreviation'),
            sa.UniqueConstraint('name'),
        )

    # Ingredients table
    if not table_exists('ingredients'):
        op.create_table(
            'ingredients',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('name', sa.String(100), nullable=False),
            sa.Column('unit_id', sa.UUID(), nullable=False),
            sa.Column('price_per_unit', sa.Numeric(10, 4), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['unit_id'], ['units.id']),
            sa.PrimaryKeyConstraint('id'),
        )

    # Products table
    if not table_exists('products'):
        op.create_table(
            'products',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('name', sa.String(100), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('image_url', sa.String(500), nullable=True),
            sa.Column('base_price', sa.Numeric(10, 2), nullable=False),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.PrimaryKeyConstraint('id'),
        )

    # ProductIngredients table
    if not table_exists('product_ingredients'):
        op.create_table(
            'product_ingredients',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('product_id', sa.UUID(), nullable=False),
            sa.Column('ingredient_id', sa.UUID(), nullable=False),
            sa.Column('quantity', sa.Numeric(10, 4), nullable=False),
            sa.ForeignKeyConstraint(['ingredient_id'], ['ingredients.id']),
            sa.ForeignKeyConstraint(['product_id'], ['products.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
        )

    # Offers table
    if not table_exists('offers'):
        op.create_table(
            'offers',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('pickup_date', sa.Date(), nullable=False),
            sa.Column('pickup_time_from', sa.Time(), nullable=False),
            sa.Column('pickup_time_to', sa.Time(), nullable=False),
            sa.Column('order_deadline', sa.DateTime(), nullable=False),
            sa.Column('is_recurring', sa.Boolean(), nullable=False, server_default='false'),
            sa.Column('recurrence_rule', sa.String(100), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('parent_offer_id', sa.UUID(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['parent_offer_id'], ['offers.id']),
            sa.PrimaryKeyConstraint('id'),
        )

    # OfferItems table
    if not table_exists('offer_items'):
        op.create_table(
            'offer_items',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('offer_id', sa.UUID(), nullable=False),
            sa.Column('product_id', sa.UUID(), nullable=False),
            sa.Column('price', sa.Numeric(10, 2), nullable=False),
            sa.Column('max_quantity', sa.Integer(), nullable=True),
            sa.Column('available_quantity', sa.Integer(), nullable=True),
            sa.ForeignKeyConstraint(['offer_id'], ['offers.id'], ondelete='CASCADE'),
            sa.ForeignKeyConstraint(['product_id'], ['products.id']),
            sa.PrimaryKeyConstraint('id'),
        )

    # Orders table
    if not table_exists('orders'):
        op.create_table(
            'orders',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('offer_id', sa.UUID(), nullable=False),
            sa.Column('customer_name', sa.String(100), nullable=False),
            sa.Column('customer_phone', sa.String(20), nullable=False),
            sa.Column('customer_email', sa.String(100), nullable=True),
            sa.Column('payment_method', sa.String(20), nullable=False),
            sa.Column('payment_status', sa.String(20), nullable=False, server_default='PENDING'),
            sa.Column('total_price', sa.Numeric(10, 2), nullable=False),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.ForeignKeyConstraint(['offer_id'], ['offers.id']),
            sa.PrimaryKeyConstraint('id'),
        )

    # OrderItems table
    if not table_exists('order_items'):
        op.create_table(
            'order_items',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('order_id', sa.UUID(), nullable=False),
            sa.Column('offer_item_id', sa.UUID(), nullable=False),
            sa.Column('quantity', sa.Integer(), nullable=False),
            sa.Column('unit_price', sa.Numeric(10, 2), nullable=False),
            sa.ForeignKeyConstraint(['offer_item_id'], ['offer_items.id']),
            sa.ForeignKeyConstraint(['order_id'], ['orders.id'], ondelete='CASCADE'),
            sa.PrimaryKeyConstraint('id'),
        )

    # Bakers table
    if not table_exists('bakers'):
        op.create_table(
            'bakers',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('email', sa.String(100), nullable=False),
            sa.Column('password_hash', sa.String(255), nullable=False),
            sa.Column('name', sa.String(100), nullable=False),
            sa.Column('phone', sa.String(20), nullable=True),
            sa.Column('created_at', sa.DateTime(), nullable=False),
            sa.PrimaryKeyConstraint('id'),
            sa.UniqueConstraint('email'),
        )

    print("Initial schema migration completed.")


def downgrade() -> None:
    # Drop tables in reverse order of dependencies
    tables = [
        'order_items', 'orders', 'offer_items', 'offers',
        'product_ingredients', 'products', 'ingredients', 'units', 'bakers'
    ]
    for table in tables:
        if table_exists(table):
            op.drop_table(table)
