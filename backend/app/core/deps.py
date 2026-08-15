from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.orm import Session

from app.core.security import decode_token
from app.db import get_db
from app.models import User, UserRole

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> User:
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
    )
    try:
        payload = decode_token(token)
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_error
    except JWTError:
        raise credentials_error

    user = db.query(User).filter(User.id == user_id).first()
    if user is None or not user.is_active:
        raise credentials_error

    if user.role != UserRole.super_admin and user.academy_id:
        from app.models import Academy, AcademyStatus
        academy = db.query(Academy).filter(Academy.id == user.academy_id).first()
        if not academy or academy.status in [AcademyStatus.suspended, AcademyStatus.deleted]:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is not accessible, contact owner",
            )

    return user


def require_role(*allowed_roles: UserRole):
    """Dependency factory. Use as:
    current_user: User = Depends(require_role(UserRole.super_admin))
    This is what makes permissions real - the client hiding a button is
    just UX, this is what actually blocks the request server-side.
    """

    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action",
            )
        return current_user

    return role_checker


def require_academy_scope(*extra_roles: UserRole):
    """Like require_role, but also resolves WHICH academy a request
    should read from: academy_admin/coach always use their own; super
    admin must pass ?academy_id=<uuid> to view a specific academy's
    data - this is the "reach into another academy" capability, and
    it's explicit every time, never a silent default.

    Deliberately applied only to GET/list routes in this codebase -
    letting the platform owner view any academy's roster for support
    purposes is a different, safer thing than letting them edit it, so
    write endpoints still use plain require_role() with the caller's
    own academy_id.

    Returns (current_user, academy_id) - the route always gets a
    concrete academy_id to filter by, regardless of who's asking.
    """

    def resolver(
        academy_id: str | None = None,
        current_user: User = Depends(get_current_user),
    ):
        if current_user.role == UserRole.super_admin:
            if not academy_id:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Super admin must pass ?academy_id=<uuid> to view a specific academy's data",
                )
            return current_user, academy_id
        if current_user.role not in extra_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You do not have permission to perform this action",
            )
        return current_user, current_user.academy_id

    return resolver
