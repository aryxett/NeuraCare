"""add_profile_metadata

Revision ID: bdd4bc0c745a
Revises: 6d5869c8e36c
Create Date: 2026-03-21 17:48:04.394735

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'bdd4bc0c745a'
down_revision: Union[str, Sequence[str], None] = '6d5869c8e36c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('users', sa.Column('profile_metadata', sa.Text(), server_default='{}', nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('users', 'profile_metadata')
