"""baseline

Revision ID: 0001_baseline
Revises:
Create Date: 2026-09-19
"""

from alembic import op

revision = "0001_baseline"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    import house_design.models  # noqa: F401
    from house_design.database import Base

    Base.metadata.create_all(bind=op.get_bind())


def downgrade() -> None:
    import house_design.models  # noqa: F401
    from house_design.database import Base

    Base.metadata.drop_all(bind=op.get_bind())
