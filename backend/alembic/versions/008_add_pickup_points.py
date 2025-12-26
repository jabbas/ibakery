"""Add pickup_points table and orders.pickup_point_id

Revision ID: 008_add_pickup_points
Revises: 007_revert_payment_enums
Create Date: 2025-12-26
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision: str = '008_add_pickup_points'
down_revision: Union[str, None] = '007_revert_payment_enums'
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
    # Create pickup_points table if it doesn't exist
    if not table_exists('pickup_points'):
        op.create_table(
            'pickup_points',
            sa.Column('id', sa.UUID(), nullable=False),
            sa.Column('name', sa.String(200), nullable=False),
            sa.Column('address', sa.String(500), nullable=False),
            sa.Column('description', sa.Text(), nullable=True),
            sa.Column('is_active', sa.Boolean(), nullable=False, server_default='true'),
            sa.Column('created_at', sa.DateTime(), nullable=False, server_default=sa.func.now()),
            sa.PrimaryKeyConstraint('id'),
        )
        print("Created table: pickup_points")

    # Add pickup_point_id column to orders if it doesn't exist
    if table_exists('orders') and not column_exists('orders', 'pickup_point_id'):
        op.add_column(
            'orders',
            sa.Column('pickup_point_id', sa.UUID(), nullable=True)
        )
        op.create_foreign_key(
            'fk_orders_pickup_point',
            'orders',
            'pickup_points',
            ['pickup_point_id'],
            ['id'],
            ondelete='RESTRICT'
        )
        print("Added column: orders.pickup_point_id")


def downgrade() -> None:
    if table_exists('orders') and column_exists('orders', 'pickup_point_id'):
        op.drop_constraint('fk_orders_pickup_point', 'orders', type_='foreignkey')
        op.drop_column('orders', 'pickup_point_id')
    if table_exists('pickup_points'):
        op.drop_table('pickup_points')
