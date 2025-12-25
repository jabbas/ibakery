"""Make offer_item.product_id nullable with SET NULL on delete.

Revision ID: 003_offer_item_product_nullable
Revises: 002_add_offer_is_completed
Create Date: 2024-12-24
"""
from alembic import op
import sqlalchemy as sa


revision = '003_offer_item_product_nullable'
down_revision = '002_add_offer_is_completed'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Make product_id nullable
    op.alter_column('offer_items', 'product_id',
                    existing_type=sa.UUID(),
                    nullable=True)

    # Drop existing foreign key and recreate with ON DELETE SET NULL
    op.drop_constraint('offer_items_product_id_fkey', 'offer_items', type_='foreignkey')
    op.create_foreign_key(
        'offer_items_product_id_fkey',
        'offer_items', 'products',
        ['product_id'], ['id'],
        ondelete='SET NULL'
    )


def downgrade() -> None:
    # Drop the SET NULL foreign key
    op.drop_constraint('offer_items_product_id_fkey', 'offer_items', type_='foreignkey')

    # Recreate without ON DELETE SET NULL
    op.create_foreign_key(
        'offer_items_product_id_fkey',
        'offer_items', 'products',
        ['product_id'], ['id']
    )

    # Make product_id non-nullable again (this will fail if there are NULLs)
    op.alter_column('offer_items', 'product_id',
                    existing_type=sa.UUID(),
                    nullable=False)
