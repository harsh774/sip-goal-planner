from fastapi import status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.crypto import get_crypto
from app.core.errors import FieldError
from app.core.security import hash_password, verify_password
from app.models import User
from app.models.enums import Currency
from app.repositories import UserRepository
from app.schemas.auth import PasswordChange, RegisterIn, UserUpdate

# Checked against when the email is unknown, so response time doesn't reveal which emails exist.
_DUMMY_HASH = hash_password("timing-equaliser-1")


def _email_taken() -> FieldError:
    return FieldError(
        "email", "email_taken", "This email already has an account.", status.HTTP_409_CONFLICT
    )


class AuthService:
    def __init__(self, db: Session) -> None:
        self._db = db
        self._users = UserRepository(db)
        self._crypto = get_crypto()

    def register(self, data: RegisterIn) -> User:
        email_hash = self._crypto.email_hash(data.email)
        if self._users.get_by_email_hash(email_hash):
            raise _email_taken()

        user = User(
            email=data.email,
            email_hash=email_hash,
            password_hash=hash_password(data.password),
            first_name=data.first_name,
            last_name=data.last_name,
            default_currency=Currency.INR,
        )
        try:
            self._users.add(user)
            self._db.commit()
        except IntegrityError:
            self._db.rollback()
            raise _email_taken() from None
        return user

    def authenticate(self, email: str, password: str) -> User | None:
        user = self._users.get_by_email_hash(self._crypto.email_hash(email))
        if user is None:
            verify_password(password, _DUMMY_HASH)
            return None
        return user if verify_password(password, user.password_hash) else None

    def update_profile(self, user: User, data: UserUpdate) -> User:
        if data.default_currency is not None:
            user.default_currency = data.default_currency
        if data.first_name is not None:
            user.first_name = data.first_name
        if "last_name" in data.model_fields_set:
            user.last_name = data.last_name
        self._db.commit()
        return user

    def change_password(self, user: User, data: PasswordChange) -> None:
        if not verify_password(data.current_password, user.password_hash):
            raise FieldError(
                "current_password", "password_incorrect", "Current password is incorrect."
            )
        if data.new_password == data.current_password:
            raise FieldError("new_password", "password_unchanged", "Choose a different password.")
        user.password_hash = hash_password(data.new_password)
        self._db.commit()
