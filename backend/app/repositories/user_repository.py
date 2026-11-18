import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import User


class UserRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get(self, user_id: uuid.UUID) -> User | None:
        return self._db.get(User, user_id)

    def get_by_email_hash(self, email_hash: str) -> User | None:
        return self._db.scalar(select(User).where(User.email_hash == email_hash))

    def add(self, user: User) -> User:
        self._db.add(user)
        self._db.flush()
        return user
