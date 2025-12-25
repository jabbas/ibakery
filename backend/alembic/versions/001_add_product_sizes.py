"""Add product sizes table and offer_items.product_size_id

Revision ID: 001_add_product_sizes
Revises:
Create Date: 2025-12-24
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision: str = '001_add_product_sizes'
down_revision: Union[str, None] = '000_initial_schema'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def table_exists(table_name: str) -> bool:
    """Check if a table exists in the database."""
    bind = op.get_bind()
    inspector = inspect(bind)
    return table_name in inspector.get_table_names()


def column_exists(table_name: str, column_name: str) -> bool:
    """Check if a column exists in a table."""
    bind = op.get_bind()
    inspector = inspect(bind)
    columns = [col['name'] for col in inspector.get_columns(table_name)]
    return column_name in columns


def upgrade() -> None:
    # Create product_sizes table if it doesn't exist
    if not table_exists('product_sizes'):
        op.create_table(
            'product_sizes',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('product_id', sa.UUID(), nullable=False),
            sa.Column('name', sa.String(100), nullable=False),
            sa.Column('percentage', sa.Numeric(5, 2), nullable=False, server_default='100'),
            sa.Column('is_default', sa.Boolean(), nullable=False, server_default='false'),
            sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.PrimaryKeyConstraint('id'),
            sa.ForeignKeyConstraint(['product_id'], ['products.id'], ondelete='CASCADE'),
        )
        print("Created table: product_sizes")

    # Add product_size_id column to offer_items if it doesn't exist
    if table_exists('offer_items') and not column_exists('offer_items', 'product_size_id'):
        op.add_column(
            'offer_items',
            sa.Column('product_size_id', sa.UUID(), nullable=True)
        )
        op.create_foreign_key(
            'fk_offer_items_product_size',
            'offer_items',
            'product_sizes',
            ['product_size_id'],
            ['id'],
            ondelete='SET NULL'
        )
        print("Added column: offer_items.product_size_id")


def downgrade() -> None:
    if table_exists('offer_items') and column_exists('offer_items', 'product_size_id'):
        op.drop_constraint('fk_offer_items_product_size', 'offer_items', type_='foreignkey')
        op.drop_column('offer_items', 'product_size_id')
    if table_exists('product_sizes'):
        op.drop_table('product_sizes')
