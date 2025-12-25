"""Add is_completed to offers

Revision ID: 002_add_offer_is_completed
Revises: 001_add_product_sizes
Create Date: 2024-12-24

"""
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = '002_add_offer_is_completed'
down_revision = '001_add_product_sizes'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('offers', sa.Column('is_completed', sa.Boolean(), nullable=False, server_default='false'))


def downgrade() -> None:
    op.drop_column('offers', 'is_completed')
