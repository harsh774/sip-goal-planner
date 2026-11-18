from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm

from app.api.deps import AuthServiceDep, CurrentUser
from app.core.security import create_access_token
from app.schemas.auth import RegisterIn, TokenOut, UserOut, UserUpdate

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", status_code=status.HTTP_201_CREATED, response_model=UserOut)
def register(data: RegisterIn, auth: AuthServiceDep):
    return auth.register(data)


@router.post("/login", response_model=TokenOut, summary="Log in (OAuth2 password form)")
def login(form: Annotated[OAuth2PasswordRequestForm, Depends()], auth: AuthServiceDep):
    """`username` is the email address."""
    user = auth.authenticate(form.username, form.password)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenOut(access_token=create_access_token(user.id))


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser):
    return user


@router.patch("/me", response_model=UserOut)
def update_me(data: UserUpdate, user: CurrentUser, auth: AuthServiceDep):
    return auth.update_profile(user, data)
