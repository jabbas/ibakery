"""Add parent_product_id and base_percentage to products.

Revision ID: 004_add_product_parent
Revises: 003_offer_item_product_nullable
Create Date: 2024-12-24
"""
from alembic import op
import sqlalchemy as sa


revision = '004_add_product_parent'
down_revision = '003_offer_item_product_nullable'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Add parent_product_id column
    op.add_column('products', sa.Column('parent_product_id', sa.UUID(), nullable=True))

    # Add base_percentage column with default 100
    op.add_column('products', sa.Column('base_percentage', sa.Numeric(5, 2), nullable=False, server_default='100'))

    # Add foreign key constraint
    op.create_foreign_key(
        'products_parent_product_id_fkey',
        'products', 'products',
        ['parent_product_id'], ['id'],
        ondelete='SET NULL'
    )


def downgrade() -> None:
    op.drop_constraint('products_parent_product_id_fkey', 'products', type_='foreignkey')
    op.drop_column('products', 'base_percentage')
    op.drop_column('products', 'parent_product_id')
