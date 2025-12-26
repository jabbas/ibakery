"""Revert payment enum types back to VARCHAR

Revision ID: 007_revert_payment_enums
Revises: 006_add_payment_enums
Create Date: 2025-12-26

SQLAlchemy async has issues with PostgreSQL ENUM types, reverting to VARCHAR.
"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '007_revert_payment_enums'
down_revision: Union[str, None] = '006_add_payment_enums'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop default before converting
    op.execute('ALTER TABLE orders ALTER COLUMN payment_status DROP DEFAULT')

    # Convert back to VARCHAR
    op.execute('ALTER TABLE orders ALTER COLUMN payment_method TYPE VARCHAR(20) USING payment_method::text')
    op.execute('ALTER TABLE orders ALTER COLUMN payment_status TYPE VARCHAR(20) USING payment_status::text')

    # Restore default
    op.execute("ALTER TABLE orders ALTER COLUMN payment_status SET DEFAULT 'PENDING'")

    # Drop enum types
    op.execute('DROP TYPE IF EXISTS paymentmethod')
    op.execute('DROP TYPE IF EXISTS paymentstatus')


def downgrade() -> None:
    # This is effectively the upgrade from 006
    from sqlalchemy.dialects import postgresql

    paymentmethod = postgresql.ENUM('CASH', 'BLIK', name='paymentmethod', create_type=False)
    paymentstatus = postgresql.ENUM('PENDING', 'PAID', 'CANCELLED', name='paymentstatus', create_type=False)
    paymentmethod.create(op.get_bind(), checkfirst=True)
    paymentstatus.create(op.get_bind(), checkfirst=True)

    op.execute('ALTER TABLE orders ALTER COLUMN payment_status DROP DEFAULT')
    op.execute('ALTER TABLE orders ALTER COLUMN payment_method TYPE paymentmethod USING payment_method::paymentmethod')
    op.execute('ALTER TABLE orders ALTER COLUMN payment_status TYPE paymentstatus USING payment_status::paymentstatus')
    op.execute("ALTER TABLE orders ALTER COLUMN payment_status SET DEFAULT 'PENDING'")
