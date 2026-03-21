"""Add App Usage Categories

Revision ID: 6d5869c8e36c
Revises: 2bd90d425343
Create Date: 2026-03-19 23:03:58.359652

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '6d5869c8e36c'
down_revision: Union[str, Sequence[str], None] = '2bd90d425343'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.add_column('behavior_logs', sa.Column('social_time', sa.Float(), nullable=True, server_default='0.0'))
    op.add_column('behavior_logs', sa.Column('entertainment_time', sa.Float(), nullable=True, server_default='0.0'))
    op.add_column('behavior_logs', sa.Column('productivity_time', sa.Float(), nullable=True, server_default='0.0'))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column('behavior_logs', 'productivity_time')
    op.drop_column('behavior_logs', 'entertainment_time')
    op.drop_column('behavior_logs', 'social_time')
