from alembic import command
from alembic.config import Config
from sqlalchemy import text
from uuid6 import uuid7

from app.core.crypto import get_crypto
from app.db.session import engine
from tests.conftest import BACKEND_DIR


def test_0002_splits_existing_display_names(migrated_db):
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    crypto = get_crypto()
    command.downgrade(config, "0001")
    try:
        with engine.begin() as conn:
            for display_name in ("Priya Sharma", "Madonna"):
                conn.execute(
                    text(
                        "INSERT INTO users (id, email, email_hash, password_hash, display_name) "
                        "VALUES (:id, :e, :h, 'x', :d)"
                    ),
                    {
                        "id": uuid7(),
                        "e": crypto.encrypt(f"{display_name}@example.com"),
                        "h": crypto.email_hash(f"{display_name}@example.com"),
                        "d": crypto.encrypt(display_name),
                    },
                )

        command.upgrade(config, "head")

        with engine.connect() as conn:
            rows = conn.execute(text("SELECT first_name, last_name FROM users")).all()
        names = {(crypto.decrypt(f), crypto.decrypt(last)) for f, last in rows}
        assert names == {("Priya", "Sharma"), ("Madonna", "")}
    finally:
        command.upgrade(config, "head")
        with engine.begin() as conn:
            conn.execute(text("TRUNCATE goal_logs, goals, users"))
