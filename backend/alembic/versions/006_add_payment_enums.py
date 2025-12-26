"""Add payment enum types

Revision ID: 006_add_payment_enums
Revises: 005_ingredient_package_fields
Create Date: 2025-12-26

Converts payment_method and payment_status columns from VARCHAR to ENUM types.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = '006_add_payment_enums'
down_revision: Union[str, None] = '005_ingredient_package_fields'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create enum types
    paymentmethod = postgresql.ENUM('CASH', 'BLIK', name='paymentmethod', create_type=False)
    paymentstatus = postgresql.ENUM('PENDING', 'PAID', 'CANCELLED', name='paymentstatus', create_type=False)

    # Create the enum types in the database
    paymentmethod.create(op.get_bind(), checkfirst=True)
    paymentstatus.create(op.get_bind(), checkfirst=True)

    # Alter columns to use enum types
    op.execute('ALTER TABLE orders ALTER COLUMN payment_method TYPE paymentmethod USING payment_method::paymentmethod')
    op.execute('ALTER TABLE orders ALTER COLUMN payment_status TYPE paymentstatus USING payment_status::paymentstatus')


def downgrade() -> None:
    # Convert back to VARCHAR
    op.execute('ALTER TABLE orders ALTER COLUMN payment_method TYPE VARCHAR(20) USING payment_method::text')
    op.execute('ALTER TABLE orders ALTER COLUMN payment_status TYPE VARCHAR(20) USING payment_status::text')

    # Drop enum types
    op.execute('DROP TYPE IF EXISTS paymentmethod')
    op.execute('DROP TYPE IF EXISTS paymentstatus')
